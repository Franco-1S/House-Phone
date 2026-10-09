#!/usr/bin/env python3
"""Build everything for a GitHub release into one folder (Windows host).

    python tools/make_upload.py [--out ../Haustelefon-Upload] [--skip-build]

Result:
    Haustelefon-Upload/
      Haustelefon/                  public git repo (tools/make_release.py)
      downloads/                    attachments for the GitHub release
        Haustelefon-<v>-android.apk
        Haustelefon-<v>-windows-x64.zip
        Haustelefon-<v>-server.zip
        SHA256SUMS.txt

Builds run from a copy of the public repo mapped to a virtual drive
(subst X: -> X:\\haustelefon). Flutter embeds the project path into the app
binary - this way it is "X:/haustelefon/..." instead of your user folder.
Every artifact is scanned for personal data (tools/scan_binaries.py).
Android release signing: android/key.properties + keystore are copied into
the build copy only, never into the repo.
"""

from __future__ import annotations

import argparse
import glob
import hashlib
import os
import re
import shutil
import string
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"


def sh(cmd: list[str] | str, cwd: Path | None = None, check: bool = True) -> int:
    print(f"\n$ {cmd if isinstance(cmd, str) else ' '.join(cmd)}", flush=True)
    res = subprocess.run(cmd, cwd=cwd, shell=isinstance(cmd, str))
    if check and res.returncode != 0:
        sys.exit(f"failed ({res.returncode})")
    return res.returncode


def version() -> str:
    m = re.search(r"^version:\s*(\S+)", (ROOT / "pubspec.yaml").read_text(encoding="utf-8"), re.M)
    return m.group(1).split("+")[0] if m else "0.0.0"


def free_drive() -> str:
    for letter in reversed(string.ascii_uppercase[7:]):  # Z: .. H:
        if not os.path.exists(f"{letter}:\\"):
            return f"{letter}:"
    sys.exit("no free drive letter for subst")


def vc_runtime() -> list[Path]:
    """App-local VC++ runtime, so the zip runs on PCs without the redistributable."""
    pattern = (r"C:\Program Files*\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*"
               r"\x64\Microsoft.VC14*.CRT")
    dirs = sorted(glob.glob(pattern), key=lambda d: [int(x) for x in re.findall(r"\d+", Path(d).parent.parent.name)])
    if not dirs:
        print("WARNING: VC++ redistributable not found - zip needs it installed")
        return []
    names = ["msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "vcruntime140.dll", "vcruntime140_1.dll"]
    return [Path(dirs[-1]) / n for n in names if (Path(dirs[-1]) / n).exists()]


def zip_dir(zf: zipfile.ZipFile, src: Path, prefix: str) -> None:
    for path in sorted(src.rglob("*")):
        if path.is_file():
            zf.write(path, f"{prefix}/{path.relative_to(src).as_posix()}")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", default=str(ROOT.parent / "Haustelefon-Upload"))
    ap.add_argument("--skip-build", action="store_true",
                    help="reuse the build copy from the last run (only re-package)")
    args = ap.parse_args()
    if os.name != "nt":
        sys.exit("make_upload.py builds the Windows app and needs Windows")

    out = Path(args.out).resolve()
    repo = out / "Haustelefon"
    downloads = out / "downloads"
    v = version()

    # 1. Public repository (privacy scan + commit).
    sh([sys.executable, str(TOOLS / "make_release.py"), "--target", str(repo)])

    # 2. Neutral build copy: <tmp>/hbroot/haustelefon  ->  X:\haustelefon
    build_root = Path(tempfile.gettempdir()) / "haustelefon-build"
    work = build_root / "haustelefon"
    drive = free_drive()
    if not args.skip_build:
        sh(["robocopy", str(repo), str(work), "/MIR", "/XD", ".git", "build", ".dart_tool",
            "ephemeral", "/NFL", "/NDL", "/NJH", "/NJS", "/NP"], check=False)
        for f in ("key.properties", "haustelefon-release.jks"):
            if (ROOT / "android" / f).exists():
                shutil.copy2(ROOT / "android" / f, work / "android" / f)
            else:
                print(f"NOTE: android/{f} missing - APK gets the debug signature")
        # Project on X:, pub cache on C: - Kotlin's incremental caches can't
        # handle sources on two drives ("Could not close incremental caches").
        with (work / "android" / "gradle.properties").open("a", encoding="utf-8") as f:
            f.write("\nkotlin.incremental=false\n")
    sh(["subst", drive, str(build_root)])
    try:
        x = Path(f"{drive}\\haustelefon")
        if not args.skip_build:
            # Windows first: it links the plugin folders as junctions. Without
            # them (and without Developer Mode) "flutter build apk" refuses to run.
            sh(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                str(x / "tools" / "install_windows.ps1"), "-NoInstall"], cwd=x)
            sh("flutter build apk --release", cwd=x)
        apk_src = x / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
        win_src = x / "build" / "windows" / "x64" / "runner" / "Release"

        # 3. Package.
        if downloads.exists():
            shutil.rmtree(downloads)
        downloads.mkdir(parents=True)
        apk = downloads / f"Haustelefon-{v}-android.apk"
        shutil.copy2(apk_src, apk)

        win = downloads / f"Haustelefon-{v}-windows-x64.zip"
        top = f"Haustelefon-{v}-windows-x64"
        with zipfile.ZipFile(win, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
            zip_dir(zf, win_src, f"{top}/app")
            for dll in vc_runtime():
                zf.write(dll, f"{top}/app/{dll.name}")
            for f in (TOOLS / "windows-package").iterdir():
                zf.write(f, f"{top}/{f.name}")
            zf.write(repo / "LICENSE", f"{top}/LICENSE.txt")
    finally:
        sh(["subst", drive, "/D"], check=False)

    server = downloads / f"Haustelefon-{v}-server.zip"
    with zipfile.ZipFile(server, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path in sorted((repo / "server").rglob("*")):
            if path.is_file():
                info = zipfile.ZipInfo.from_file(path, f"haustelefon-server/{path.relative_to(repo / 'server').as_posix()}")
                if path.suffix in (".sh", ".py"):
                    info.external_attr = (0o100755 << 16)  # keep ./setup.sh executable
                info.compress_type = zipfile.ZIP_DEFLATED
                zf.writestr(info, path.read_bytes())
        zf.write(repo / "LICENSE", "haustelefon-server/LICENSE")
        for readme in ("README.md", "README.de.md"):
            zf.write(repo / readme, f"haustelefon-server/{readme}")

    # 4. Privacy scan of everything that gets uploaded.
    sh([sys.executable, str(TOOLS / "scan_binaries.py"), str(downloads)])
    for forbidden in ("haustelefon.yaml", "secrets.yaml", "key.properties", ".jks"):
        for z in downloads.glob("*.zip"):
            names = zipfile.ZipFile(z).namelist()
            bad = [n for n in names if n.endswith(forbidden) and "example" not in n]
            if bad:
                sys.exit(f"private file in {z.name}: {bad}")

    sums = downloads / "SHA256SUMS.txt"
    sums.write_text("".join(f"{sha256(p)}  {p.name}\n" for p in sorted(downloads.iterdir())
                            if p != sums), encoding="utf-8")
    print("\nDownloads:")
    for p in sorted(downloads.iterdir()):
        print(f"  {p.name:42} {p.stat().st_size / 1e6:7.1f} MB")
    print(f"\nFertig: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
