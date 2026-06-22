"""response_builder.py — Stage 4 of the dynamic InBody OCR pipeline.

Responsibilities:
  1. Convert all values to metric (lb→kg, ft+in→cm, lb-water→L).
  2. Apply biological cross-validation (nullify implausible extracted values).
  3. Enrich fields with confidence / validation metadata.
  4. Build the PDF output contract alongside the legacy Flutter field map.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional, Tuple

import json
import os
from confidence_engine import enrich_field, extraction_confidence, fields_needing_verification
from document_analyser import DocumentLayout
from field_extractor import FIELD_DESCRIPTORS

logger = logging.getLogger("smart_fit_backend.ocr.response_builder")

# Legacy Flutter keys → PDF canonical field names
CANONICAL_FIELD_MAP: Dict[str, str] = {
    "Age": "age",
    "Gender": "gender",
    "Height": "height_cm",
    "Weight": "weight_kg",
    "SMM_(Skeletal_Muscle_Mass)": "smm_kg",
    "BMR_(Basal_Metabolic_Rate)": "bmr_kcal",
    "FFM_of_Trunk": "segmental_ffm",
    "TBW_(Total_Body_Water)": "tbw_l",
    "ECW/TBW": "ecw_tbw_ratio",
    "50kHz-Whole_Body_Phase_Angle": "phase_angle",
    "BFM_(Body_Fat_Mass)": "bfm_kg",
    "PBF_(Percent_Body_Fat)": "pbf_percent",
}

# Load version metrics
_VERSION_METRICS_PATH = os.path.join(os.path.dirname(__file__), "config", "version_metrics.json")
try:
    with open(_VERSION_METRICS_PATH, "r", encoding="utf-8") as f:
        VERSION_METRICS = json.load(f)
except Exception as e:
    logger.warning("Could not load version_metrics.json: %s", e)
    VERSION_METRICS = {"versions": {}}


class ResponseBuilder:
    """Converts raw extracted fields into the final extraction dict."""

    def build(
        self,
        raw_fields: Dict[str, dict],
        layout: DocumentLayout,
        block_count: int = 0,
    ) -> dict:
        metric_fields = self._convert_to_metric(raw_fields, layout.units)
        validated_fields, validation_warnings, failed_keys = self._cross_validate(metric_fields)
        imputed_fields = self._impute_missing_fields(validated_fields)

        enriched_fields: Dict[str, dict] = {}
        report_type = layout.model.replace("-class", "")
        
        # Determine unsupported metrics for this version
        version_config = VERSION_METRICS.get("versions", {}).get(report_type, {})
        unsupported_keys = set(version_config.get("unsupported", []))

        # Derive BMI/PBF if missing but dependents exist
        self._derive_metrics(imputed_fields)

        for key, fdata in imputed_fields.items():
            enriched_fields[key] = enrich_field(
                key,
                fdata,
                cross_validated=key not in failed_keys,
            )
            if fdata.get("is_imputed"):
                enriched_fields[key]["extraction_method"] = "imputed"
            
            # Apply unsupported flag and override review actions
            if key in unsupported_keys:
                enriched_fields[key]["unsupported"] = True
                enriched_fields[key]["needs_review"] = False
                enriched_fields[key]["validation_status"] = "missing"
                enriched_fields[key]["review_action"] = "auto_accept"


        missing: List[str] = [
            key for key, fdata in enriched_fields.items()
            if fdata.get("value") is None and not fdata.get("unsupported", False)
        ]

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

        verify_fields = fields_needing_verification(enriched_fields)
        if verify_fields:
            warnings.append(
                "Fields requiring manual verification: " + ", ".join(verify_fields)
            )

        found_confs = [
            f["confidence"]
            for f in enriched_fields.values()
            if f.get("value") is not None and not f.get("is_imputed", False)
        ]
        avg_conf = round(
            sum(found_confs) / len(found_confs), 4
        ) if found_confs else 0.0

        report_type = layout.model.replace("-class", "")
        overall_conf = extraction_confidence(enriched_fields)

        return {
            "report_type": report_type,
            "scan_datetime": None,
            "extraction_confidence": overall_conf,
            "layout": {
                "template": layout.model,
                "units": layout.units,
                "confidence": self._layout_confidence(layout),
            },
            "fields": enriched_fields,
            "canonical_fields": self._build_canonical_fields(enriched_fields),
            "missing_fields": missing,
            "fields_needing_verification": verify_fields,
            "warnings": warnings,
            "ocr": {
                "engine": "easyocr",
                "block_count": block_count,
                "average_confidence": avg_conf,
            },
        }

    def _build_canonical_fields(
        self,
        fields: Dict[str, dict],
    ) -> Dict[str, dict[str, Any]]:
        canonical: Dict[str, dict[str, Any]] = {}
        for legacy_key, canon_key in CANONICAL_FIELD_MAP.items():
            fdata = fields.get(legacy_key, {})
            # Skip metrics strictly unsupported by this hardware version
            if fdata.get("unsupported", False):
                continue
                
            value = fdata.get("value")
            if canon_key == "gender" and value is not None:
                display_value: Any = "male" if float(value) == 1.0 else "female"
            else:
                display_value = value
                
            extraction_method = fdata.get("extraction_method", "extracted")
            if extraction_method == "mathematical_derivation":
                source = "derived"
            elif extraction_method in {"imputed", "estimated"}:
                source = "estimated"
            elif extraction_method == "none":
                source = "extracted"
            else:
                source = "extracted"
                
            canonical[canon_key] = {
                "value": display_value,
                "confidence": fdata.get("confidence", 0.0),
                "source": source,
                "needs_review": fdata.get("needs_review", display_value is None),
            }
        return canonical

    _MASS_FIELDS = frozenset({"Weight", "SMM_(Skeletal_Muscle_Mass)", "BFM_(Body_Fat_Mass)", "FFM_of_Trunk"})
    _WATER_FIELDS = frozenset({"TBW_(Total_Body_Water)"})

    def _derive_metrics(self, fields: Dict[str, dict]) -> None:
        """Derive mathematically exact metrics if extraction failed and inputs exist."""
        # 1. BMI = Weight / Height^2
        weight_fdata = fields.get("Weight", {})
        height_fdata = fields.get("Height", {})
        weight = weight_fdata.get("value")
        height = height_fdata.get("value")
        bmi_field = fields.get("BMI")
        if bmi_field and bmi_field.get("value") is None and weight and height and height > 0:
            bmi_val = round(weight / ((height / 100) ** 2), 1)
            bmi_field["value"] = bmi_val
            # Inherit minimum confidence from dependencies
            w_conf = weight_fdata.get("confidence", 0.0)
            h_conf = height_fdata.get("confidence", 0.0)
            bmi_field["confidence"] = min(w_conf, h_conf)
            bmi_field["source"] = "derived"
            bmi_field["extraction_method"] = "mathematical_derivation"
        
        # 2. PBF = (BFM / Weight) * 100
        bfm_fdata = fields.get("BFM_(Body_Fat_Mass)", {})
        bfm = bfm_fdata.get("value")
        pbf_field = fields.get("PBF_(Percent_Body_Fat)")
        
        if pbf_field and pbf_field.get("value") is None and weight and bfm and weight > 0:
            pbf_val = round((bfm / weight) * 100, 2)
            pbf_field["value"] = pbf_val
            # Inherit minimum confidence from dependencies
            w_conf = weight_fdata.get("confidence", 0.0)
            b_conf = bfm_fdata.get("confidence", 0.0)
            pbf_field["confidence"] = min(w_conf, b_conf)
            pbf_field["source"] = "derived"
            pbf_field["extraction_method"] = "mathematical_derivation"
            
    def _convert_to_metric(
        self,
        raw_fields: Dict[str, dict],
        units: str,
    ) -> Dict[str, dict]:
        converted: Dict[str, dict] = {}

        for key, fdata in raw_fields.items():
            val: Optional[float] = fdata.get("value")
            conf: float = fdata.get("confidence", 0.0)
            unit: str = fdata.get("unit", "")

            base = {
                "unit": unit,
                "confidence": conf,
                "is_imputed": False,
                "source_region": fdata.get("source_region", ""),
                "extraction_method": fdata.get("extraction_method", "none"),
                "needs_review": fdata.get("needs_review", False),
            }

            if val is None or units == "metric":
                converted[key] = {**base, "value": val}
                continue

            if key in self._MASS_FIELDS:
                val = round(val * 0.453592, 2)
            elif key in self._WATER_FIELDS:
                val = round(val / 2.20462, 2)
            elif key == "Height":
                val = round(val, 1)

            converted[key] = {**base, "value": val}

        return converted

    def _cross_validate(
        self,
        fields: Dict[str, dict],
    ) -> Tuple[Dict[str, dict], List[str], set[str]]:
        result = {k: v.copy() for k, v in fields.items()}
        warnings: List[str] = []
        failed_keys: set[str] = set()

        def val(key: str) -> Optional[float]:
            return result.get(key, {}).get("value")

        weight  = val("Weight")
        smm     = val("SMM_(Skeletal_Muscle_Mass)")
        bfm     = val("BFM_(Body_Fat_Mass)")
        pbf     = val("PBF_(Percent_Body_Fat)")
        tbw     = val("TBW_(Total_Body_Water)")
        ffm_t   = val("FFM_of_Trunk")
        age     = val("Age")

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
                failed_keys.add("SMM_(Skeletal_Muscle_Mass)")
                warnings.append(msg)

        if weight is not None and bfm is not None and pbf is not None and weight > 0:
            calc_pbf = (bfm / weight) * 100.0
            if abs(calc_pbf - pbf) > 10.0:
                warnings.append(
                    f"PBF ({pbf:.1f}%) differs from BFM/Weight calculation "
                    f"({calc_pbf:.1f}%) by more than 10 pp — "
                    "one of BFM, Weight, or PBF may be incorrectly extracted"
                )

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
                failed_keys.add("TBW_(Total_Body_Water)")
                warnings.append(msg)

        if weight is not None and ffm_t is not None:
            if ffm_t > weight * 0.60:
                msg = (
                    f"FFM of Trunk ({ffm_t:.1f} kg) exceeds 60% of weight "
                    f"({weight:.1f} kg) — FFM_of_Trunk nullified"
                )
                logger.warning(msg)
                result["FFM_of_Trunk"]["value"] = None
                result["FFM_of_Trunk"]["confidence"] = 0.0
                failed_keys.add("FFM_of_Trunk")
                warnings.append(msg)

        if age is not None and not (10 <= age <= 110):
            result["Age"]["value"] = None
            result["Age"]["confidence"] = 0.0
            failed_keys.add("Age")
            warnings.append(f"Extracted age ({age}) is out of plausible range")

        return result, warnings, failed_keys

    def _impute_missing_fields(self, fields: Dict[str, dict]) -> Dict[str, dict]:
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
        bmr = val("BMR_(Basal_Metabolic_Rate)")

        if bmr is None and weight is not None and bfm is not None:
            lbm = weight - bfm
            imputed_bmr = 370 + (21.6 * lbm)
            result["BMR_(Basal_Metabolic_Rate)"] = {
                "value": round(imputed_bmr, 0),
                "unit": "kcal",
                "confidence": 0.70,
                "is_imputed": True,
                "source_region": "imputed",
                "extraction_method": "estimated",
                "needs_review": True,
            }

        if tbw is None and weight is not None:
            imputed_tbw = None
            if bfm is not None:
                ffm = weight - bfm
                imputed_tbw = ffm * 0.732
            elif age is not None and height is not None and gender is not None:
                if gender == 1.0:
                    imputed_tbw = 2.447 - (0.09156 * age) + (0.1074 * height) + (0.3362 * weight)
                else:
                    imputed_tbw = -2.097 + (0.1069 * height) + (0.2466 * weight)

            if imputed_tbw is not None:
                result["TBW_(Total_Body_Water)"] = {
                    "value": round(imputed_tbw, 2),
                    "unit": "L",
                    "confidence": 0.55,
                    "is_imputed": True,
                    "source_region": "imputed",
                    "extraction_method": "estimated",
                    "needs_review": True,
                }

        if ecw_tbw is None and age is not None:
            imputed_ecw = 0.370 + (age * 0.0004)
            result["ECW/TBW"] = {
                "value": round(imputed_ecw, 3),
                "unit": "ratio",
                "confidence": 0.55,
                "is_imputed": True,
                "source_region": "imputed",
                "extraction_method": "estimated",
                "needs_review": True,
            }

        if (
            phase_angle is None
            and weight is not None
            and height is not None
            and height > 0
            and age is not None
            and gender is not None
        ):
            bmi = weight / ((height / 100.0) ** 2)
            if gender == 1.0:
                imputed_pa = 8.6 - (0.044 * age) + (0.015 * bmi)
            else:
                imputed_pa = 7.6 - (0.035 * age) + (0.012 * bmi)
            result["50kHz-Whole_Body_Phase_Angle"] = {
                "value": round(imputed_pa, 1),
                "unit": "deg",
                "confidence": 0.55,
                "is_imputed": True,
                "source_region": "imputed",
                "extraction_method": "estimated",
                "needs_review": True,
            }

        return result

    @staticmethod
    def _layout_confidence(layout: DocumentLayout) -> float:
        conf = 0.0
        if layout.model not in {"InBodyUnknown"}:
            conf += 0.25
        section_score = min(0.45, len(layout.sections) / 10 * 0.45)
        conf += section_score
        conf += min(0.30, layout.average_ocr_confidence * 0.30)
        return round(min(conf, 0.99), 4)
