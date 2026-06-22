"""confidence_engine.py — Field-level confidence scoring and validation status.

Determines whether each extracted field should be auto-accepted, flagged for
user verification, or marked uncertain.
"""
from __future__ import annotations

from typing import Any

CRITICAL_METRICS = {"Weight", "SMM_(Skeletal_Muscle_Mass)", "BFM_(Body_Fat_Mass)", "PBF_(Percent_Body_Fat)", "BMR_(Basal_Metabolic_Rate)"}
IDENTITY_METRICS = {"Age", "Height", "Gender"}

def validation_status(
    *,
    key: str,
    value: float | str | None,
    confidence: float,
    is_imputed: bool,
    passed_range: bool = True,
    cross_validated: bool = True,
) -> str:
    """Return one of: valid | uncertain | missing | imputed | failed_validation."""
    if value is None:
        return "missing"
    if is_imputed:
        return "imputed"
    if not passed_range or not cross_validated:
        return "failed_validation"
        
    threshold = 0.60
    if key in CRITICAL_METRICS:
        threshold = 0.80
    elif key in IDENTITY_METRICS:
        threshold = 0.75
        
    if confidence >= threshold:
        return "valid"
    return "uncertain"


def review_action(status: str) -> str:
    """Map validation status to user-facing review action."""
    if status in {"valid", "imputed"}:
        return "auto_accept"
    if status == "uncertain":
        return "request_verification"
    return "mark_uncertain"


def enrich_field(
    key: str,
    field: dict[str, Any],
    *,
    passed_range: bool = True,
    cross_validated: bool = True,
) -> dict[str, Any]:
    """Add validation_status and review_action to a field dict."""
    value = field.get("value")
    confidence = float(field.get("confidence", 0.0))
    is_imputed = bool(field.get("is_imputed", False))
    status = validation_status(
        key=key,
        value=value,
        confidence=confidence,
        is_imputed=is_imputed,
        passed_range=passed_range,
        cross_validated=cross_validated,
    )
    enriched = dict(field)
    enriched["validation_status"] = status
    enriched["review_action"] = review_action(status)
    enriched["needs_review"] = enriched["review_action"] in {"request_verification", "mark_uncertain"}
    return enriched


def extraction_confidence(fields: dict[str, dict[str, Any]]) -> float:
    """Overall extraction confidence from non-imputed, non-null fields."""
    scores = [
        float(f["confidence"])
        for f in fields.values()
        if f.get("value") is not None and not f.get("is_imputed", False)
    ]
    if not scores:
        return 0.0
    return round(sum(scores) / len(scores), 4)


def fields_needing_verification(fields: dict[str, dict[str, Any]]) -> list[str]:
    """Return legacy field keys that require user review."""
    return [
        key
        for key, f in fields.items()
        if f.get("review_action") in {"request_verification", "mark_uncertain"}
    ]
