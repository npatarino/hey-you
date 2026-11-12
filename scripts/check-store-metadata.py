#!/usr/bin/env python3
"""Checks docs/store/metadata against App Store Connect's length limits. Exits 1 if a field is too long."""
import pathlib
import sys

LIMITS = {
    "name": 30, "subtitle": 30, "keywords": 100, "promotional_text": 170,
    "description": 4000, "release_notes": 4000, "iap_name": 35, "iap_description": 55,
}
root = pathlib.Path(__file__).resolve().parent.parent / "docs" / "store" / "metadata"
failed = False
for locale in sorted(p for p in root.iterdir() if p.is_dir()):
    for field, limit in LIMITS.items():
        path = locale / f"{field}.txt"
        if not path.exists():
            print(f"MISSING  {locale.name}/{field}.txt")
            failed = True
            continue
        length = len(path.read_text(encoding="utf-8").strip())
        status = "ok" if length <= limit else "TOO LONG"
        failed |= length > limit
        print(f"{status:8} {locale.name}/{field}: {length}/{limit}")
sys.exit(1 if failed else 0)
