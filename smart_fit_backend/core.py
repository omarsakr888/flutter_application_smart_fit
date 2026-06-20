from __future__ import annotations

import logging
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "ultimate_stacking_classifier.pkl"
FEATURE_COLUMNS_PATH = BASE_DIR / "ultimate_feature_columns.pkl"
SCALER_PATH = BASE_DIR / "ultimate_inbody_scaler.pkl"
PERSONA_MAPPING_PATH = BASE_DIR / "ultimate_zone_mapping.pkl"

DATA_DIR = BASE_DIR / "data"
UPLOAD_DIR = DATA_DIR / "uploads"
DATABASE_PATH = DATA_DIR / "smart_fit_scans.sqlite3"

# ── Recommendation dataset paths ──────────────────────────────────────────────
DATASETS_DIR = BASE_DIR.parent / "recommendation_datasets"
EXERCISES_CSV    = DATASETS_DIR / "exercises_enhanced.csv"
MEALS_PRIMARY_CSV   = DATASETS_DIR / "advanced_foodcom_labeled_dataset.csv"
MEALS_FALLBACK_CSV  = DATASETS_DIR / "cleaned_intermediate_dataset.csv"

# Number of meal rows sampled from disk per engine load (keeps RAM low)
MEALS_SAMPLE_SIZE = 60_000

TEMPLATES_DIR = BASE_DIR / "templates"

MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB

REQUIRED_INPUT_FEATURES = (
    "Age",
    "Gender",
    "Height",
    "Weight",
    "SMM_(Skeletal_Muscle_Mass)",
    "BMR_(Basal_Metabolic_Rate)",
    "FFM_of_Trunk",
    "TBW_(Total_Body_Water)",
    "ECW/TBW",
    "50kHz-Whole_Body_Phase_Angle",
    "BFM_(Body_Fat_Mass)",
    "PBF_(Percent_Body_Fat)",
    "User_Goal",
)


def configure_logging() -> logging.Logger:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    )
    return logging.getLogger("smart_fit_backend")
