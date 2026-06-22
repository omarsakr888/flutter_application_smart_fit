"""math_engine.py — Deterministic Nutrition & Intensity Calculator.

Pipeline:
  1. Mifflin-St Jeor BMR  (uses Weight, Height, Age, Gender)
  2. Activity multiplier   (based on preferred_days per week)
  3. SMM bias correction   (users with higher lean mass burn more)
  4. Goal-aware caloric adjustment (cut / maintain / bulk)
  5. Macro split           (Protein / Carb / Fat ratios per goal)
  6. Intensity multiplier  (reduced when ECW/TBW or Phase Angle indicate
                            poor hydration / cellular health)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

logger = logging.getLogger("smart_fit_backend.math_engine")

# ── Constants ─────────────────────────────────────────────────────────────────

# Activity multipliers indexed by preferred_days (0-7).
# 0 days → sedentary; 6-7 days → very active.
_ACTIVITY_MULTIPLIERS: dict[int, float] = {
    0: 1.20,  # sedentary
    1: 1.30,
    2: 1.375, # lightly active
    3: 1.45,
    4: 1.55,  # moderately active
    5: 1.65,
    6: 1.725, # very active
    7: 1.90,  # extra active
}

# Macro splits (protein_pct, carb_pct, fat_pct) by goal label.
# Values sum to 1.0 and represent fraction of total calories.
_MACRO_SPLITS: dict[str, tuple[float, float, float]] = {
    "Balanced/Recovery":    (0.30, 0.40, 0.30),
    "Core Stability":       (0.32, 0.38, 0.30),
    "Lower Body Power":     (0.35, 0.40, 0.25),
    "Upper Body Strength":  (0.38, 0.35, 0.27),
}
_DEFAULT_MACRO_SPLIT: tuple[float, float, float] = (0.30, 0.40, 0.30)

# Caloric adjustment per goal.
# Positive → surplus (bulk), negative → deficit (cut), zero → maintenance.
_GOAL_CALORIC_ADJUSTMENTS: dict[str, float] = {
    "Balanced/Recovery":   0.0,    # maintenance
    "Core Stability":     -0.05,   # slight cut  (−5 %)
    "Lower Body Power":    0.05,   # slight bulk (+5 %)
    "Upper Body Strength": 0.08,   # moderate bulk (+8 %)
}

# Intensity multiplier thresholds.
_ECW_TBW_HIGH_THRESHOLD   = 0.390   # above this → elevated extracellular water (inflammation)
_PHASE_ANGLE_LOW_THRESHOLD = 4.5    # below this → poor cellular integrity / fatigue
_INTENSITY_REDUCED         = 0.70   # multiplier when either threshold is breached
_INTENSITY_NORMAL          = 1.00   # multiplier when health markers are good

# Calories per gram of each macro.
KCAL_PER_G_PROTEIN = 4.0
KCAL_PER_G_CARB    = 4.0
KCAL_PER_G_FAT     = 9.0


# ── Data containers ───────────────────────────────────────────────────────────

@dataclass(frozen=True)
class MacroGrams:
    protein_g: float
    carbs_g:   float
    fat_g:     float
    protein_pct: float
    carbs_pct:   float
    fat_pct:     float


@dataclass(frozen=True)
class MathEngineResult:
    """All deterministic outputs consumed by the Matching Engine."""
    # Calories
    bmr_kcal:              float   # raw Mifflin-St Jeor BMR
    tdee_kcal:             float   # total daily energy expenditure (with activity)
    target_calories_kcal:  float   # goal-adjusted calorie target

    # Macros (grams and percentages)
    macros: MacroGrams

    # Training load
    intensity_multiplier:  float   # 0.70 = reduced, 1.00 = normal
    intensity_reason:      str     # human-readable explanation

    # Context
    goal:          str
    preferred_days: int


# ── Engine ────────────────────────────────────────────────────────────────────

class MathEngine:
    """Stateless service — all methods are pure functions with no side effects."""

    # ── Public API ────────────────────────────────────────────────────────────

    def calculate(
        self,
        *,
        age: float,
        gender: float,          # 1.0 = male, 0.0 = female
        weight_kg: float,
        height_cm: float,
        smm_kg: float | None,          # skeletal muscle mass
        ecw_tbw: float | None,         # extracellular water ratio
        phase_angle: float | None,     # bioelectrical phase angle (degrees)
        goal: str,
        preferred_days: int,    # 0-7 workout days per week
        ocr_bmr: float | None = None,  # Top priority BMR from OCR
        extra_caloric_adjustment: float = 0.0,
    ) -> MathEngineResult:
        """Run the full deterministic pipeline and return a MathEngineResult."""

        # 1. BMR Priority: OCR BMR > Mifflin-St Jeor
        if ocr_bmr is not None and ocr_bmr > 500.0:
            bmr = ocr_bmr
        else:
            bmr = self._mifflin_st_jeor(
                weight_kg=weight_kg,
                height_cm=height_cm,
                age=age,
                is_male=(gender >= 0.5),
            )

        # 2. SMM bias: lean athletes have higher metabolic rate; scale proportionally
        # Reference average SMM: 30 kg.  Each extra kg of SMM adds ~22 kcal/day.
        smm_val = smm_kg if smm_kg is not None else 30.0
        smm_bias = (smm_val - 30.0) * 22.0
        bmr_adjusted = max(bmr + smm_bias, bmr * 0.85)   # never drop below 85% of raw

        # 3. Activity multiplier
        days_clamped = max(0, min(7, int(preferred_days)))
        activity_multiplier = _ACTIVITY_MULTIPLIERS[days_clamped]
        tdee = bmr_adjusted * activity_multiplier

        # 4. Goal-aware caloric adjustment
        caloric_adjustment = _GOAL_CALORIC_ADJUSTMENTS.get(goal, 0.0)
        target_calories = round(
            tdee * (1.0 + caloric_adjustment + extra_caloric_adjustment), 1
        )

        # 5. Macro split
        macros = self._calculate_macros(target_calories, goal)

        # 6. Intensity multiplier
        intensity, intensity_reason = self._intensity_multiplier(
            ecw_tbw=ecw_tbw,
            phase_angle=phase_angle,
        )

        logger.info(
            "MathEngine: goal=%s days=%d BMR=%.0f TDEE=%.0f target=%.0f "
            "intensity=%.2f protein_g=%.0f carbs_g=%.0f fat_g=%.0f",
            goal, preferred_days, bmr_adjusted, tdee, target_calories,
            intensity, macros.protein_g, macros.carbs_g, macros.fat_g,
        )

        return MathEngineResult(
            bmr_kcal=round(bmr_adjusted, 1),
            tdee_kcal=round(tdee, 1),
            target_calories_kcal=target_calories,
            macros=macros,
            intensity_multiplier=intensity,
            intensity_reason=intensity_reason,
            goal=goal,
            preferred_days=preferred_days,
        )

    # ── Private helpers ───────────────────────────────────────────────────────

    @staticmethod
    def _mifflin_st_jeor(
        *,
        weight_kg: float,
        height_cm: float,
        age: float,
        is_male: bool,
    ) -> float:
        """Mifflin-St Jeor equation (most validated for diverse populations).

        Male:   BMR = 10W + 6.25H − 5A + 5
        Female: BMR = 10W + 6.25H − 5A − 161
        """
        base = (10.0 * weight_kg) + (6.25 * height_cm) - (5.0 * age)
        return base + 5.0 if is_male else base - 161.0

    @staticmethod
    def _calculate_macros(target_calories: float, goal: str) -> MacroGrams:
        protein_pct, carb_pct, fat_pct = _MACRO_SPLITS.get(goal, _DEFAULT_MACRO_SPLIT)

        protein_g = round((target_calories * protein_pct) / KCAL_PER_G_PROTEIN, 1)
        carbs_g   = round((target_calories * carb_pct)    / KCAL_PER_G_CARB,    1)
        fat_g     = round((target_calories * fat_pct)     / KCAL_PER_G_FAT,     1)

        return MacroGrams(
            protein_g=protein_g,
            carbs_g=carbs_g,
            fat_g=fat_g,
            protein_pct=round(protein_pct * 100, 1),
            carbs_pct=round(carb_pct * 100, 1),
            fat_pct=round(fat_pct * 100, 1),
        )

    @staticmethod
    def _intensity_multiplier(
        *,
        ecw_tbw: float | None,
        phase_angle: float | None,
    ) -> tuple[float, str]:
        """Determine workout intensity modifier from hydration & cellular health.

        Returns (multiplier, reason_string).
        """
        reasons: list[str] = []

        if ecw_tbw is not None and ecw_tbw > _ECW_TBW_HIGH_THRESHOLD:
            reasons.append(
                f"ECW/TBW={ecw_tbw:.3f} > {_ECW_TBW_HIGH_THRESHOLD} "
                "(elevated extracellular water — possible inflammation or overtraining)"
            )
        if phase_angle is not None and phase_angle < _PHASE_ANGLE_LOW_THRESHOLD:
            reasons.append(
                f"Phase angle={phase_angle:.1f}° < {_PHASE_ANGLE_LOW_THRESHOLD}° "
                "(low cellular integrity — prioritise recovery)"
            )

        if reasons:
            return _INTENSITY_REDUCED, "; ".join(reasons)

        return _INTENSITY_NORMAL, "Biomarkers within normal range — full intensity cleared."
