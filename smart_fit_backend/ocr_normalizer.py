"""ocr_normalizer.py — Clean OCR artifacts before numeric parsing."""
from __future__ import annotations

import re


def normalize_numeric_text(text: str) -> str:
    """Convert common OCR numeric artifacts to parseable strings.

    Examples:
        ``59 . 1`` → ``59.1``
        ``156.9cm`` → ``156.9``
        ``1,234.5`` → ``1234.5``
    """
    cleaned = text.strip()
    cleaned = cleaned.replace(",", "")
    cleaned = re.sub(r"\s*\.\s*", ".", cleaned)
    cleaned = re.sub(r"[^\d.\-]", "", cleaned)
    if cleaned.count(".") > 1:
        parts = cleaned.split(".")
        cleaned = parts[0] + "." + "".join(parts[1:])
    return cleaned


def parse_normalized_float(text: str) -> float | None:
    cleaned = normalize_numeric_text(text)
    if not cleaned or cleaned in {"-", ".", "-."}:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None
