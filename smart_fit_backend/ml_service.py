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

# Extracted from ultimate_inbody_scaler.mean_
TRAINING_MEDIANS = {
    'Height': 169.93527164034887,
    'Gender': 0.7439535618045486,
    'Age': 35.872136006015005,
    'Weight': 78.25395828606763,
    'ICW_(Intracellular_Water)': 28.672820000841266,
    'ECW_(Extracellular_Water)': 16.49801821304595,
    'Protein': 12.388910561458244,
    'Minerals': 4.058020138412481,
    'BFM_(Body_Fat_Mass)': 17.103384915088146,
    'SMM_(Skeletal_Muscle_Mass)': 34.91050775271722,
    'PBF_(Percent_Body_Fat)': 20.135903345854516,
    'FFM_of_Trunk': 28.331958868227364,
    'FFM%_of_Trunk': 111.24177236660765,
    'TBW_of_Trunk': 21.923157977795686,
    'ICW_of_Trunk': 13.976745559592217,
    'ECW_of_Trunk': 7.94610399042999,
    'ECW/TBW': 0.3646184878057818,
    'ECW/TBW_of_Trunk': 0.36261472654050164,
    'BFM_of_Trunk': 8.727144123873208,
    'BFM%_of_Trunk': 216.43914328785758,
    'InBody_Score': 81.36478442728443,
    'BMR_(Basal_Metabolic_Rate)': 1703.5354490708992,
    'WHR_(Waist-Hip_Ratio)': 0.9104071726393498,
    'VFL_(Visceral_Fat_Level)': 6.080725757707325,
    'VFA_(Visceral_Fat_Area)': 65.97379036593887,
    'Obesity_Degree': 122.21429879190157,
    'BCM_(Body_Cell_Mass)': 41.059495042612916,
    'TBW/FFM': 73.23572874434355,
    'FFMI_(Fat_Free_Mass_Index)': 21.321252332210708,
    'FMI_(Fat_Mass_Index)': 5.544398799218079,
    '50kHz-Whole_Body_Phase_Angle': 7.157875675931766,
    'Measured_Circumference_of_Chest': 104.97297517891417,
    'Measured_Circumference_of_Abdomen': 91.96151040432977,
    'Measured_Circumference_of_Hip': 100.7497565535929,
    'User_Goal': 0.9766707194889703,
    'Intensity_Multiplier': 0.9999820678624681,
    'Calorie_Target': 2238.6959831476383,
    'SMM_Ratio': 0.45938342786433856,
    'BFM_Ratio': 0.20155001089719154,
    'TBW_Ratio': 0.5848200809740121,
    'FFM_Ratio': 0.7986286635590205,
    'Metabolic_Efficiency': 22.109225128420352,
    'Muscle_Fat_Ratio': 2.676536173037397,
    'Trunk_Limb_Ratio': 0.8589802060771045,
    'Delta_SMM': 0.3339217737223038,
    'Delta_BFM': -0.5173804475347923,
    'Delta_Weight': -0.013734533432253827,
    'Delta_PBF': -0.0047703130779826195,
    'Delta_Phase_Angle': 0.10044761117414083,
    'Days_Between_Scans': 35.974175086033995,
    'Hydration_Stress': 2.606239435453477,
    'Lean_Per_Height': 12.098295064534696,
}


class PredictionRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, extra="forbid")

    user_goal: str | float = Field(alias="User_Goal")
    age: float | None = Field(None, alias="Age", gt=0, le=120)
    gender: float | str | None = Field(None, alias="Gender")
    height: float | None = Field(None, alias="Height", gt=0)
    weight: float | None = Field(None, alias="Weight", gt=0)
    skeletal_muscle_mass: float | None = Field(None, alias="SMM_(Skeletal_Muscle_Mass)", gt=0)
    basal_metabolic_rate: float | None = Field(None, alias="BMR_(Basal_Metabolic_Rate)", gt=0)
    ffm_of_trunk: float | None = Field(None, alias="FFM_of_Trunk", gt=0)
    total_body_water: float | None = Field(None, alias="TBW_(Total_Body_Water)", ge=0)
    ecw_tbw: float | None = Field(None, alias="ECW/TBW", ge=0)
    phase_angle: float | None = Field(None, alias="50kHz-Whole_Body_Phase_Angle", ge=0)
    body_fat_mass: float | None = Field(None, alias="BFM_(Body_Fat_Mass)", ge=0)
    percent_body_fat: float | None = Field(None, alias="PBF_(Percent_Body_Fat)", ge=0)

    @field_validator("gender")
    @classmethod
    def normalize_gender(cls, value: float | str | None) -> float | None:
        if value is None:
            return None
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"male", "m", "1"}:
                return 1.0
            if normalized in {"female", "f", "0"}:
                return 0.0
            raise ValueError("Gender must be 0/1 or male/female.")
        return float(value)

    def to_feature_dict(self) -> dict[str, float | str]:
        goal_map = {
            "Balanced/Recovery": 0.0,
            "Core Stability": 1.0,
            "Lower Body Power": 2.0,
            "Upper Body Strength": 3.0,
        }
        goal_val = float(goal_map.get(str(self.user_goal), 0.0)) if isinstance(self.user_goal, str) else float(self.user_goal)
        
        return {
            "User_Goal": goal_val,
            "Age": self.age,
            "Gender": self.gender,
            "Height": self.height,
            "Weight": self.weight,
            "SMM_(Skeletal_Muscle_Mass)": self.skeletal_muscle_mass,
            "BMR_(Basal_Metabolic_Rate)": self.basal_metabolic_rate,
            "FFM_of_Trunk": self.ffm_of_trunk,
            "TBW_(Total_Body_Water)": self.total_body_water,
            "ECW/TBW": self.ecw_tbw,
            "50kHz-Whole_Body_Phase_Angle": self.phase_angle,
            "BFM_(Body_Fat_Mass)": self.body_fat_mass,
            "PBF_(Percent_Body_Fat)": self.percent_body_fat,
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
        features = payload.to_feature_dict()
        return self.predict_features(features)

    def predict_features(self, features: dict[str, float | str]) -> dict[str, str | float]:
        if not self.ready:
            raise RuntimeError("Model artifacts are not loaded yet.")

        payload = PredictionRequest(**{key: features.get(key) for key in REQUIRED_INPUT_FEATURES})
        frame = pd.DataFrame([payload.to_feature_dict()])
        
        # 1. Expand dataframe to all required feature columns
        frame = frame.reindex(columns=self.feature_columns)
        
        # 2. Impute missing features with exact training medians
        missing_count = 0
        for col in self.feature_columns:
            if pd.isna(frame[col].iloc[0]):
                frame.loc[0, col] = TRAINING_MEDIANS.get(col, 0.0)
                missing_count += 1
                
        logger.info(f"Imputed {missing_count} missing biological features using median strategy")

        # 3. Apply feature engineering on strictly imputed data
        frame["Muscle_Fat_Ratio"] = (
            frame["SMM_(Skeletal_Muscle_Mass)"] / (frame["BFM_(Body_Fat_Mass)"] + 1e-5)
        )
        frame["Hydration_Stress"] = frame["ECW/TBW"] * frame["50kHz-Whole_Body_Phase_Angle"]
        frame["Lean_Per_Height"] = (
            frame["SMM_(Skeletal_Muscle_Mass)"] / ((frame["Height"] / 100) ** 2)
        )

        # 4. Final safety check: features that are biologically impossible at 0.0
        # NOTE: Gender=0.0 is valid (female), Delta_* can be 0.0, ECW/TBW ratios can be low.
        # Only flag features where 0.0 is a clear sign of a broken imputation pipeline.
        _NEVER_ZERO = {
            "Height", "Weight", "Age", "SMM_(Skeletal_Muscle_Mass)",
            "BMR_(Basal_Metabolic_Rate)", "TBW_(Total_Body_Water)",
        }
        for col in _NEVER_ZERO:
            if col in frame.columns:
                assert frame[col].iloc[0] != 0.0, (
                    f"Critical Pipeline Error: biological feature '{col}' is 0.0 before scaling."
                )

        aligned = frame[self.feature_columns]
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
