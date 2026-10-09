#!/usr/bin/env python3
"""Haustelefon configuration generator.

Reads ``haustelefon.yaml`` and writes a complete Asterisk configuration plus a
setup code ("Einrichtungscode") for every device.

    python3 generator/generate.py                 # uses ./haustelefon.yaml
    python3 generator/generate.py --check         # validate only

Design notes
------------
* Every *line* (phone number) is its own registration at the router, so the
  router tells us which number was called and which number to call out with.
* Inbound calls are matched to their line via ``line=yes`` on the
  registration; if a router strips that parameter, ``from-speedport``
  dispatches by request-URI user / called number instead.
* The app selects the outbound line with the SIP header ``X-Haustelefon-Line``;
  the device's dialplan only honours lines that device is allowed to use.
* Inbound calls carry ``X-Haustelefon-Line: <id>`` towards the app so it can
  show which number was called.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import secrets as pysecrets
import sys
from dataclasses import dataclass, field
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - environment guard
    sys.exit("PyYAML fehlt / missing:  pip install pyyaml")

PROVISION_PREFIX = "HT1."
LINE_HEADER = "X-Haustelefon-Line"
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,30}$")
# Emergency / service numbers that must never be hijacked by an extension.
RESERVED_EXACT = {"110", "112", "115"}
RESERVED_PREFIX = ("116", "118")


class ConfigError(Exception):
    """A human-readable configuration problem."""


@dataclass
class Line:
    id: str
    label: str
    number: str
    user: str
    auth: str
    password: str
    ring: list[str]  # resolved device ids


@dataclass
class Device:
    id: str
    name: str
    extension: str
    line: str
    lines: list[str]
    password: str


@dataclass
class Group:
    id: str
    name: str
    extension: str
    members: list[str]


@dataclass
class System:
    mode: str
    speedport_ip: str
    speedport_domain: str
    server_host: str
    ws_port: int
    rtp_start: int
    rtp_end: int


@dataclass
class Model:
    system: System
    lines: list[Line]
    devices: list[Device]
    groups: list[Group]
    generated_secrets: dict[str, str] = field(default_factory=dict)

    def device(self, device_id: str) -> Device:
        return next(d for d in self.devices if d.id == device_id)


# ----------------------------------------------------------------- parsing


def _req(obj: dict, key: str, where: str):
    if key not in obj or obj[key] in (None, ""):
        raise ConfigError(f"{where}: '{key}' fehlt / missing")
    return obj[key]


def _check_id(value: str, where: str) -> str:
    value = str(value)
    if not ID_RE.match(value):
        raise ConfigError(
            f"{where}: ungültige ID '{value}' – nur a-z, 0-9 und '-' "
            f"(invalid id: lowercase letters, digits, '-')"
        )
    return value


def _check_extension(value, where: str) -> str:
    ext = str(value).strip()
    if not re.fullmatch(r"[1-9][0-9]{1,3}", ext):
        raise ConfigError(
            f"{where}: Durchwahl '{ext}' muss 2–4 Ziffern haben und darf nicht "
            f"mit 0 beginnen (extension must be 2–4 digits, not starting with 0)"
        )
    if ext in RESERVED_EXACT or ext.startswith(RESERVED_PREFIX):
        raise ConfigError(
            f"{where}: Durchwahl {ext} kollidiert mit Not-/Servicerufnummern "
            f"(extension collides with emergency/service numbers)"
        )
    return ext


def load_model(config: dict, stored_secrets: dict | None = None) -> Model:
    stored_secrets = stored_secrets or {}
    stored_devices = (stored_secrets.get("devices") or {}) if stored_secrets else {}

    sysc = config.get("system") or {}
    mode = str(sysc.get("mode", "home")).lower()
    if mode not in ("home", "office"):
        raise ConfigError("system.mode: 'home' oder/or 'office'")
    rtp = sysc.get("rtp_ports", [10000, 10200])
    system = System(
        mode=mode,
        speedport_ip=str(_req(sysc, "speedport_ip", "system")),
        speedport_domain=str(sysc.get("speedport_domain") or sysc["speedport_ip"]),
        server_host=str(_req(sysc, "server_host", "system")),
        ws_port=int(sysc.get("ws_port", 8088)),
        rtp_start=int(rtp[0]),
        rtp_end=int(rtp[1]),
    )

    # Devices -------------------------------------------------------------
    raw_devices = config.get("devices") or []
    if not raw_devices:
        raise ConfigError("devices: mindestens ein Gerät / at least one device")
    raw_lines = config.get("lines") or []
    if not raw_lines:
        raise ConfigError("lines: mindestens eine Leitung / at least one line")
    line_ids = []
    for i, ln in enumerate(raw_lines):
        line_ids.append(_check_id(_req(ln, "id", f"lines[{i}]"), f"lines[{i}]"))
    if len(set(line_ids)) != len(line_ids):
        raise ConfigError("lines: doppelte ID / duplicate id")

    taken_ext: dict[str, str] = {}
    devices: list[Device] = []
    generated: dict[str, str] = {}
    for i, d in enumerate(raw_devices):
        where = f"devices[{i}]"
        did = _check_id(_req(d, "id", where), where)
        ext = _check_extension(_req(d, "extension", where), f"{where} ({did})")
        if ext in taken_ext:
            raise ConfigError(
                f"{where} ({did}): Durchwahl {ext} schon vergeben an "
                f"'{taken_ext[ext]}' (extension already used)"
            )
        taken_ext[ext] = did
        allowed = [str(x) for x in (d.get("lines") or line_ids)]
        for ln in allowed:
            if ln not in line_ids:
                raise ConfigError(f"{where} ({did}): unbekannte Leitung '{ln}'")
        default_line = str(d.get("line") or allowed[0])
        if default_line not in allowed:
            raise ConfigError(
                f"{where} ({did}): Standard-Leitung '{default_line}' ist nicht "
                f"in 'lines' erlaubt (default line not in allowed lines)"
            )
        pw = d.get("password", "auto")
        if pw == "CHANGE_ME":
            raise ConfigError(
                f"{where} ({did}): Passwort eintragen oder 'auto' (still CHANGE_ME)"
            )
        if pw in (None, "", "auto"):
            pw = stored_devices.get(did) or pysecrets.token_urlsafe(18)
            generated[did] = pw
        devices.append(
            Device(
                id=did,
                name=str(d.get("name") or did),
                extension=ext,
                line=default_line,
                lines=allowed,
                password=str(pw),
            )
        )
    device_ids = {d.id for d in devices}
    if len(device_ids) != len(devices):
        raise ConfigError("devices: doppelte ID / duplicate id")

    # Groups --------------------------------------------------------------
    groups: list[Group] = []
    for i, g in enumerate(config.get("groups") or []):
        where = f"groups[{i}]"
        gid = _check_id(_req(g, "id", where), where)
        if gid in device_ids:
            raise ConfigError(f"{where}: ID '{gid}' ist schon ein Gerät")
        ext = _check_extension(_req(g, "extension", where), f"{where} ({gid})")
        if ext in taken_ext:
            raise ConfigError(
                f"{where} ({gid}): Durchwahl {ext} schon vergeben an '{taken_ext[ext]}'"
            )
        taken_ext[ext] = gid
        members = [str(m) for m in (g.get("members") or [])]
        if not members:
            raise ConfigError(f"{where} ({gid}): 'members' ist leer")
        for m in members:
            if m not in device_ids:
                raise ConfigError(f"{where} ({gid}): unbekanntes Gerät '{m}'")
        groups.append(Group(gid, str(g.get("name") or gid), ext, members))
    group_map = {g.id: g for g in groups}

    # Lines ---------------------------------------------------------------
    lines: list[Line] = []
    for i, ln in enumerate(raw_lines):
        where = f"lines[{i}] ({line_ids[i]})"
        sp = ln.get("speedport") or {}
        password = str(_req(sp, "password", where + ".speedport"))
        for key in ("user", "auth", "password"):
            if str(sp.get(key, "")) == "CHANGE_ME":
                raise ConfigError(
                    f"{where}: speedport.{key} eintragen (still CHANGE_ME)"
                )
        ring_refs = ln.get("ring")
        if not ring_refs:
            if mode == "office":
                raise ConfigError(
                    f"{where}: im Büro-Modus ist 'ring' Pflicht (office mode requires 'ring')"
                )
            ring_refs = [d.id for d in devices]
        ring: list[str] = []
        for ref in ring_refs:
            ref = str(ref)
            if ref in device_ids:
                targets = [ref]
            elif ref in group_map:
                targets = group_map[ref].members
            else:
                raise ConfigError(f"{where}: 'ring' kennt '{ref}' nicht (unknown device/group)")
            for t in targets:
                if t not in ring:
                    ring.append(t)
        lines.append(
            Line(
                id=line_ids[i],
                label=str(ln.get("label") or line_ids[i]),
                number=str(ln.get("number") or ""),
                user=str(_req(sp, "user", where + ".speedport")),
                auth=str(sp.get("auth") or sp["user"]),
                password=password,
                ring=ring,
            )
        )

    return Model(system, lines, devices, groups, generated)


# --------------------------------------------------------------- rendering

HEADER = """; =============================================================================
;  ERZEUGT von Haustelefon – nicht von Hand bearbeiten, sondern haustelefon.yaml
;  ändern und ./setup.sh (oder generator/generate.py) erneut ausführen.
;  GENERATED by Haustelefon – edit haustelefon.yaml instead.
; =============================================================================
"""


def _label(line_id: str) -> str:
    return "ht_" + line_id.replace("-", "_")


def number_variants(number: str) -> list[str]:
    """Spellings under which a router may present a called number."""
    digits = re.sub(r"[^0-9+]", "", number)
    out: list[str] = []
    if not digits:
        return out
    if digits.startswith("+"):
        intl = digits[1:]
    elif digits.startswith("00"):
        intl = digits[2:]
    elif digits.startswith("0"):
        intl = "49" + digits[1:]
    else:
        intl = digits
    for v in ("+" + intl, intl, "00" + intl):
        out.append(v)
    if intl.startswith("49"):
        out.append("0" + intl[2:])
    return list(dict.fromkeys(out))


def render_pjsip(m: Model) -> str:
    s = m.system
    out = [HEADER]
    out.append(
        f"""[global]
type=global
user_agent=Haustelefon

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

; SIP über WebSocket für die Apps (http.conf, Port {s.ws_port}, Pfad /ws)
[transport-ws]
type=transport
protocol=ws
bind=0.0.0.0
"""
    )
    out.append("; ======================================================== LEITUNGEN / LINES\n")
    for ln in m.lines:
        out.append(
            f"""; ---- {ln.label} {ln.number}
[line-{ln.id}-auth]
type=auth
auth_type=userpass
username={ln.auth}
password={ln.password}

[line-{ln.id}-reg]
type=registration
transport=transport-udp
outbound_auth=line-{ln.id}-auth
server_uri=sip:{s.speedport_ip}:5060
client_uri=sip:{ln.user}@{s.speedport_domain}
contact_user={ln.user}
expiration=300
retry_interval=30
forbidden_retry_interval=120
max_retries=10000
line=yes
endpoint=line-{ln.id}

[line-{ln.id}]
type=aor
contact=sip:{s.speedport_ip}:5060
qualify_frequency=60

[line-{ln.id}]
type=endpoint
transport=transport-udp
context=line-in-{ln.id}
disallow=all
allow=alaw,ulaw,g722
outbound_auth=line-{ln.id}-auth
aors=line-{ln.id}
from_user={ln.user}
from_domain={s.speedport_domain}
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
dtmf_mode=rfc4733
send_pai=no
trust_id_inbound=yes

"""
        )
    out.append(
        f"""; Fallback für Router, die den line-Parameter nicht zurückgeben:
; Zuordnung dann per Rufnummer in [from-speedport].
[speedport-in]
type=endpoint
transport=transport-udp
context=from-speedport
disallow=all
allow=alaw,ulaw,g722
direct_media=no
rtp_symmetric=yes
force_rport=yes
dtmf_mode=rfc4733

[speedport-identify]
type=identify
endpoint=speedport-in
match={s.speedport_ip}

; ======================================================== GERÄTE / DEVICES
"""
    )
    for d in m.devices:
        out.append(
            f"""; ---- {d.name} (Durchwahl {d.extension})
[{d.id}-auth]
type=auth
auth_type=userpass
username={d.id}
password={d.password}

[{d.id}]
type=aor
max_contacts=1
remove_existing=yes
qualify_frequency=30

[{d.id}]
type=endpoint
transport=transport-ws
webrtc=yes
context=dev-{d.id}
disallow=all
allow=alaw,ulaw
auth={d.id}-auth
aors={d.id}
callerid="{d.name}" <{d.extension}>
dtmf_mode=rfc4733
direct_media=no

"""
        )
    return "".join(out)


def render_extensions(m: Model) -> str:
    out = [HEADER, "[general]\nstatic=yes\nwriteprotect=yes\n\n"]

    def dial_devices(ids: list[str]) -> str:
        return "&".join(f"PJSIP/{i}" for i in ids)

    # Header predial handlers + inbound per line
    for ln in m.lines:
        out.append(
            f"""; ------------------------------------------- Leitung {ln.label} {ln.number}
[hdr-{ln.id}]
exten => s,1,Set(PJSIP_HEADER(add,{LINE_HEADER})={ln.id})
 same => n,Return()

[line-in-{ln.id}]
exten => s,1,NoOp(Haustelefon: Anruf auf {ln.label} von ${{CALLERID(all)}})
 same => n,Dial({dial_devices(ln.ring)},45,b(hdr-{ln.id}^s^1))
 same => n,Hangup()
exten => _[0-9a-zA-Z*#+].,1,Goto(s,1)
exten => _[0-9a-zA-Z*#+],1,Goto(s,1)

"""
        )

    # Fallback dispatch by called number / contact user
    out.append("; Fallback-Zuordnung eingehender Anrufe per Rufnummer\n[from-speedport]\n")
    seen: set[str] = set()
    for ln in m.lines:
        for v in [ln.user, *number_variants(ln.number)]:
            if v and v not in seen:
                seen.add(v)
                out.append(f"exten => {v},1,Goto(line-in-{ln.id},s,1)\n")
    first = m.lines[0].id
    out.append(
        f"exten => _[0-9a-zA-Z*#+].,1,Goto(line-in-{first},s,1)\n"
        f"exten => s,1,Goto(line-in-{first},s,1)\n\n"
    )

    # Device contexts: internal extensions first (exact match wins over pattern)
    internal: list[str] = []
    for d in m.devices:
        internal.append(
            f"exten => {d.extension},1,Dial(PJSIP/{d.id},30)\n same => n,Hangup()\n"
        )
    for g in m.groups:
        internal.append(
            f"exten => {g.extension},1,Dial({dial_devices(g.members)},30)\n"
            f" same => n,Hangup()\n"
        )
    for d in m.devices:
        out.append(f"; ------------------------------------------- Gerät {d.name}\n[dev-{d.id}]\n")
        out.append("".join(internal))
        out.append(
            f"exten => _[0-9*#+].,1,Set(HT_LINE=${{PJSIP_HEADER(read,{LINE_HEADER})}})\n"
        )
        for ln_id in d.lines:
            if ln_id != d.line:
                out.append(
                    f' same => n,GotoIf($["${{HT_LINE}}" = "{ln_id}"]?{_label(ln_id)})\n'
                )
        out.append(
            f" same => n({_label(d.line)}),Dial(PJSIP/${{EXTEN}}@line-{d.line},90)\n"
            f" same => n,Hangup()\n"
        )
        for ln_id in d.lines:
            if ln_id != d.line:
                out.append(
                    f" same => n({_label(ln_id)}),Dial(PJSIP/${{EXTEN}}@line-{ln_id},90)\n"
                    f" same => n,Hangup()\n"
                )
        out.append("\n")
    return "".join(out)


def render_http(m: Model) -> str:
    return (
        HEADER
        + f"[general]\nenabled=yes\nbindaddr=0.0.0.0\nbindport={m.system.ws_port}\n"
    )


def render_rtp(m: Model) -> str:
    return (
        HEADER
        + f"[general]\nrtpstart={m.system.rtp_start}\nrtpend={m.system.rtp_end}\n"
        + "icesupport=yes\n"
    )


MODULES = HEADER + (
    "[modules]\nautoload=yes\n"
    # Alter SIP-Kanal würde Port 5060 belegen.
    "noload => chan_sip.so\n"
    # Nicht benötigt – erzeugen sonst nur Fehlermeldungen im Log.
    "noload => res_config_pgsql.so\n"
    "noload => res_config_ldap.so\n"
    "noload => chan_alsa.so\n"
    "noload => chan_console.so\n"
    "noload => res_phoneprov.so\n"
    # Beispiel-Wählpläne der Docker-Images (AEL/Lua) dürfen nicht mitlaufen.
    "noload => pbx_ael.so\n"
    "noload => pbx_lua.so\n"
    "noload => cel_pgsql.so\n"
    "noload => cel_sqlite3_custom.so\n"
    "noload => cdr_pgsql.so\n"
    "noload => res_hep.so\n"
    "noload => res_hep_pjsip.so\n"
    "noload => res_hep_rtcp.so\n"
    "noload => res_pjsip_phoneprov_provider.so\n"
    "noload => format_ogg_vorbis.so\n"
    "noload => cdr_sqlite3_custom.so\n"
    "noload => cdr_custom.so\n"
    "noload => cel_custom.so\n"
)


def provisioning_code(m: Model, d: Device) -> str:
    """Compact, copy-paste-friendly setup code for one device."""
    s = m.system
    payload = {
        "v": 1,
        "mode": s.mode,
        "ws": f"ws://{s.server_host}:{s.ws_port}/ws",
        "domain": s.server_host,
        "user": d.id,
        "pass": d.password,
        "name": d.name,
        "ext": d.extension,
        "line": d.line,
        "lines": [
            {"id": ln.id, "label": ln.label, "number": ln.number}
            for ln in m.lines
            if ln.id in d.lines
        ],
        "dir": [
            {"name": x.name, "ext": x.extension, "kind": "device"}
            for x in m.devices
            if x.id != d.id
        ]
        + [{"name": g.name, "ext": g.extension, "kind": "group"} for g in m.groups],
    }
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode()
    return PROVISION_PREFIX + base64.urlsafe_b64encode(raw).decode().rstrip("=")


def decode_provisioning(code: str) -> dict:
    data = code.strip()
    if not data.startswith(PROVISION_PREFIX):
        raise ValueError("kein Haustelefon-Code")
    data = data[len(PROVISION_PREFIX):]
    data += "=" * (-len(data) % 4)
    return json.loads(base64.urlsafe_b64decode(data))


# ------------------------------------------------------------------- main


def write_outputs(m: Model, out_dir: Path) -> list[Path]:
    ast = out_dir / "asterisk"
    prov = out_dir / "provisioning"
    ast.mkdir(parents=True, exist_ok=True)
    prov.mkdir(parents=True, exist_ok=True)
    files = {
        ast / "pjsip.conf": render_pjsip(m),
        ast / "extensions.conf": render_extensions(m),
        ast / "http.conf": render_http(m),
        ast / "rtp.conf": render_rtp(m),
        ast / "modules.conf": MODULES,
    }
    for d in m.devices:
        code = provisioning_code(m, d)
        lines = ", ".join(f"{ln.label} {ln.number}".strip() for ln in m.lines if ln.id in d.lines)
        files[prov / f"{d.id}.txt"] = (
            f"Haustelefon – {d.name} (Durchwahl / extension {d.extension})\n"
            f"Leitungen / lines: {lines}\n\n"
            "App: Einstellungen > Einrichtungscode einfügen\n"
            "App: Settings > Paste setup code\n\n"
            f"{code}\n\n"
            "ACHTUNG: Der Code enthält das Passwort – nur an diese Person weitergeben.\n"
            "WARNING: the code contains the password – share it only with this person.\n"
        )
    for path, text in files.items():
        path.write_text(text, encoding="utf-8", newline="\n")
    for path in prov.glob("*.txt"):
        if path.stem not in {d.id for d in m.devices}:
            path.unlink()  # removed device → remove its stale setup code
    return list(files)


def save_secrets(path: Path, m: Model, previous: dict) -> None:
    devices = dict((previous.get("devices") or {}))
    devices.update(m.generated_secrets)
    # Only keep secrets of devices that still exist.
    devices = {k: v for k, v in devices.items() if k in {d.id for d in m.devices}}
    text = (
        "# Automatisch erzeugte Passwörter – geheim halten, nicht einchecken.\n"
        "# Auto-generated passwords – keep secret, do not commit.\n"
        + yaml.safe_dump({"devices": devices}, allow_unicode=True, sort_keys=True)
    )
    path.write_text(text, encoding="utf-8", newline="\n")
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def main(argv: list[str] | None = None) -> int:
    # Windows-Konsolen (cp1252) sollen bei Sonderzeichen nicht abstürzen.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(errors="replace")
        except (AttributeError, ValueError):
            pass
    here = Path.cwd()
    ap = argparse.ArgumentParser(description="Haustelefon configuration generator")
    ap.add_argument("--config", default=str(here / "haustelefon.yaml"))
    ap.add_argument("--secrets", default=str(here / "secrets.yaml"))
    ap.add_argument("--out", default=str(here / "generated"))
    ap.add_argument("--check", action="store_true", help="nur prüfen / validate only")
    args = ap.parse_args(argv)

    cfg_path = Path(args.config)
    if not cfg_path.exists():
        print(
            f"{cfg_path} fehlt. Vorlage kopieren:  cp haustelefon.example.yaml haustelefon.yaml",
            file=sys.stderr,
        )
        return 2
    sec_path = Path(args.secrets)
    previous = yaml.safe_load(sec_path.read_text(encoding="utf-8")) if sec_path.exists() else {}
    try:
        config = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
        model = load_model(config, previous or {})
    except ConfigError as e:
        print(f"Konfigurationsfehler / config error: {e}", file=sys.stderr)
        return 1

    print(f"Modus/mode: {model.system.mode}   Server: {model.system.server_host}")
    for ln in model.lines:
        print(f"  Leitung {ln.label:<12} {ln.number:<18} -> {', '.join(ln.ring)}")
    for d in model.devices:
        print(f"  Gerät   {d.name:<12} Durchwahl {d.extension:<5} raus über {d.line}")
    for g in model.groups:
        print(f"  Gruppe  {g.name:<12} Durchwahl {g.extension:<5} = {', '.join(g.members)}")
    if args.check:
        print("OK - Konfiguration gültig / configuration valid")
        return 0

    out = Path(args.out)
    written = write_outputs(model, out)
    save_secrets(sec_path, model, previous or {})
    print(f"\n{len(written)} Dateien erzeugt in {out}/ - Einrichtungscodes: {out}/provisioning/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
