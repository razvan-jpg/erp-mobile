#!/usr/bin/env python3
"""Translate terms of service from Romanian to all app languages."""
from __future__ import annotations

import sys
import time
from pathlib import Path

from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parents[1]
LEGAL_DIR = ROOT / "ERP Mobile" / "Resources" / "Legal"
SOURCE = LEGAL_DIR / "terms-of-service-ro.txt"

LANG_TARGETS = {
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

KEEP = (
    "DATECONTA.RO",
    "ERP MOBILE",
    "ERP Mobile",
    "GDPR",
    "DPA",
    "DRM",
    "SLA",
    "iOS",
    "iPhone",
    "iPad",
    "FaceID",
    "TouchID",
    "Jailbreak",
    "UX/UI",
    "App Store",
    "Apple Inc.",
    "As Is",
)


def protect(text: str) -> tuple[str, dict[str, str]]:
    placeholders: dict[str, str] = {}
    for i, token in enumerate(KEEP):
        if token in text:
            key = f"__KEEP{i}__"
            placeholders[key] = token
            text = text.replace(token, key)
    return text, placeholders


def restore(text: str, placeholders: dict[str, str]) -> str:
    for key, token in placeholders.items():
        text = text.replace(key, token)
    return text


def chunk_text(text: str, max_len: int = 4500) -> list[str]:
    paragraphs = text.split("\n\n")
    chunks: list[str] = []
    current = ""
    for para in paragraphs:
        candidate = f"{current}\n\n{para}".strip() if current else para
        if len(candidate) <= max_len:
            current = candidate
        else:
            if current:
                chunks.append(current)
            if len(para) <= max_len:
                current = para
            else:
                lines = para.splitlines(keepends=True)
                block = ""
                for line in lines:
                    if len(block) + len(line) > max_len and block:
                        chunks.append(block.rstrip())
                        block = line
                    else:
                        block += line
                current = block.rstrip()
    if current:
        chunks.append(current)
    return chunks


def translate_file(text: str, target: str) -> str:
    translator = GoogleTranslator(source="ro", target=target)
    chunks = chunk_text(text)
    out: list[str] = []
    for i, chunk in enumerate(chunks, 1):
        print(f"    chunk {i}/{len(chunks)}", flush=True)
        protected, placeholders = protect(chunk)
        translated = translator.translate(protected)
        out.append(restore(translated, placeholders))
        time.sleep(0.35)
    return "\n\n".join(out)


def main() -> int:
    if not SOURCE.exists():
        print(f"Missing source: {SOURCE}", file=sys.stderr)
        return 1

    text = SOURCE.read_text(encoding="utf-8")
    LEGAL_DIR.mkdir(parents=True, exist_ok=True)

    for code, google in LANG_TARGETS.items():
        dest = LEGAL_DIR / f"terms-of-service-{code}.txt"
        print(f"→ {code}", flush=True)
        try:
            translated = translate_file(text, google)
            dest.write_text(translated, encoding="utf-8")
            print(f"✓ {dest.name}", flush=True)
        except Exception as exc:
            print(f"✗ {code}: {exc}", file=sys.stderr)
            return 1

    print("Done.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
