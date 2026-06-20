"""inbody_regions.py — Version-specific layout region templates for InBody reports.

Used as fallback anchors when OCR-based section header detection is incomplete.
All coordinates are normalised fractions of page height (y_start, y_end).
"""
from __future__ import annotations

from typing import Dict, Tuple

Region = Tuple[float, float]

# Approximate vertical bands per model (top-to-bottom page fractions).
MODEL_REGION_TEMPLATES: Dict[str, Dict[str, Region]] = {
    "InBody120": {
        "header": (0.0, 0.12),
        "body_composition": (0.12, 0.28),
        "muscle_fat": (0.28, 0.40),
        "obesity": (0.40, 0.52),
        "segmental_lean": (0.52, 0.68),
        "segmental_fat": (0.68, 0.80),
        "summary": (0.80, 1.0),
    },
    "InBody270": {
        "header": (0.0, 0.11),
        "body_composition": (0.11, 0.26),
        "muscle_fat": (0.26, 0.38),
        "obesity": (0.38, 0.50),
        "segmental_lean": (0.50, 0.66),
        "segmental_fat": (0.66, 0.78),
        "research_params": (0.78, 0.90),
        "summary": (0.90, 1.0),
    },
    "InBody570": {
        "header": (0.0, 0.10),
        "body_composition": (0.10, 0.24),
        "muscle_fat": (0.24, 0.36),
        "obesity": (0.36, 0.48),
        "segmental_lean": (0.48, 0.60),
        "segmental_fat": (0.60, 0.70),
        "ecw_tbw": (0.70, 0.78),
        "research_params": (0.78, 0.88),
        "summary": (0.88, 1.0),
    },
}

# Header text anchors used for version detection (case-insensitive substrings).
VERSION_ANCHORS: Dict[str, list[str]] = {
    "InBody120": ["inbody 120", "inbody120", "[inbody120]"],
    "InBody270": ["inbody 270", "inbody270", "[inbody270]", "inbody 270s", "inbody270s"],
    "InBody570": ["inbody 570", "inbody570", "[inbody570]"],
}


def merge_sections(
    detected: Dict[str, Region],
    model: str,
) -> Dict[str, Region]:
    """Fill missing sections from the model template without overwriting detected ones."""
    template = MODEL_REGION_TEMPLATES.get(model) or MODEL_REGION_TEMPLATES["InBody270"]
    merged = dict(template)
    merged.update(detected)
    return merged


def normalise_model_name(raw: str) -> str:
    """Map detected model strings to canonical template keys."""
    upper = raw.upper().replace("-", "").replace(" ", "")
    if "570" in upper:
        return "InBody570"
    if "270" in upper:
        return "InBody270"
    if "120" in upper:
        return "InBody120"
    return "InBody270"
