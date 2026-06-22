"""ocr_normalizer.py — Clean OCR artifacts before numeric parsing."""
from __future__ import annotations

import re


def normalize_numeric_text(text: str) -> str:
    """Convert common OCR numeric artifacts to parseable strings.

    Examples:
        ``59 . 1`` → ``59.1``
        ``156.9cm`` → ``156.9``
        ``1,234.5`` → ``1234.5``
        ``I8 8`` → ``18.8``
    """
    cleaned = text.strip()
    
    # Common OCR letter-to-number misreads
    if cleaned.startswith("I") and len(cleaned) >= 2 and cleaned[1].isdigit():
        cleaned = "1" + cleaned[1:]
    elif cleaned.startswith("l") and len(cleaned) >= 2 and cleaned[1].isdigit():
        cleaned = "1" + cleaned[1:]
        
    if "," in cleaned and "." not in cleaned:
        cleaned = cleaned.replace(",", ".")
    else:
        cleaned = cleaned.replace(",", "")
        
    cleaned = re.sub(r"\s*\.\s*", ".", cleaned)
    # If there's a space between numbers and no dot exists, we still want I8 8 to be parsed if possible.
    # We will do that by replacing space with dot ONLY if it has an exact pattern of 1-3 digits, space, 1 digit.
    if re.fullmatch(r"\d{1,3}\s\d", cleaned):
        cleaned = cleaned.replace(" ", ".")

    match = re.search(r"-?\d+(?:\.\d+)?", cleaned)
    return match.group(0) if match else ""


def parse_normalized_float(text: str) -> float | None:
    cleaned = normalize_numeric_text(text)
    if not cleaned or cleaned in {"-", ".", "-."}:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None
