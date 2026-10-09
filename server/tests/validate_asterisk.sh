#!/usr/bin/env bash
# =============================================================================
#  Integration test: generate the configuration from haustelefon.example.yaml,
#  boot a real Asterisk with it and check that everything loads and routes.
#  Used by CI; runs locally too (needs Docker + Python 3 with PyYAML).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="${ASTERISK_IMAGE:-andrius/asterisk:latest}"
NAME="haustelefon-ci-$$"
TMP="$(mktemp -d)"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT

python3 - "$TMP" <<'EOF'
import sys, yaml
tmp = sys.argv[1]
cfg = yaml.safe_load(open("haustelefon.example.yaml", encoding="utf-8"))
for line in cfg["lines"]:
    line["speedport"]["password"] = "ci-" + line["id"]
yaml.safe_dump(cfg, open(f"{tmp}/haustelefon.yaml", "w", encoding="utf-8"), allow_unicode=True)
EOF
python3 generator/generate.py --config "$TMP/haustelefon.yaml" \
  --secrets "$TMP/secrets.yaml" --out "$TMP/generated" >/dev/null

mounts=()
for f in pjsip extensions http rtp modules; do
  mounts+=(-v "$TMP/generated/asterisk/$f.conf:/etc/asterisk/$f.conf:ro")
done
docker run -d --name "$NAME" "${mounts[@]}" "$IMAGE" >/dev/null

ax() { docker exec "$NAME" asterisk -rx "$1"; }
for _ in $(seq 1 30); do
  ax "core show uptime" >/dev/null 2>&1 && break
  sleep 1
done
sleep 3

fail=0
check() {  # check <description> <command> <grep-pattern>
  if ax "$2" | grep -qE "$3"; then echo "ok    $1"; else echo "FAIL  $1"; fail=1; fi
}

errors="$(docker logs "$NAME" 2>&1 | grep 'ERROR' \
  | grep -vE 'Unable to connect|No route|unreachable|cannot assign|Temporary failure' || true)"
if [ -n "$errors" ]; then echo "FAIL  Asterisk reported errors:"; echo "$errors"; fail=1
else echo "ok    no errors while loading"; fi

endpoints="$(ax 'pjsip show endpoints' | grep -cE '^ Endpoint:  [a-z]' || true)"
if [ "$endpoints" = "6" ]; then echo "ok    6 endpoints (3 devices, 2 lines, fallback)"
else echo "FAIL  expected 6 endpoints, got $endpoints"; fail=1; fi

check "one registration per line"      "pjsip show registrations" "line-firma-reg"
check "WebSocket transport for apps"   "http show status"         "/ws => Asterisk HTTP WebSocket"
check "extension 12 rings Anna"        "dialplan show 12@dev-handy"   "Dial\(PJSIP/anna,30\)"
check "group 20 rings PC + Anna"       "dialplan show 20@dev-handy"   "Dial\(PJSIP/pc&PJSIP/anna,30\)"
check "handy may choose line 'firma'"  "dialplan show 0301234567@dev-handy" "ht_firma"
check "inbound 'firma' rings group"    "dialplan show s@line-in-firma" "b\(hdr-firma\^s\^1\)"
check "fallback dispatch by user id"   "dialplan show **72@from-speedport" "line-in-firma"
if ax "dialplan show 0301234567@dev-anna" | grep -q "line-privat"; then
  echo "FAIL  anna can reach line 'privat'"; fail=1
else echo "ok    anna is restricted to line 'firma'"; fi
if ax "dialplan show" | grep -qE "Context '(demo|default|ael-)"; then
  echo "FAIL  sample dialplans of the image are active"; fail=1
else echo "ok    only Haustelefon dialplan contexts"; fi

exit "$fail"
