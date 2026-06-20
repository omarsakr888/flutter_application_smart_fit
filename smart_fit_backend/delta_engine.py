"""delta_engine.py — Progress deltas from confirmed scan history."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class ScanDelta:
    has_previous: bool
    weight_delta_kg: float | None
    pbf_delta_pp: float | None
    smm_delta_kg: float | None
    tbw_delta_l: float | None
    weeks_between: float | None


def compute_delta(
    current_features: dict[str, float | str],
    previous_features: dict[str, Any] | None,
) -> ScanDelta:
    if not previous_features:
        return ScanDelta(
            has_previous=False,
            weight_delta_kg=None,
            pbf_delta_pp=None,
            smm_delta_kg=None,
            tbw_delta_l=None,
            weeks_between=None,
        )

    def f(key: str) -> float | None:
        val = current_features.get(key)
        if val is None:
            return None
        try:
            return float(val)
        except (TypeError, ValueError):
            return None

    def p(key: str) -> float | None:
        val = previous_features.get(key)
        if val is None:
            return None
        try:
            return float(val)
        except (TypeError, ValueError):
            return None

    cw, pw = f("Weight"), p("Weight")
    cp, pp = f("PBF_(Percent_Body_Fat)"), p("PBF_(Percent_Body_Fat)")
    cs, ps = f("SMM_(Skeletal_Muscle_Mass)"), p("SMM_(Skeletal_Muscle_Mass)")
    ct, pt = f("TBW_(Total_Body_Water)"), p("TBW_(Total_Body_Water)")

    return ScanDelta(
        has_previous=True,
        weight_delta_kg=round(cw - pw, 2) if cw is not None and pw is not None else None,
        pbf_delta_pp=round(cp - pp, 2) if cp is not None and pp is not None else None,
        smm_delta_kg=round(cs - ps, 2) if cs is not None and ps is not None else None,
        tbw_delta_l=round(ct - pt, 2) if ct is not None and pt is not None else None,
        weeks_between=None,
    )


def caloric_modifier(delta: ScanDelta) -> float:
    """Small deterministic adjustment based on progress trend."""
    if not delta.has_previous or delta.weight_delta_kg is None:
        return 0.0
    # Losing weight quickly — soften deficit
    if delta.weight_delta_kg < -1.5:
        return 0.03
    # Gaining weight — tighten surplus
    if delta.weight_delta_kg > 0.5:
        return -0.03
    return 0.0
