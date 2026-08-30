#!/usr/bin/env python3
"""Generate native localization JSON files for all 20 app languages."""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parents[1]
LOC_DIR = ROOT / "ERP Mobile" / "Resources" / "Localization"

LANG_TARGETS: dict[str, str] = {
    "ro": "ro",
    "en": "en",
    "fr": "fr",
    "it": "it",
    "es": "es",
    "de": "de",
    "pl": "pl",
    "cs": "cs",
    "sr": "sr",
    "hu": "hu",
    "ru": "ru",
    "bg": "bg",
    "tr": "tr",
    "ne": "ne",
    "ko": "ko",
    "zh-Hans": "zh-CN",
    "ja": "ja",
    "ar": "ar",
    "th": "th",
    "nl": "nl",
}

PLACEHOLDER_PATTERN = re.compile(r"%[@dlf]|%[\d]+\$[@dlfs]")

KEEP_LITERAL = (
    "ERP Mobile",
    "Dateconta",
    "ANAF",
    "Supabase",
    "IBAN",
    "CUI",
    "OK",
    "GDPR",
    "PDF",
    "WhatsApp",
    "Superadmin",
)


def log(message: str) -> None:
    print(message, flush=True)


def protect_placeholders(text: str) -> tuple[str, list[str]]:
    tokens: list[str] = []

    def repl(match: re.Match[str]) -> str:
        tokens.append(match.group(0))
        # Private-use markers unlikely to be altered by MT
        return f"\uE000{len(tokens) - 1}\uE001"

    return PLACEHOLDER_PATTERN.sub(repl, text), tokens


def restore_placeholders(text: str, tokens: list[str]) -> str:
    result = text
    for index, token in enumerate(tokens):
        marker = f"\uE000{index}\uE001"
        result = result.replace(marker, token)
        result = result.replace(f"PH{index}", token)
        result = re.sub(rf"\bPH{index}\b", token, result)
    return force_placeholders_from_source(text, result, tokens)


def force_placeholders_from_source(source: str, translated: str, expected: list[str]) -> str:
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

    # Rebuild: translate only text segments between placeholders
    parts = PLACEHOLDER_PATTERN.split(source)
    if len(parts) == len(expected) + 1:
        rebuilt: list[str] = []
        for index, part in enumerate(parts):
            if index < len(parts) - 1:
                segment = translated
                if index == 0 and part:
                    segment = translated.split(expected[0])[0] if expected[0] in translated else translated
                rebuilt.append(part if not part.strip() else segment if index == 0 else "")
                rebuilt.append(expected[index])
            else:
                rebuilt.append(part)
        # Simpler fallback: append missing placeholders from English positions
        result = PLACEHOLDER_PATTERN.sub("", translated)
        for token in expected:
            if token not in result:
                if ":" in source and source.strip().endswith(token):
                    result = result.rstrip() + f" {token}"
                else:
                    result = result.rstrip() + token
        return result

    result = translated
    for token in expected:
        if token not in result:
            result = result.rstrip() + f" {token}"
    return result


def protect_literals(text: str) -> tuple[str, list[tuple[str, str]]]:
    preserved: list[tuple[str, str]] = []

    def repl(match: re.Match[str]) -> str:
        preserved.append((f"LIT{len(preserved)}", match.group(0)))
        return preserved[-1][0]

    pattern = re.compile(
        r"\b(" + "|".join(re.escape(word) for word in sorted(KEEP_LITERAL, key=len, reverse=True)) + r")\b"
    )
    return pattern.sub(repl, text), preserved


def restore_literals(text: str, preserved: list[tuple[str, str]]) -> str:
    result = text
    for token, literal in preserved:
        result = result.replace(token, literal)
    return result


def translate_batch(texts: list[str], translator: GoogleTranslator, chunk_size: int = 12) -> list[str]:
    results: list[str] = []
    total = len(texts)

    for start in range(0, total, chunk_size):
        chunk = texts[start : start + chunk_size]
        protected_chunks: list[str] = []
        literal_maps: list[list[tuple[str, str]]] = []
        placeholder_maps: list[list[str]] = []

        for text in chunk:
            protected, literals = protect_literals(text)
            protected, placeholders = protect_placeholders(protected)
            protected_chunks.append(protected)
            literal_maps.append(literals)
            placeholder_maps.append(placeholders)

        translated_chunk: list[str | None] = []
        for attempt in range(6):
            try:
                translated_chunk = translator.translate_batch(protected_chunks)
                break
            except Exception as error:
                log(f"    retry {attempt + 1}: {error}")
                time.sleep(1.5 * (attempt + 1))
        else:
            translated_chunk = list(chunk)

        for original, translated, literals, placeholders in zip(
            chunk, translated_chunk, literal_maps, placeholder_maps
        ):
            if not translated:
                results.append(original)
                continue
            fixed = restore_placeholders(translated, placeholders)
            fixed = restore_literals(fixed, literals)
            results.append(fixed)

        log(f"    {min(start + chunk_size, total)}/{total}")
        time.sleep(0.25)

    return results


def main() -> None:
    only = sys.argv[1:] if len(sys.argv) > 1 else []

    with (LOC_DIR / "ro.json").open(encoding="utf-8") as f:
        ro_data: dict[str, str] = json.load(f)

    with (LOC_DIR / "en.json").open(encoding="utf-8") as f:
        en_data: dict[str, str] = json.load(f)

    keys = list(ro_data.keys())
    sources = [en_data[key] for key in keys]
    targets = LANG_TARGETS.items()
    if only:
        targets = [(code, google) for code, google in LANG_TARGETS.items() if code in only]

    log(f"Translating {len(keys)} keys…")

    for lang_code, google_code in targets:
        out_path = LOC_DIR / f"{lang_code}.json"
        if lang_code == "ro":
            data = ro_data
        elif lang_code == "en":
            data = en_data
        else:
            log(f"→ {lang_code} ({google_code})")
            translator = GoogleTranslator(source="en", target=google_code)
            translated_values = translate_batch(sources, translator)
            data = dict(zip(keys, translated_values))

        with out_path.open("w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        log(f"✓ {lang_code}.json")

    log("Done.")


if __name__ == "__main__":
    main()
