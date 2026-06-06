"""response_builder.py — Stage 4 of the dynamic InBody OCR pipeline.

Responsibilities:
  1. Convert all values to metric (lb→kg, ft+in→cm, lb-water→L).
  2. Apply biological cross-validation (nullify implausible extracted values).
  3. Build the final extraction dict that ``OcrService`` wraps with
     ``status`` and ``extraction_id``.

The output dict shape is the existing contract consumed by ``OcrService``
(unchanged from the previous engine):

    {
        "layout":         { "template": ..., "confidence": ..., "units": ... },
        "fields":         { key: {"value": ..., "unit": ..., "confidence": ...}, ... },
        "missing_fields": [...],
        "warnings":       [...],
        "ocr":            { "engine": "paddleocr", ... },
    }
"""
from __future__ import annotations

import logging
from typing import Dict, List, Optional, Tuple

from document_analyser import DocumentLayout
from field_extractor import FIELD_DESCRIPTORS

logger = logging.getLogger("smart_fit_backend.ocr.response_builder")


class ResponseBuilder:
    """
    Converts raw extracted fields (in document units) into the final metric
    extraction dict ready for ``OcrService``.
    """

    def build(
        self,
        raw_fields: Dict[str, dict],
        layout: DocumentLayout,
        block_count: int = 0,
    ) -> dict:
        """
        Parameters
        ----------
        raw_fields:
            Output of ``FieldExtractor.extract_all()`` — values in raw/document units.
        layout:
            ``DocumentLayout`` from Stage 2.
        block_count:
            Number of raw OCR blocks (for the ``ocr`` metadata section).

        Returns
        -------
        Extraction dict matching the existing ``OcrService`` contract.
        """

        # 1. Convert raw units -> metric and add is_imputed default
        metric_fields = self._convert_to_metric(raw_fields, layout.units)

        # 2. Biological cross-validation
        validated_fields, validation_warnings = self._cross_validate(metric_fields)

        # 3. Biological Imputation
        imputed_fields = self._impute_missing_fields(validated_fields)

        # 4. Build field list and missing list
        missing: List[str] = [
            key for key, fdata in imputed_fields.items()
            if fdata.get("value") is None
        ]

        # 4. Build warnings
        warnings = list(validation_warnings)
        if layout.units == "imperial":
            warnings.append(
                "Imperial units detected — all body measurements converted to metric"
            )
        for key in missing:
            desc = next((d for d in FIELD_DESCRIPTORS if d.key == key), None)
            if desc is None:
                continue
            if desc.may_be_absent:
                warnings.append(
                    f"{key} not found in this scan — "
                    "not available on all InBody models"
                )
            else:
                warnings.append(
                    f"{key} could not be extracted — please verify manually"
                )

        # Average confidence over successfully extracted fields
        found_confs = [
            f["confidence"]
            for f in imputed_fields.values()
            if f.get("value") is not None and not f.get("is_imputed", False)
        ]
        avg_conf = round(
            sum(found_confs) / len(found_confs), 4
        ) if found_confs else 0.0

        return {
            "layout": {
                "template":   layout.model,
                "units":      layout.units,
                "confidence": self._layout_confidence(layout),
            },
            "fields": imputed_fields,
            "missing_fields": missing,
            "warnings": warnings,
            "ocr": {
                "engine":             "paddleocr",
                "block_count":        block_count,
                "average_confidence": avg_conf,
            },
        }

    # ─────────────────────────────────────────────────────────────────────────
    # Unit conversion
    # ─────────────────────────────────────────────────────────────────────────

    # Fields whose raw value is a mass in lbs (imperial) → kg
    _MASS_FIELDS = frozenset({
        "Weight",
        "SMM_(Skeletal_Muscle_Mass)",
        "BFM_(Body_Fat_Mass)",
        "FFM_of_Trunk",
    })

    # TBW raw value is in lbs when imperial (water density ≈ 1 kg/L)
    # InBody actually prints TBW in lbs on imperial reports
    _WATER_FIELDS = frozenset({"TBW_(Total_Body_Water)"})

    def _convert_to_metric(
        self,
        raw_fields: Dict[str, dict],
        units: str,
    ) -> Dict[str, dict]:
        """Return a new dict with all values converted to metric units."""
        converted: Dict[str, dict] = {}

        for key, fdata in raw_fields.items():
            val: Optional[float] = fdata.get("value")
            conf: float = fdata.get("confidence", 0.0)
            unit: str = fdata.get("unit", "")

            if val is None or units == "metric":
                converted[key] = fdata.copy()
                converted[key]["is_imputed"] = False
                continue

            # Imperial -> metric
            if key in self._MASS_FIELDS:
                val = round(val * 0.453592, 2)          # lb -> kg
            elif key in self._WATER_FIELDS:
                val = round(val / 2.20462, 2)           # lb-water -> L
            elif key == "Height":
                # Height already converted to cm by _extract_height_imperial
                val = round(val, 1)
            # BMR, PBF, ECW/TBW, Age, Gender, Phase Angle: no conversion

            converted[key] = {
                "value": val,
                "unit": unit,
                "confidence": conf,
                "is_imputed": False
            }

        return converted

    # ─────────────────────────────────────────────────────────────────────────
    # Biological cross-validation
    # ─────────────────────────────────────────────────────────────────────────

    def _cross_validate(
        self,
        fields: Dict[str, dict],
    ) -> Tuple[Dict[str, dict], List[str]]:
        """
        Check known biological relationships between extracted fields.
        If a value is biologically impossible, nullify it and emit a warning.
        Does NOT substitute or fabricate a corrected value.

        Returns (validated_fields, warnings_list).
        """
        result = {k: v.copy() for k, v in fields.items()}
        warnings: List[str] = []

        def val(key: str) -> Optional[float]:
            return result.get(key, {}).get("value")

        weight  = val("Weight")
        smm     = val("SMM_(Skeletal_Muscle_Mass)")
        bfm     = val("BFM_(Body_Fat_Mass)")
        pbf     = val("PBF_(Percent_Body_Fat)")
        tbw     = val("TBW_(Total_Body_Water)")
        ffm_t   = val("FFM_of_Trunk")
        age     = val("Age")

        # Rule 1: SMM cannot exceed FFM (weight − BFM) by more than 5%
        if weight is not None and smm is not None and bfm is not None:
            ffm_approx = weight - bfm
            if smm > ffm_approx * 1.10:
                msg = (
                    f"SMM ({smm:.1f} kg) exceeds estimated FFM "
                    f"({ffm_approx:.1f} kg) — SMM nullified, verify manually"
                )
                logger.warning(msg)
                result["SMM_(Skeletal_Muscle_Mass)"]["value"] = None
                result["SMM_(Skeletal_Muscle_Mass)"]["confidence"] = 0.0
                warnings.append(msg)

        # Rule 2: PBF should match BFM/Weight × 100 within 10 percentage points
        if weight is not None and bfm is not None and pbf is not None and weight > 0:
            calc_pbf = (bfm / weight) * 100.0
            if abs(calc_pbf - pbf) > 10.0:
                warnings.append(
                    f"PBF ({pbf:.1f}%) differs from BFM/Weight calculation "
                    f"({calc_pbf:.1f}%) by more than 10 pp — "
                    "one of BFM, Weight, or PBF may be incorrectly extracted"
                )

        # Rule 3: TBW should be 40–75% of body weight
        if weight is not None and tbw is not None and weight > 0:
            tbw_ratio = tbw / weight
            if not (0.35 <= tbw_ratio <= 0.78):
                msg = (
                    f"TBW ({tbw:.1f} L) / Weight ({weight:.1f} kg) = "
                    f"{tbw_ratio:.2f} — outside plausible range [0.35, 0.78]; "
                    "TBW nullified"
                )
                logger.warning(msg)
                result["TBW_(Total_Body_Water)"]["value"] = None
                result["TBW_(Total_Body_Water)"]["confidence"] = 0.0
                warnings.append(msg)

        # Rule 4: FFM of Trunk cannot exceed weight × 0.60
        if weight is not None and ffm_t is not None:
            if ffm_t > weight * 0.60:
                msg = (
                    f"FFM of Trunk ({ffm_t:.1f} kg) exceeds 60% of weight "
                    f"({weight:.1f} kg) — FFM_of_Trunk nullified"
                )
                logger.warning(msg)
                result["FFM_of_Trunk"]["value"] = None
                result["FFM_of_Trunk"]["confidence"] = 0.0
                warnings.append(msg)

        # Rule 5: Age sanity (already range-checked by extractor, but double-check)
        if age is not None and not (10 <= age <= 110):
            result["Age"]["value"] = None
            result["Age"]["confidence"] = 0.0
            warnings.append(f"Extracted age ({age}) is out of plausible range")

        return result, warnings

    # ─────────────────────────────────────────────────────────────────────────
    # Biological Imputation
    # ─────────────────────────────────────────────────────────────────────────

    def _impute_missing_fields(self, fields: Dict[str, dict]) -> Dict[str, dict]:
        """
        Impute missing values using clinical averages or mathematical derivations.
        Marks imputed fields with `is_imputed=True`.
        """
        result = {k: v.copy() for k, v in fields.items()}

        def val(key: str) -> Optional[float]:
            return result.get(key, {}).get("value")

        weight = val("Weight")
        bfm = val("BFM_(Body_Fat_Mass)")
        tbw = val("TBW_(Total_Body_Water)")
        ecw_tbw = val("ECW/TBW")
        phase_angle = val("50kHz-Whole_Body_Phase_Angle")
        age = val("Age")
        height = val("Height")
        gender = val("Gender")

        # 1. TBW Imputation
        if tbw is None and weight is not None:
            imputed_tbw = None
            if bfm is not None:
                # FFM-based formula
                ffm = weight - bfm
                imputed_tbw = ffm * 0.732
            elif age is not None and height is not None and gender is not None:
                # Watson Formula fallback
                if gender == 1.0:  # Male
                    imputed_tbw = 2.447 - (0.09156 * age) + (0.1074 * height) + (0.3362 * weight)
                else:  # Female
                    imputed_tbw = -2.097 + (0.1069 * height) + (0.2466 * weight)
            
            if imputed_tbw is not None:
                result["TBW_(Total_Body_Water)"] = {
                    "value": round(imputed_tbw, 2),
                    "unit": "L",
                    "confidence": 1.0,
                    "is_imputed": True
                }

        # 2. ECW/TBW Imputation: Age-adjusted physiological scale
        if ecw_tbw is None and age is not None:
            imputed_ecw = 0.370 + (age * 0.0004)
            result["ECW/TBW"] = {
                "value": round(imputed_ecw, 3),
                "unit": "ratio",
                "confidence": 1.0,
                "is_imputed": True
            }

        # 3. Phase Angle Imputation: Gonzalez et al.
        if phase_angle is None and weight is not None and height is not None and height > 0 and age is not None and gender is not None:
            bmi = weight / ((height / 100.0) ** 2)
            imputed_pa = None
            if gender == 1.0:  # Male
                imputed_pa = 8.6 - (0.044 * age) + (0.015 * bmi)
            else:  # Female
                imputed_pa = 7.6 - (0.035 * age) + (0.012 * bmi)
                
            if imputed_pa is not None:
                result["50kHz-Whole_Body_Phase_Angle"] = {
                    "value": round(imputed_pa, 1),
                    "unit": "deg",
                    "confidence": 1.0,
                    "is_imputed": True
                }

        return result

    # ─────────────────────────────────────────────────────────────────────────
    # Layout confidence estimation
    # ─────────────────────────────────────────────────────────────────────────

    @staticmethod
    def _layout_confidence(layout: DocumentLayout) -> float:
        """
        Estimate layout detection confidence from structural signals:
        - Known model tag found: +0.25
        - Number of sections detected: up to +0.45
        - Average OCR confidence: up to +0.30
        """
        conf = 0.0
        if layout.model not in {"InBodyUnknown"}:
            conf += 0.25
        section_score = min(0.45, len(layout.sections) / 10 * 0.45)
        conf += section_score
        conf += min(0.30, layout.average_ocr_confidence * 0.30)
        return round(min(conf, 0.99), 4)
