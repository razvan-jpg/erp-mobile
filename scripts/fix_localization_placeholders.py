#!/usr/bin/env python3
"""Fix missing format placeholders in localization JSON files."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOC_DIR = ROOT / "ERP Mobile" / "Resources" / "Localization"
PLACEHOLDER_PATTERN = re.compile(r"%[@dlf]|%[\d]+\$[@dlfs]")


def fix_value(en_value: str, translated: str) -> str:
    expected = PLACEHOLDER_PATTERN.findall(en_value)
    if not expected:
        return translated

    actual = PLACEHOLDER_PATTERN.findall(translated)
    if actual == expected:
        return translated

    if len(actual) == len(expected):
        result = translated
        for wrong, right in zip(actual, expected):
            result = result.replace(wrong, right, 1)
        return result

    result = PLACEHOLDER_PATTERN.sub("", translated).rstrip()
    if ":" in en_value and en_value.rstrip().endswith(expected[-1]):
        if not result.endswith(":"):
            result += ":"
        result += f" {expected[-1]}"
        return result

    for token in expected:
        if token not in result:
            result += f" {token}"
    return result


def main() -> None:
    targets = sys.argv[1:] or [
        p.stem for p in sorted(LOC_DIR.glob("*.json")) if p.stem not in {"ro", "en"}
    ]

    with (LOC_DIR / "en.json").open(encoding="utf-8") as f:
        en_data: dict[str, str] = json.load(f)

    for lang in targets:
        path = LOC_DIR / f"{lang}.json"
        with path.open(encoding="utf-8") as f:
            data: dict[str, str] = json.load(f)

        fixed_count = 0
        for key, en_value in en_data.items():
            current = data.get(key, en_value)
            repaired = fix_value(en_value, current)
            if repaired != current:
                data[key] = repaired
                fixed_count += 1

        with path.open("w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        print(f"✓ {lang}: fixed {fixed_count} entries", flush=True)


if __name__ == "__main__":
    main()
