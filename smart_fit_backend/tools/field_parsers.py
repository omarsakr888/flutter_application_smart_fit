"""field_parsers.py -- Dedicated per-field OCR text parsers for InBody scans.

Each function takes raw OCR text and returns a clean, validated Python value
(float or None). These are intentionally strict: if the value doesn't make
biological sense for the field, None is returned and the extraction is flagged
for manual review.
"""
from __future__ import annotations

import re
from pathlib import Path
import sys

# Allow importing ocr_normalizer from the parent backend directory
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ocr_normalizer import parse_normalized_float


def parse_numeric(text: str, valid_min: float, valid_max: float) -> float | None:
    """Extract first valid float from OCR text that falls within [valid_min, valid_max]."""
    if not text:
        return None
    # Try the whole cleaned string first
    v = parse_normalized_float(text)
    if v is not None and valid_min <= v <= valid_max:
        return round(v, 3)
    # Split on whitespace/commas and try each token
    for token in re.split(r"[\s,;:]+", text):
        token_clean = re.sub(r"[^0-9.\-]", "", token)
        v = parse_normalized_float(token_clean)
        if v is not None and valid_min <= v <= valid_max:
            return round(v, 3)
    return None


def parse_age(text: str) -> float | None:
    """Return integer age in [10, 110] or None."""
    v = parse_numeric(text.strip(), 10, 110)
    return float(int(v)) if v is not None else None


def parse_gender(text: str) -> float | None:
    """Return 0.0 (Female) or 1.0 (Male) or None."""
    t = text.lower().strip()
    if "female" in t or t in {"f", "fem"}:
        return 0.0
    if "male" in t or t in {"m", "mal"}:
        return 1.0
    return None


def parse_height_metric(text: str) -> float | None:
    """Parse metric height: '156.9cm', '156.9 cm', '156. 9', etc. -> cm."""
    cleaned = text.lower()
    cleaned = cleaned.replace("cmn", "").replace("cm", "").strip()
    # Merge split OCR: "156." + " 9" -> "156.9"
    cleaned = re.sub(r"(\d+)\s*\.\s*(\d+)", r"\1.\2", cleaned)
    v = parse_normalized_float(cleaned)
    if v is not None and 100 <= v <= 230:
        return round(v, 1)
    # Try extracting a 3-digit number
    m = re.search(r"(\d{3}(?:\.\d+)?)", cleaned)
    if m:
        v = parse_normalized_float(m.group(1))
        if v is not None and 100 <= v <= 230:
            return round(v, 1)
    return None


def parse_height_imperial(text: str) -> float | None:
    """Parse imperial height: '5 ft 05.0 in' -> cm."""
    m = re.search(r"(\d+)\s*ft\s*(\d+(?:\.\d+)?)\s*in", text, re.IGNORECASE)
    if m:
        cm = (float(m.group(1)) * 12 + float(m.group(2))) * 2.54
        if 100 <= cm <= 230:
            return round(cm, 1)
    # Feet only: "5 ft"
    m = re.search(r"(\d+)\s*ft", text, re.IGNORECASE)
    if m:
        cm = float(m.group(1)) * 30.48
        if 100 <= cm <= 230:
            return round(cm, 1)
    return None


def parse_weight(text: str, *, imperial: bool = False) -> float | None:
    """Parse weight. Returns kg always (converts from lb if imperial)."""
    if imperial:
        v = parse_numeric(text, 66, 440)      # lb range
        return round(v * 0.453592, 2) if v is not None else None
    return parse_numeric(text, 20, 200)        # kg range


def parse_smm(text: str, *, imperial: bool = False) -> float | None:
    """Parse Skeletal Muscle Mass. Returns kg."""
    if imperial:
        v = parse_numeric(text, 22, 132)
        return round(v * 0.453592, 2) if v is not None else None
    return parse_numeric(text, 10, 80)


def parse_bfm(text: str, *, imperial: bool = False) -> float | None:
    """Parse Body Fat Mass. Returns kg."""
    if imperial:
        v = parse_numeric(text, 11, 220)
        return round(v * 0.453592, 2) if v is not None else None
    return parse_numeric(text, 3, 100)


def parse_tbw(text: str, *, imperial: bool = False) -> float | None:
    """Parse Total Body Water. Returns litres."""
    if imperial:
        v = parse_numeric(text, 44, 132)       # lb range for 570
        return round(v / 2.20462, 2) if v is not None else None
    return parse_numeric(text, 15, 60)         # litres range


def parse_pbf(text: str) -> float | None:
    """Parse Percent Body Fat (%). Returns %."""
    return parse_numeric(text, 5, 70)


def parse_bmr(text: str) -> float | None:
    """Parse Basal Metabolic Rate (kcal). Returns kcal."""
    cleaned = re.sub(r"[kK][cC][aA][lL]", "", text).strip()
    cleaned = cleaned.replace("kal", "").replace("Kal", "")
    return parse_numeric(cleaned, 800, 3500)


def parse_trunk_ffm(text: str, *, imperial: bool = False) -> float | None:
    """Parse Trunk FFM from segmental section. Returns kg."""
    if imperial:
        v = parse_numeric(text, 22, 110)       # lb range
        return round(v * 0.453592, 2) if v is not None else None
    return parse_numeric(text, 10, 50)


def parse_ecw_tbw(text: str) -> float | None:
    """Parse ECW/TBW ratio [0.300, 0.500]."""
    v = parse_numeric(text, 0.300, 0.500)
    return round(v, 3) if v is not None else None
