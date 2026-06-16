"""easyocr_response_builder.py — Stage 4: Conversion & Imputation

This module finalizes the OCR payload by converting Imperial units to Metric,
and applying Clinical Imputations for missing fields.
"""
from __future__ import annotations

import math
from typing import Any

from ocr_types import ExtractedField

LBS_TO_KG = 0.45359237

class EasyOcrResponseBuilder:
    def __init__(self, raw_metrics: dict[str, float | None], layout: str, units: str):
        self.raw_metrics = raw_metrics
        self.layout = layout
        self.units = units
        self.final_fields: list[ExtractedField] = []

    def build(self) -> dict[str, Any]:
        self._apply_imperial_conversion()
        self._apply_clinical_imputations()
        self._construct_extracted_fields()
        
        return {
            "layout": self.layout,
            "units": self.units,
            "fields": [f.to_json() for f in self.final_fields]
        }

    def _apply_imperial_conversion(self):
        if self.units == "Imperial":
            mass_keys = [
                "Weight", "SMM_(Skeletal_Muscle_Mass)", "BMR_(Basal_Metabolic_Rate)", 
                "FFM_of_Trunk", "TBW_(Total_Body_Water)", "BFM_(Body_Fat_Mass)"
            ]
            for key in mass_keys:
                if self.raw_metrics.get(key) is not None:
                    # BMR is technically kcal, not mass, but sometimes scaled if extracted as lb-based?
                    # The prompt says: "multiply all lbs values by 0.45359237 to yield kg (or L for TBW)"
                    # We skip BMR because BMR is in kcal.
                    if key == "BMR_(Basal_Metabolic_Rate)":
                        continue
                        
                    self.raw_metrics[key] = round(self.raw_metrics[key] * LBS_TO_KG, 2)
                    
            # Height imperial conversion is assumed to be handled in the field_extractor 
            # if it extracts "5 ft 10 in". However, if we just got a raw float like 70.0 (inches),
            # we should convert it to cm.
            height = self.raw_metrics.get("Height")
            if height is not None and height < 100.0:
                # Assuming it's in inches
                self.raw_metrics["Height"] = round(height * 2.54, 1)

    def _apply_clinical_imputations(self):
        age = self.raw_metrics.get("Age", 30.0) or 30.0
        gender = self.raw_metrics.get("Gender", 1.0)
        gender = 1.0 if gender is None else gender
        height = self.raw_metrics.get("Height", 170.0) or 170.0
        weight = self.raw_metrics.get("Weight")
        bfm = self.raw_metrics.get("BFM_(Body_Fat_Mass)")
        tbw = self.raw_metrics.get("TBW_(Total_Body_Water)")
        phase_angle = self.raw_metrics.get("50kHz-Whole_Body_Phase_Angle")
        ecw_tbw = self.raw_metrics.get("ECW/TBW")

        self.imputed_flags = set()

        if weight is None:
            # Cannot do most calculations without weight
            return

        # 1. TBW Imputation
        if tbw is None:
            if bfm is None:
                if gender == 1.0: # Male
                    bfm = 2.447 - (0.09156 * age) + (0.1074 * height) + (0.3362 * weight)
                else: # Female
                    bfm = -2.097 + (0.1069 * height) + (0.2466 * weight)
                
            self.raw_metrics["TBW_(Total_Body_Water)"] = round((weight - bfm) * 0.732, 2)
            self.imputed_flags.add("TBW_(Total_Body_Water)")

        # 2. Phase Angle Imputation
        if phase_angle is None:
            bmi = weight / ((height / 100) ** 2)
            if gender == 1.0: # Male
                self.raw_metrics["50kHz-Whole_Body_Phase_Angle"] = round(8.6 - (0.044 * age) + (0.015 * bmi), 1)
            else: # Female
                self.raw_metrics["50kHz-Whole_Body_Phase_Angle"] = round(7.6 - (0.035 * age) + (0.012 * bmi), 1)
            self.imputed_flags.add("50kHz-Whole_Body_Phase_Angle")

        # 3. ECW/TBW Imputation
        if ecw_tbw is None:
            self.raw_metrics["ECW/TBW"] = round(0.370 + (age * 0.0004), 3)
            self.imputed_flags.add("ECW/TBW")

    def _construct_extracted_fields(self):
        units_map = {
            "Age": "Years",
            "Gender": "",
            "Height": "cm",
            "Weight": "kg",
            "SMM_(Skeletal_Muscle_Mass)": "kg",
            "BMR_(Basal_Metabolic_Rate)": "kcal",
            "FFM_of_Trunk": "kg",
            "TBW_(Total_Body_Water)": "L",
            "ECW/TBW": "Ratio",
            "50kHz-Whole_Body_Phase_Angle": "°",
            "BFM_(Body_Fat_Mass)": "kg",
            "PBF_(Percent_Body_Fat)": "%"
        }

        for key, val in self.raw_metrics.items():
            if val is None:
                continue

            field = ExtractedField(
                key=key,
                label=key.replace("_", " "),
                value=val,
                raw_text=str(val),
                unit=units_map.get(key, ""),
                confidence=1.0 if key in getattr(self, 'imputed_flags', set()) else 0.95,
                source="imputed" if key in getattr(self, 'imputed_flags', set()) else "easyocr"
            )
            self.final_fields.append(field)
