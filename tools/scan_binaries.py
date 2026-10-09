#!/usr/bin/env python3
"""Scan build output (exe, dll, so, apk, zip) for personal data.

    python tools/scan_binaries.py <file-or-folder> [...]

Compilers embed build paths (e.g. C:\\Users\\<you>\\...) into binaries. This
checks every file - and every member of apk/zip archives - for the generic
user-path pattern and the private patterns from tools/private_patterns.txt,
both as ASCII/UTF-8 and as UTF-16LE (Windows strings). Exit code 1 on hits.
"""

from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from make_release import GENERIC_PATTERNS, private_patterns  # noqa: E402


def compile_patterns() -> list[tuple[str, re.Pattern[bytes]]]:
    out = []
    for p in GENERIC_PATTERNS + private_patterns():
        out.append((p, re.compile(p.encode("utf-8"), re.IGNORECASE)))
    return out


def hits_in(data: bytes, patterns) -> list[str]:
    found = []
    # UTF-16LE strings: drop the zero bytes of ASCII characters.
    narrow = data.replace(b"\x00", b"") if b"\x00" in data else data
    for name, rx in patterns:
        m = rx.search(data) or rx.search(narrow)
        if m:
            s = max(0, m.start() - 20)
            ctx = (m.string[s:m.end() + 40]).decode("utf-8", "replace")
            found.append(f"{name}: ...{ctx!r}...")
    return found


def scan_file(path: Path, patterns, label: str | None = None) -> list[str]:
    label = label or str(path)
    results = []
    if path.suffix.lower() in {".apk", ".zip", ".aab", ".jar"}:
        with zipfile.ZipFile(path) as z:
            for info in z.infolist():
                if info.is_dir():
                    continue
                for h in hits_in(z.read(info), patterns):
                    results.append(f"{label}!{info.filename}: {h}")
        return results
    return [f"{label}: {h}" for h in hits_in(path.read_bytes(), patterns)]


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    patterns = compile_patterns()
    results = []
    for arg in argv:
        p = Path(arg)
        files = [f for f in p.rglob("*") if f.is_file()] if p.is_dir() else [p]
        for f in files:
            results += scan_file(f, patterns)
    for r in results:
        print("LEAK", r)
    print(f"{len(results)} hit(s)")
    return 1 if results else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
