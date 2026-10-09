#!/usr/bin/env python3
"""Create / update the public release repository next to this project.

    python tools/make_release.py [--target ../Haustelefon-Upload/Haustelefon] [--no-commit]

1. Copies the project (without build output) into the target folder.
2. Lets git apply .gitignore and removes every ignored file from the copy
   (your real haustelefon.yaml, secrets, generated configs, private notes …).
3. Scans all remaining files for personal data and aborts if something is found.
4. Commits the result (a fresh repository on first run).

Private strings to block: tools/private_patterns.txt (git-ignored) or --private.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Never even copied (large or machine-specific).
SKIP_DIRS = {
    ".git", ".dart_tool", ".idea", "build", ".gradle", "Pods",
    "__pycache__", "ephemeral", ".cxx",
}

# Generic leak: local user paths. Your own private strings (name, e-mail, IPs,
# phone numbers) go into tools/private_patterns.txt – one regex per line. That
# file is git-ignored, so the patterns themselves are never published.
GENERIC_PATTERNS = [r"[A-Za-z]:[\\/]+Users[\\/]+\w"]
PRIVATE_FILE = ROOT / "tools" / "private_patterns.txt"


def private_patterns() -> list[str]:
    if not PRIVATE_FILE.exists():
        return []
    lines = PRIVATE_FILE.read_text(encoding="utf-8").splitlines()
    return [ln.strip() for ln in lines if ln.strip() and not ln.startswith("#")]


def run(cmd: list[str], cwd: Path, check: bool = True) -> str:
    res = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                         encoding="utf-8", errors="replace")
    if check and res.returncode != 0:
        sys.exit(f"{' '.join(cmd)} failed:\n{res.stdout}{res.stderr}")
    return res.stdout


def copy_tree(src: Path, dst: Path) -> int:
    count = 0
    for dirpath, dirnames, filenames in os.walk(src):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        rel = Path(dirpath).relative_to(src)
        if rel.parts and rel.parts[0] == dst.name:
            continue
        (dst / rel).mkdir(parents=True, exist_ok=True)
        for f in filenames:
            shutil.copy2(Path(dirpath) / f, dst / rel / f)
            count += 1
    return count


def clear_worktree(dst: Path) -> None:
    for entry in dst.iterdir():
        if entry.name == ".git":
            continue
        if entry.is_dir():
            shutil.rmtree(entry)
        else:
            entry.unlink()


def scan(dst: Path, patterns: list[str]) -> list[str]:
    hits = []
    regex = re.compile("|".join(patterns), re.IGNORECASE)
    for name in run(["git", "ls-files", "--cached", "--others", "--exclude-standard"], dst).splitlines():
        path = dst / name
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue  # binary
        for i, line in enumerate(text.splitlines(), 1):
            if regex.search(line):
                hits.append(f"{name}:{i}: {line.strip()[:120]}")
    return hits


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--target", default=str(ROOT.parent / "Haustelefon-Upload" / "Haustelefon"))
    ap.add_argument("--private", action="append", default=[],
                    help="additional private regex (repeatable)")
    ap.add_argument("--no-commit", action="store_true")
    args = ap.parse_args()

    dst = Path(args.target).resolve()
    if dst == ROOT or ROOT in dst.parents:
        sys.exit("target must be outside the project folder")
    dst.mkdir(parents=True, exist_ok=True)
    fresh = not (dst / ".git").exists()
    if fresh:
        run(["git", "init", "-b", "main"], dst)
    else:
        clear_worktree(dst)

    copied = copy_tree(ROOT, dst)
    # .gitignore entscheidet, was öffentlich ist: Ignoriertes wird entfernt.
    run(["git", "clean", "-fdX", "-q"], dst)
    run(["git", "add", "-A"], dst)
    tracked = run(["git", "ls-files"], dst).splitlines()
    print(f"{copied} Dateien kopiert, {len(tracked)} im Release.")

    for required in ("README.md", "LICENSE", "server/haustelefon.example.yaml"):
        if required not in tracked:
            sys.exit(f"missing in release: {required}")
    for forbidden in ("server/haustelefon.yaml", "server/secrets.yaml", "docs/MEIN-SETUP.md"):
        if forbidden in tracked:
            sys.exit(f"private file would be published: {forbidden}")

    hits = scan(dst, GENERIC_PATTERNS + private_patterns() + args.private)
    if hits:
        print("\nPERSÖNLICHE DATEN GEFUNDEN – nichts committet:")
        print("\n".join(hits))
        return 1
    print("Datenschutz-Check: keine persönlichen Daten gefunden.")

    if args.no_commit:
        return 0
    if not run(["git", "status", "--porcelain"], dst).strip():
        print("Keine Änderungen seit dem letzten Release-Commit.")
        return 0
    version = re.search(r"^version:\s*(\S+)", (ROOT / "pubspec.yaml").read_text(encoding="utf-8"), re.M)
    msg = f"Haustelefon {version.group(1).split('+')[0] if version else ''}".strip()
    if fresh:
        msg += " – initial public release"
    run(["git", "commit", "-q", "-m", msg], dst)
    print(run(["git", "log", "--oneline", "-1"], dst).strip())
    print(f"\nFertig: {dst}")
    print("Hochladen: GitHub-Repo anlegen, dann  git remote add origin <url> && git push -u origin main")
    return 0


if __name__ == "__main__":
    sys.exit(main())
