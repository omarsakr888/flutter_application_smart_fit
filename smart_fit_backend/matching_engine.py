"""matching_engine.py — Meal & Exercise Recommendation Engine.

Architecture
------------
* DataStore        — loads CSV files lazily at first request; caches in memory.
* MealMatcher      — filters & assembles a 5-meal-slot daily nutrition plan.
* ExerciseMatcher  — builds a per-day workout split with intensity scaling.
* MatchingEngine   — orchestrates both matchers and returns a RecommendationPlan.

CSV columns used (exact names from schema analysis):
  Meals  → Name, Calories_PS, Protein_PS, Carbs_PS, Fat_PS,
            Diet_Type, Goal_Label, Health_Score, Meal_Time_Category,
            AggregatedRating, RecipeIngredientParts, RecipeInstructions
  Exercises → name, bodyPart, target, equipment, focus_zone,
              default_sets, default_reps_min, default_reps_max,
              movement_pattern, Split_Type
"""

from __future__ import annotations

import logging
import random
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import pandas as pd

from core import (
    EXERCISES_CSV,
    MEALS_FALLBACK_CSV,
    MEALS_PRIMARY_CSV,
    MEALS_SAMPLE_SIZE,
)
from math_engine import MathEngineResult
from ml_engine import get_csv_zones

logger = logging.getLogger("smart_fit_backend.matching_engine")


# ── Enums / literal types ─────────────────────────────────────────────────────

VALID_DIET_TYPES: frozenset[str] = frozenset({"Vegan", "Vegetarian", "Omnivore"})

# Meal slot names and their approximate calorie fractions of the daily target
MEAL_SLOTS: list[tuple[str, float]] = [
    ("breakfast",   0.25),
    ("morning_snack", 0.10),
    ("lunch",       0.30),
    ("afternoon_snack", 0.10),
    ("dinner",      0.25),
]

# How many exercise candidates we pick per focus zone before applying intensity
EXERCISES_PER_ZONE_SLOT = 5

# Columns to keep when returning meal data (drops large text blobs by default)
_MEAL_DISPLAY_COLS = [
    "Name", "Calories_PS", "Protein_PS", "Carbs_PS", "Fat_PS",
    "Diet_Type", "Goal_Label", "Health_Score", "AggregatedRating",
    "Meal_Time_Category", "RecipeIngredientParts", "RecipeInstructions",
]

# Columns to keep when returning exercise data
_EXERCISE_DISPLAY_COLS = [
    "name", "bodyPart", "target", "equipment",
    "focus_zone", "movement_pattern",
    "default_sets", "default_reps_min", "default_reps_max",
]


# ── Data containers ───────────────────────────────────────────────────────────

@dataclass
class MealSlot:
    slot_name:          str
    target_calories:    float
    recipe_name:        str
    calories_per_serving: float
    protein_g:          float
    carbs_g:            float
    fat_g:              float
    diet_type:          str
    health_score:       float
    rating:             float
    meal_time_category: str
    ingredients:        str
    instructions:       str


@dataclass
class WorkoutExercise:
    name:             str
    body_part:        str
    target_muscle:    str
    equipment:        str
    focus_zone:       str
    movement_pattern: str
    sets:             int
    reps_min:         int
    reps_max:         int


@dataclass
class WorkoutDay:
    day_number:   int
    day_label:    str          # e.g. "Day 1 — Upper Body Strength"
    focus_zone:   str
    exercises:    list[WorkoutExercise]
    note:         str = ""


@dataclass
class RecommendationPlan:
    # Identity
    focus_zone:            str
    ml_confidence_pct:     float
    intensity_multiplier:  float
    intensity_reason:      str

    # Nutrition
    target_calories_kcal:  float
    macros_protein_g:      float
    macros_carbs_g:        float
    macros_fat_g:          float
    macros_protein_pct:    float
    macros_carbs_pct:      float
    macros_fat_pct:        float
    daily_meals:           list[MealSlot]

    # Training
    preferred_days:        int
    workout_split:         list[WorkoutDay]

    # Meta
    warnings:              list[str] = field(default_factory=list)


# ── DataStore (singleton-style lazy loader) ───────────────────────────────────

class DataStore:
    """Loads and caches the CSVs.  Thread-safe for read-only after first load."""

    def __init__(self) -> None:
        self._meals_df: pd.DataFrame | None = None
        self._exercises_df: pd.DataFrame | None = None

    # ── Exercises ─────────────────────────────────────────────────────────────

    def exercises(self) -> pd.DataFrame:
        if self._exercises_df is None:
            self._exercises_df = self._load_exercises()
        return self._exercises_df

    def _load_exercises(self) -> pd.DataFrame:
        path = _require_path(EXERCISES_CSV, "exercises_enhanced.csv")
        logger.info("DataStore: loading exercises from %s", path)
        df = pd.read_csv(
            path,
            usecols=_EXERCISE_DISPLAY_COLS,
            dtype={
                "name": str, "bodyPart": str, "target": str,
                "equipment": str, "focus_zone": str, "movement_pattern": str,
            },
        )
        df = df.dropna(subset=["name", "focus_zone"])
        df["focus_zone"]       = df["focus_zone"].str.strip()
        df["movement_pattern"] = df["movement_pattern"].str.strip()
        logger.info("DataStore: loaded %d exercises", len(df))
        return df

    # ── Meals ─────────────────────────────────────────────────────────────────

    def meals(self) -> pd.DataFrame:
        if self._meals_df is None:
            self._meals_df = self._load_meals()
        return self._meals_df

    def _load_meals(self) -> pd.DataFrame:
        """Samples MEALS_SAMPLE_SIZE rows from disk to keep RAM manageable.

        Falls back to the secondary CSV if the primary is unavailable.
        """
        path = _pick_meal_csv()
        logger.info("DataStore: sampling %d rows from %s", MEALS_SAMPLE_SIZE, path)

        # Use chunked reading + reservoir-style random skip to avoid loading 572 MB
        # We read the full CSV but only keep a random sample — Pandas skiprows lets
        # us do this in a single pass while keeping the header.
        total_estimate = 500_000   # conservative row count
        skip_prob = 1.0 - min(1.0, MEALS_SAMPLE_SIZE / total_estimate)

        chunks: list[pd.DataFrame] = []
        for chunk in pd.read_csv(
            path,
            usecols=_MEAL_DISPLAY_COLS,
            chunksize=10_000,
            dtype={"Diet_Type": str, "Goal_Label": str, "Meal_Time_Category": str},
            on_bad_lines="skip",
        ):
            # Drop rows missing the columns we need
            chunk = chunk.dropna(
                subset=["Name", "Calories_PS", "Protein_PS", "Carbs_PS", "Fat_PS", "Diet_Type"]
            )
            # Random sub-sample of this chunk to hit the target size
            if skip_prob > 0 and len(chunk) > 10:
                chunk = chunk.sample(frac=max(0.05, 1.0 - skip_prob), random_state=42)
            chunks.append(chunk)
            if sum(len(c) for c in chunks) >= MEALS_SAMPLE_SIZE:
                break

        df = pd.concat(chunks, ignore_index=True)
        df["Diet_Type"] = df["Diet_Type"].str.strip()
        logger.info("DataStore: loaded %d meal rows", len(df))
        return df

    def reload(self) -> None:
        """Force a fresh reload on next access (e.g. after a dataset update)."""
        self._meals_df = None
        self._exercises_df = None


# ── Meal Matcher ──────────────────────────────────────────────────────────────

class MealMatcher:
    """Builds a 5-slot meal plan from the meals DataFrame."""

    def __init__(self, df: pd.DataFrame) -> None:
        self._df = df

    def build_plan(
        self,
        *,
        target_calories: float,
        protein_g: float,
        carbs_g: float,
        fat_g: float,
        diet_type: str,
        goal: str,
        warnings: list[str],
    ) -> list[MealSlot]:
        """Return a list of MealSlot objects covering all 5 meal slots."""
        diet_type = _normalise_diet_type(diet_type, warnings)

        # Map goal → Goal_Label in the CSV
        csv_goal_label = _goal_to_csv_label(goal)

        # Pre-filter the pool to the user's diet type
        pool = self._df[self._df["Diet_Type"] == diet_type].copy()
        if len(pool) < 20:
            warnings.append(
                f"Only {len(pool)} meals found for diet_type='{diet_type}'. "
                "Widening to all diet types."
            )
            pool = self._df.copy()

        # Secondary filter by Goal_Label (best effort — don't shrink pool to nothing)
        goal_pool = pool[pool["Goal_Label"] == csv_goal_label]
        if len(goal_pool) >= 10:
            pool = goal_pool

        # Sort by health score desc so high-quality items are preferred
        pool = pool.sort_values("Health_Score", ascending=False).reset_index(drop=True)

        slots: list[MealSlot] = []
        used_indices: set[int] = set()

        for slot_name, cal_fraction in MEAL_SLOTS:
            slot_target_cal = target_calories * cal_fraction
            meal_row = self._pick_meal(
                pool=pool,
                target_cal=slot_target_cal,
                used_indices=used_indices,
            )
            if meal_row is None:
                warnings.append(
                    f"Could not find a suitable meal for slot '{slot_name}'. "
                    "A generic placeholder was used."
                )
                slots.append(_placeholder_slot(slot_name, slot_target_cal))
                continue

            used_indices.add(meal_row.name)  # .name is the DataFrame row index
            slots.append(
                MealSlot(
                    slot_name=slot_name,
                    target_calories=round(slot_target_cal, 1),
                    recipe_name=str(meal_row["Name"]),
                    calories_per_serving=round(float(meal_row["Calories_PS"]), 1),
                    protein_g=round(float(meal_row["Protein_PS"]), 1),
                    carbs_g=round(float(meal_row["Carbs_PS"]), 1),
                    fat_g=round(float(meal_row["Fat_PS"]), 1),
                    diet_type=str(meal_row["Diet_Type"]),
                    health_score=round(float(meal_row.get("Health_Score", 0.0)), 4),
                    rating=round(float(meal_row.get("AggregatedRating", 0.0) or 0.0), 2),
                    meal_time_category=str(meal_row.get("Meal_Time_Category", "N/A")),
                    ingredients=_safe_str(meal_row.get("RecipeIngredientParts")),
                    instructions=_safe_str(meal_row.get("RecipeInstructions")),
                )
            )

        return slots

    @staticmethod
    def _pick_meal(
        pool: pd.DataFrame,
        target_cal: float,
        used_indices: set[int],
    ) -> Any | None:
        """Find the row whose Calories_PS is closest to target_cal.

        Searches in a ±40% window, then relaxes to any unvisited row.
        """
        available = pool[~pool.index.isin(used_indices)]
        if available.empty:
            return None

        lo, hi = target_cal * 0.60, target_cal * 1.40
        window = available[
            (available["Calories_PS"] >= lo) & (available["Calories_PS"] <= hi)
        ]
        if window.empty:
            window = available   # relax constraint

        # Weighted random selection biased toward top health score rows
        top_n = min(20, len(window))
        candidates = window.head(top_n)
        return candidates.sample(1).iloc[0]


# ── Exercise Matcher ──────────────────────────────────────────────────────────

class ExerciseMatcher:
    """Builds a workout split from the exercises DataFrame."""

    def __init__(self, df: pd.DataFrame) -> None:
        self._df = df

    def build_split(
        self,
        *,
        focus_zone: str,
        preferred_days: int,
        intensity_multiplier: float,
        warnings: list[str],
    ) -> list[WorkoutDay]:
        """Return a list of WorkoutDay objects for the user's weekly split.

        Strategy:
          - The ML-predicted focus zone gets 60% of days (rounded up).
          - Remaining days rotate through complementary zones.
          - "Balanced/Recovery" gets a light full-body + cardio rotation.
          - Intensity multiplier scales reps_max down (or up).
        """
        days = max(1, min(7, int(preferred_days)))
        csv_zones = get_csv_zones(focus_zone)

        # Build per-day zone assignments
        day_zone_assignments = self._assign_zones(
            focus_zone=focus_zone,
            csv_zones=csv_zones,
            num_days=days,
        )

        workout_days: list[WorkoutDay] = []
        for day_num, (day_csv_zone, day_label_suffix) in enumerate(day_zone_assignments, start=1):
            exercises = self._pick_exercises(
                csv_zone=day_csv_zone,
                intensity_multiplier=intensity_multiplier,
                warnings=warnings,
            )
            if not exercises:
                warnings.append(
                    f"No exercises found for zone '{day_csv_zone}' on Day {day_num}."
                )

            label = f"Day {day_num} — {day_label_suffix}"
            note = ""
            if intensity_multiplier < 1.0:
                note = (
                    f"⚠ Reduced intensity mode (×{intensity_multiplier:.2f}): "
                    "focus on form and recovery."
                )

            workout_days.append(
                WorkoutDay(
                    day_number=day_num,
                    day_label=label,
                    focus_zone=day_csv_zone,
                    exercises=exercises,
                    note=note,
                )
            )

        return workout_days

    @staticmethod
    def _assign_zones(
        focus_zone: str,
        csv_zones: list[str],
        num_days: int,
    ) -> list[tuple[str, str]]:
        """Return a list of (csv_zone, day_label_suffix) for each workout day."""

        # Full rotation schedules by day count
        ROTATIONS: dict[str, list[str]] = {
            "Upper Body Strength": [
                "Upper Body", "Lower Body", "Upper Body", "Core",
                "Upper Body", "Lower Body", "Core",
            ],
            "Lower Body Power": [
                "Lower Body", "Upper Body", "Lower Body", "Core",
                "Lower Body", "Upper Body", "Core",
            ],
            "Core Stability": [
                "Core", "Upper Body", "Core", "Lower Body",
                "Core", "Upper Body", "Lower Body",
            ],
            "Balanced/Recovery": [
                "Full Body", "Cardio", "Full Body", "Core",
                "Full Body", "Cardio", "Core",
            ],
        }

        # Pretty labels (for the WorkoutDay.day_label field)
        ZONE_LABELS: dict[str, str] = {
            "Upper Body": "Upper Body Strength",
            "Lower Body": "Lower Body Power",
            "Core":       "Core & Stability",
            "Cardio":     "Active Recovery / Cardio",
            "Full Body":  "Full Body Circuit",
        }

        rotation = ROTATIONS.get(focus_zone, ROTATIONS["Balanced/Recovery"])
        result: list[tuple[str, str]] = []
        for i in range(num_days):
            zone = rotation[i % len(rotation)]
            label = ZONE_LABELS.get(zone, zone)
            result.append((zone, label))

        return result

    def _pick_exercises(
        self,
        *,
        csv_zone: str,
        intensity_multiplier: float,
        warnings: list[str],
    ) -> list[WorkoutExercise]:
        """Filter exercises for this zone and apply intensity scaling."""

        # Handle 'Full Body' by mixing Upper + Lower + Core
        if csv_zone == "Full Body":
            combined: list[WorkoutExercise] = []
            for sub_zone in ["Upper Body", "Lower Body", "Core"]:
                combined += self._pick_exercises(
                    csv_zone=sub_zone,
                    intensity_multiplier=intensity_multiplier,
                    warnings=warnings,
                )[:2]  # 2 exercises from each sub-zone = 6 total
            return combined

        pool = self._df[self._df["focus_zone"] == csv_zone]
        if pool.empty:
            return []

        # Sample up to EXERCISES_PER_ZONE_SLOT exercises
        n = min(EXERCISES_PER_ZONE_SLOT, len(pool))
        sample = pool.sample(n=n, random_state=random.randint(0, 9999))

        exercises: list[WorkoutExercise] = []
        for _, row in sample.iterrows():
            base_sets    = int(row["default_sets"])
            base_reps_min = int(row["default_reps_min"])
            base_reps_max = int(row["default_reps_max"])

            # Apply intensity multiplier to reps_max (floor to keep integers)
            scaled_reps_max = max(base_reps_min, int(base_reps_max * intensity_multiplier))

            exercises.append(
                WorkoutExercise(
                    name=str(row["name"]),
                    body_part=str(row["bodyPart"]),
                    target_muscle=str(row["target"]),
                    equipment=str(row["equipment"]),
                    focus_zone=str(row["focus_zone"]),
                    movement_pattern=str(row["movement_pattern"]),
                    sets=base_sets,
                    reps_min=base_reps_min,
                    reps_max=scaled_reps_max,
                )
            )

        return exercises


# ── Main Orchestrator ─────────────────────────────────────────────────────────

class MatchingEngine:
    """Orchestrates DataStore, MealMatcher, and ExerciseMatcher."""

    def __init__(self) -> None:
        self._store = DataStore()

    @property
    def ready(self) -> bool:
        """True if exercise data is accessible (quick sanity check)."""
        try:
            return EXERCISES_CSV.exists()
        except Exception:
            return False

    def generate_plan(
        self,
        *,
        math_result: MathEngineResult,
        focus_zone: str,
        ml_confidence: float,
        diet_type: str,
    ) -> RecommendationPlan:
        """Build the full recommendation plan.

        Args:
            math_result:    Output of MathEngine.calculate().
            focus_zone:     ML-predicted focus zone (normalised string).
            ml_confidence:  Model confidence percentage (0–100).
            diet_type:      User's dietary preference: 'Vegan' / 'Vegetarian' / 'Omnivore'.

        Returns:
            A fully populated RecommendationPlan dataclass.
        """
        warnings: list[str] = []

        # ── Meals ────────────────────────────────────────────────────────────
        meal_matcher = MealMatcher(self._store.meals())
        daily_meals = meal_matcher.build_plan(
            target_calories=math_result.target_calories_kcal,
            protein_g=math_result.macros.protein_g,
            carbs_g=math_result.macros.carbs_g,
            fat_g=math_result.macros.fat_g,
            diet_type=diet_type,
            goal=math_result.goal,
            warnings=warnings,
        )

        # ── Exercises ────────────────────────────────────────────────────────
        exercise_matcher = ExerciseMatcher(self._store.exercises())
        workout_split = exercise_matcher.build_split(
            focus_zone=focus_zone,
            preferred_days=math_result.preferred_days,
            intensity_multiplier=math_result.intensity_multiplier,
            warnings=warnings,
        )

        return RecommendationPlan(
            focus_zone=focus_zone,
            ml_confidence_pct=round(ml_confidence, 2),
            intensity_multiplier=math_result.intensity_multiplier,
            intensity_reason=math_result.intensity_reason,

            target_calories_kcal=math_result.target_calories_kcal,
            macros_protein_g=math_result.macros.protein_g,
            macros_carbs_g=math_result.macros.carbs_g,
            macros_fat_g=math_result.macros.fat_g,
            macros_protein_pct=math_result.macros.protein_pct,
            macros_carbs_pct=math_result.macros.carbs_pct,
            macros_fat_pct=math_result.macros.fat_pct,

            daily_meals=daily_meals,
            preferred_days=math_result.preferred_days,
            workout_split=workout_split,
            warnings=warnings,
        )


# ── Private utilities ─────────────────────────────────────────────────────────

def _require_path(path: Path, label: str) -> Path:
    if not path.exists():
        raise FileNotFoundError(
            f"Dataset file not found: {path}. "
            f"Ensure '{label}' is in the recommendation_datasets/ directory."
        )
    return path


def _pick_meal_csv() -> Path:
    if MEALS_PRIMARY_CSV.exists():
        return MEALS_PRIMARY_CSV
    if MEALS_FALLBACK_CSV.exists():
        logger.warning(
            "Primary meal CSV not found; falling back to %s", MEALS_FALLBACK_CSV
        )
        return MEALS_FALLBACK_CSV
    raise FileNotFoundError(
        "No meal dataset CSV found. Expected one of:\n"
        f"  {MEALS_PRIMARY_CSV}\n  {MEALS_FALLBACK_CSV}"
    )


def _normalise_diet_type(raw: str, warnings: list[str]) -> str:
    """Return a canonical Diet_Type string; warns and defaults if invalid."""
    stripped = raw.strip().title()   # e.g. "vegan" → "Vegan"
    if stripped in VALID_DIET_TYPES:
        return stripped
    warnings.append(
        f"Unknown diet_type='{raw}'. Defaulting to 'Omnivore'."
    )
    return "Omnivore"


def _goal_to_csv_label(goal: str) -> str:
    """Map ML goal string to the Goal_Label value used in the meals CSV."""
    keto_goals = {"Lower Body Power", "Upper Body Strength"}
    return "Keto" if goal in keto_goals else "General"


def _placeholder_slot(slot_name: str, target_cal: float) -> MealSlot:
    return MealSlot(
        slot_name=slot_name,
        target_calories=round(target_cal, 1),
        recipe_name="Balanced Meal (placeholder)",
        calories_per_serving=round(target_cal, 1),
        protein_g=0.0,
        carbs_g=0.0,
        fat_g=0.0,
        diet_type="Omnivore",
        health_score=0.0,
        rating=0.0,
        meal_time_category="N/A",
        ingredients="",
        instructions="Please consult a nutritionist for a personalised meal suggestion.",
    )


def _safe_str(value: Any) -> str:
    if value is None or (isinstance(value, float) and value != value):  # NaN check
        return ""
    return str(value)
