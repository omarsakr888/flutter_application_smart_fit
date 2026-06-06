from __future__ import annotations

import logging
from typing import Any

import joblib
import numpy as np
import pandas as pd
from pydantic import BaseModel, ConfigDict, Field, field_validator

from core import (
    FEATURE_COLUMNS_PATH,
    MODEL_PATH,
    PERSONA_MAPPING_PATH,
    REQUIRED_INPUT_FEATURES,
    SCALER_PATH,
)

logger = logging.getLogger("smart_fit_backend.ml")


class PredictionRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")

    user_goal: str = Field(alias="User_Goal")
    age: float = Field(alias="Age", gt=0, le=120)
    gender: float | str = Field(alias="Gender")
    height: float = Field(alias="Height", gt=0)
    weight: float = Field(alias="Weight", gt=0)
    skeletal_muscle_mass: float = Field(alias="SMM_(Skeletal_Muscle_Mass)", gt=0)
    basal_metabolic_rate: float = Field(alias="BMR_(Basal_Metabolic_Rate)", gt=0)
    ffm_of_trunk: float = Field(alias="FFM_of_Trunk", gt=0)
    total_body_water: float = Field(alias="TBW_(Total_Body_Water)", ge=0)
    ecw_tbw: float = Field(alias="ECW/TBW", ge=0)
    phase_angle: float = Field(alias="50kHz-Whole_Body_Phase_Angle", ge=0)
    body_fat_mass: float = Field(alias="BFM_(Body_Fat_Mass)", ge=0)
    percent_body_fat: float = Field(alias="PBF_(Percent_Body_Fat)", ge=0)

    @field_validator("gender")
    @classmethod
    def normalize_gender(cls, value: float | str) -> float:
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"male", "m", "1"}:
                return 1.0
            if normalized in {"female", "f", "0"}:
                return 0.0
            raise ValueError("Gender must be 0/1 or male/female.")
        return float(value)

    def to_feature_dict(self) -> dict[str, float | str]:
        return {
            "User_Goal": str(self.user_goal),
            "Age": float(self.age),
            "Gender": float(self.gender),
            "Height": float(self.height),
            "Weight": float(self.weight),
            "SMM_(Skeletal_Muscle_Mass)": float(self.skeletal_muscle_mass),
            "BMR_(Basal_Metabolic_Rate)": float(self.basal_metabolic_rate),
            "FFM_of_Trunk": float(self.ffm_of_trunk),
            "TBW_(Total_Body_Water)": float(self.total_body_water),
            "ECW/TBW": float(self.ecw_tbw),
            "50kHz-Whole_Body_Phase_Angle": float(self.phase_angle),
            "BFM_(Body_Fat_Mass)": float(self.body_fat_mass),
            "PBF_(Percent_Body_Fat)": float(self.percent_body_fat),
        }


class PredictionService:
    def __init__(self) -> None:
        self.classifier: Any | None = None
        self.feature_columns: list[str] | None = None
        self.scaler: Any | None = None
        self.persona_mapping: dict[Any, str] | None = None

    @property
    def ready(self) -> bool:
        return all(
            value is not None
            for value in (
                self.classifier,
                self.feature_columns,
                self.scaler,
                self.persona_mapping,
            )
        )

    def load(self) -> None:
        logger.info("Loading ML artifacts")
        self.feature_columns = list(_load_artifact(FEATURE_COLUMNS_PATH))
        self.scaler = _load_artifact(SCALER_PATH)
        self.persona_mapping = _load_artifact(PERSONA_MAPPING_PATH)
        self.classifier = _load_artifact(MODEL_PATH)
        logger.info("Loaded classifier with %d features", len(self.feature_columns))

    def predict_request(self, payload: PredictionRequest) -> dict[str, str | float]:
        return self.predict_features(payload.to_feature_dict())

    def predict_features(self, features: dict[str, float | str]) -> dict[str, str | float]:
        if not self.ready:
            raise RuntimeError("Model artifacts are not loaded yet.")

        payload = PredictionRequest(**{key: features[key] for key in REQUIRED_INPUT_FEATURES})
        frame = pd.DataFrame([payload.to_feature_dict()])
        frame["Muscle_Fat_Ratio"] = (
            frame["SMM_(Skeletal_Muscle_Mass)"] / (frame["BFM_(Body_Fat_Mass)"] + 1e-5)
        )
        frame["Hydration_Stress"] = frame["ECW/TBW"] * frame["50kHz-Whole_Body_Phase_Angle"]
        frame["Lean_Per_Height"] = (
            frame["SMM_(Skeletal_Muscle_Mass)"] / ((frame["Height"] / 100) ** 2)
        )

        aligned = frame.reindex(columns=self.feature_columns, fill_value=0.0)
        aligned = aligned.fillna(0.0)
        scaled = self.scaler.transform(aligned)

        prediction = self.classifier.predict(scaled)[0]
        predicted_key = int(prediction) if isinstance(prediction, np.integer | int) else prediction
        persona = self.persona_mapping.get(predicted_key, str(prediction))
        confidence = _confidence_score(self.classifier, scaled)

        return {
            "status": "success",
            "predicted_persona": persona,
            "confidence": confidence,
        }


def _load_artifact(path) -> Any:
    if not path.exists():
        raise FileNotFoundError(f"Required artifact not found: {path.name}")
    return joblib.load(path)


def _confidence_score(classifier: Any, scaled_frame: np.ndarray) -> float:
    if hasattr(classifier, "predict_proba"):
        probabilities = classifier.predict_proba(scaled_frame)
        return round(float(np.max(probabilities)) * 100, 2)

    if hasattr(classifier, "decision_function"):
        scores = np.asarray(classifier.decision_function(scaled_frame), dtype=float)
        scores = scores - np.max(scores)
        probabilities = np.exp(scores) / np.sum(np.exp(scores))
        return round(float(np.max(probabilities)) * 100, 2)

    return 100.0
