"""ml_engine.py — Thin inference wrapper around the existing PredictionService.

This module exposes a single clean function `predict_focus_zone()` that the
Recommendation Engine calls without caring about model internals.  It delegates
all artifact loading and feature engineering to the already-tested
`ml_service.PredictionService` so we don't duplicate logic.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ml_service import PredictionService

logger = logging.getLogger("smart_fit_backend.ml_engine")

# ── Focus Zone normaliser ─────────────────────────────────────────────────────
# The ML model outputs exactly one of these strings (via the persona_mapping pkl).
# We normalise casing/whitespace to guarantee a clean match downstream.
VALID_FOCUS_ZONES: frozenset[str] = frozenset(
    {
        "Balanced/Recovery",
        "Core Stability",
        "Lower Body Power",
        "Upper Body Strength",
    }
)

# Mapping from ML output string → CSV `focus_zone` column value(s).
# Used by the Matching Engine to query exercises.csv.
FOCUS_ZONE_TO_CSV: dict[str, list[str]] = {
    "Balanced/Recovery":   ["Full Body", "Cardio"],   # light mixed days
    "Core Stability":      ["Core"],
    "Lower Body Power":    ["Lower Body"],
    "Upper Body Strength": ["Upper Body"],
}


# ── Public API ────────────────────────────────────────────────────────────────

def predict_focus_zone(
    service: "PredictionService",
    features: dict[str, float | str],
) -> tuple[str, float, str]:
    """Run ML inference and return (focus_zone_label, confidence_pct, raw_persona).

    Args:
        service:  A loaded `PredictionService` instance (from ml_service.py).
        features: A dict matching REQUIRED_INPUT_FEATURES — biological floats
                  plus the 'User_Goal' string.

    Returns:
        A tuple of:
          - focus_zone: one of VALID_FOCUS_ZONES, or a best-guess normalised
                        string if the model returns something unexpected.
          - confidence: 0.0–100.0 percentage.

    Raises:
        RuntimeError: if the service is not yet loaded.
    """
    if not service.ready:
        raise RuntimeError(
            "ML artifacts are not loaded. Call PredictionService.load() first."
        )

    result = service.predict_features(features)
    raw_persona: str = str(result.get("predicted_persona", "Balanced/Recovery"))
    confidence: float = float(result.get("confidence", 0.0))

    focus_zone = _normalise_focus_zone(raw_persona)
    logger.info(
        "MLEngine: raw='%s' → normalised='%s' confidence=%.2f%%",
        raw_persona, focus_zone, confidence,
    )
    return focus_zone, confidence, raw_persona


def get_csv_zones(focus_zone: str) -> list[str]:
    """Return the list of CSV `focus_zone` values that map to this ML class."""
    return FOCUS_ZONE_TO_CSV.get(focus_zone, ["Full Body"])


# ── Internal helpers ──────────────────────────────────────────────────────────

def _normalise_focus_zone(raw: str) -> str:
    """Normalise a raw model output string to a canonical focus zone label.

    Tries an exact match first, then a case-insensitive substring search.
    Falls back to 'Balanced/Recovery' if nothing matches.
    """
    stripped = raw.strip()

    # Exact match
    if stripped in VALID_FOCUS_ZONES:
        return stripped

    # Case-insensitive match
    stripped_lower = stripped.lower()
    for zone in VALID_FOCUS_ZONES:
        if zone.lower() == stripped_lower:
            return zone

    # Partial / keyword match
    keyword_map: list[tuple[str, str]] = [
        ("upper",    "Upper Body Strength"),
        ("lower",    "Lower Body Power"),
        ("core",     "Core Stability"),
        ("balanced", "Balanced/Recovery"),
        ("recovery", "Balanced/Recovery"),
    ]
    for keyword, canonical in keyword_map:
        if keyword in stripped_lower:
            logger.warning(
                "MLEngine: ambiguous output '%s' — mapped to '%s' via keyword '%s'.",
                raw, canonical, keyword,
            )
            return canonical

    logger.warning(
        "MLEngine: unrecognised output '%s' — defaulting to 'Balanced/Recovery'.", raw
    )
    return "Balanced/Recovery"
