"""easyocr_extractor.py — Spatial keyword-to-value matching for InBody scans.

Consumes horizontally clustered EasyOCR rows, pairs metric labels with the
nearest numeric value on the same alignment, converts imperial units to metric,
and applies clinical imputation for absent fields.
"""
from __future__ import annotations

import logging
import re
from typing import Any

from field_extractor import FIELD_DESCRIPTORS, FieldDescriptor
from ocr_types import OcrBlock

logger = logging.getLogger(__name__)

LBS_TO_KG = 0.45359237
LB_WATER_TO_L = 1.0 / 2.20462

_MASS_FIELDS = frozenset({
    "Weight",
    "SMM_(Skeletal_Muscle_Mass)",
    "BFM_(Body_Fat_Mass)",
    "FFM_of_Trunk",
})
_WATER_FIELDS = frozenset({"TBW_(Total_Body_Water)"})

_FLOAT_RE = re.compile(r"-?\d+(?:[.,]\d+)?")
_IMPERIAL_RE = re.compile(r"\b(LBS?|FT|IN)\b", re.IGNORECASE)
_HEIGHT_IMPERIAL_RE = re.compile(
    r"(\d+)\s*(?:ft|')\s*(\d+(?:\.\d+)?)\s*(?:in|\"|''?)?",
    re.IGNORECASE,
)
_MODEL_PATTERNS = (
    ("InBody 270S", re.compile(r"\b270\s*S\b", re.IGNORECASE)),
    ("InBody 270", re.compile(r"\b270\b")),
    ("InBody 570", re.compile(r"\b570\b")),
    ("InBody 120", re.compile(r"\b120\b")),
)


class EasyOcrExtractor:
    """Extract the 12 InBody metrics from clustered OCR rows."""

    def __init__(
        self,
        rows: list[list[OcrBlock]],
        *,
        image_width: int,
        image_height: int,
        block_count: int = 0,
        average_confidence: float = 0.0,
    ) -> None:
        self.rows = rows
        self.blocks = [block for row in rows for block in row]
        self.image_width = max(image_width, 1)
        self.image_height = max(image_height, 1)
        self.block_count = block_count
        self.average_confidence = average_confidence
        self.full_text = " ".join(block.text for block in self.blocks)
        self.layout = self._detect_layout()
        self.units = self._detect_units()
        # Build a set of numeric values that appear 3+ times — almost certainly
        # scale bar tick marks (e.g. 80, 90, 100, 110 on InBody bar charts).
        self._scale_markers: set[float] = self._find_scale_markers()

    def extract(self) -> dict[str, Any]:
        """Return the Flutter-compatible extraction payload."""
        raw_fields = self._extract_raw_fields()
        metric_fields = self._convert_to_metric(raw_fields)
        imputed_fields = self._impute_missing_fields(metric_fields)

        missing = [
            descriptor.key
            for descriptor in FIELD_DESCRIPTORS
            if imputed_fields.get(descriptor.key, {}).get("value") is None
        ]

        warnings: list[str] = []
        if self.units == "imperial":
            warnings.append(
                "Imperial units detected — all body measurements converted to metric"
            )
        for descriptor in FIELD_DESCRIPTORS:
            if descriptor.key not in missing:
                continue
            if descriptor.may_be_absent:
                warnings.append(
                    f"{descriptor.key} not found in this scan — "
                    "not available on all InBody models"
                )
            else:
                warnings.append(
                    f"{descriptor.key} could not be extracted — please verify manually"
                )

        found_confs = [
            field["confidence"]
            for field in imputed_fields.values()
            if field.get("value") is not None and not field.get("is_imputed", False)
        ]
        avg_conf = round(sum(found_confs) / len(found_confs), 4) if found_confs else 0.0

        return {
            "layout": {
                "template": self.layout,
                "units": self.units,
                "confidence": self._layout_confidence(avg_conf),
            },
            "fields": imputed_fields,
            "missing_fields": missing,
            "warnings": warnings,
            "ocr": {
                "engine": "easyocr",
                "block_count": self.block_count,
                "average_confidence": avg_conf,
            },
        }

    # ── Scale marker detection ────────────────────────────────────────────────

    def _find_scale_markers(self) -> set[float]:
        """Return numeric values that appear 3+ times — likely bar-chart tick marks."""
        from collections import Counter
        counts: Counter = Counter()
        for block in self.blocks:
            val = self._parse_float(block.text)
            if val is not None and val >= 5.0:
                counts[val] += 1
        return {v for v, c in counts.items() if c >= 3}

    def _is_scale_marker(self, value: float) -> bool:
        """True if the value is a known scale tick (integer or .0/.5 multiples)."""
        if value not in self._scale_markers:
            return False
        # Only reject round values — decimals like 26.5 are real readings
        frac = value - int(value)
        return frac in {0.0, 0.5}

    # ── Layout / unit detection ───────────────────────────────────────────────

    def _detect_layout(self) -> str:
        for model_name, pattern in _MODEL_PATTERNS:
            if pattern.search(self.full_text):
                return model_name
        return "InBodyUnknown"

    def _detect_units(self) -> str:
        if _IMPERIAL_RE.search(self.full_text):
            return "imperial"
        return "metric"

    def _layout_confidence(self, avg_conf: float) -> float:
        score = 0.0
        if self.layout != "InBodyUnknown":
            score += 0.35
        score += min(0.35, len(self.rows) / 12 * 0.35)
        score += min(0.30, avg_conf * 0.30)
        return round(min(score, 0.99), 4)

    # ── Extraction ────────────────────────────────────────────────────────────

    def _extract_raw_fields(self) -> dict[str, dict[str, Any]]:
        results: dict[str, dict[str, Any]] = {}

        for descriptor in FIELD_DESCRIPTORS:
            value, confidence, source = self._extract_field(descriptor)
            results[descriptor.key] = {
                "value": value,
                "unit": descriptor.unit_in_output,
                "confidence": confidence,
                "is_imputed": False,
                "source": source,
            }

        return results

    def _extract_field(
        self,
        descriptor: FieldDescriptor,
    ) -> tuple[float | None, float, str]:
        if descriptor.key == "Gender":
            return self._extract_gender(descriptor)
        if descriptor.key == "Height":
            return self._extract_height(descriptor)
        if descriptor.key == "FFM_of_Trunk":
            return self._extract_trunk_ffm(descriptor)

        return self._extract_by_row_match(descriptor)

    def _extract_by_row_match(
        self,
        descriptor: FieldDescriptor,
    ) -> tuple[float | None, float, str]:
        for row_index, row in enumerate(self.rows):
            row_text = " ".join(block.text for block in row)
            if not self._row_matches_synonym(row_text, descriptor):
                continue

            value, confidence = self._nearest_value_in_row(row, descriptor)
            if value is not None and self._in_range(descriptor, value):
                return value, confidence, f"row:{row_index}"

        value, confidence = self._semantic_fallback(descriptor)
        if value is not None and self._in_range(descriptor, value):
            return value, confidence, "semantic"

        return None, 0.0, "missing"

    def _extract_gender(
        self,
        descriptor: FieldDescriptor,
    ) -> tuple[float | None, float, str]:
        for row_index, row in enumerate(self.rows):
            row_text = " ".join(block.text for block in row).lower()
            if not self._row_matches_synonym(row_text, descriptor):
                continue
            for block in row:
                text = block.text.lower()
                if re.search(r"\bmale\b", text) or re.fullmatch(r"m", text.strip()):
                    return 1.0, block.confidence, f"row:{row_index}"
                if re.search(r"\bfemale\b", text) or re.fullmatch(r"f", text.strip()):
                    return 0.0, block.confidence, f"row:{row_index}"
        return None, 0.0, "missing"

    def _extract_height(
        self,
        descriptor: FieldDescriptor,
    ) -> tuple[float | None, float, str]:
        for row_index, row in enumerate(self.rows):
            row_text = " ".join(block.text for block in row)
            if not self._row_matches_synonym(row_text.lower(), descriptor):
                continue

            for block in row:
                imperial_match = _HEIGHT_IMPERIAL_RE.search(block.text)
                if imperial_match:
                    feet = float(imperial_match.group(1))
                    inches = float(imperial_match.group(2))
                    cm = round(((feet * 12.0) + inches) * 2.54, 1)
                    return cm, block.confidence, f"row:{row_index}"

            value, confidence = self._nearest_value_in_row(row, descriptor)
            if value is not None:
                return value, confidence, f"row:{row_index}"

        return None, 0.0, "missing"

    def _extract_trunk_ffm(
        self,
        descriptor: FieldDescriptor,
    ) -> tuple[float | None, float, str]:
        if self.layout in {"InBody 120", "InBody 270", "InBody 270S"}:
            band_start = self.image_width * 0.30
            band_end = self.image_width * 0.55
            best_val: float | None = None
            best_conf = 0.0
            for block in self.blocks:
                if not (band_start <= block.center_x <= band_end):
                    continue
                val = self._parse_float(block.text)
                if val is None or not self._in_range(descriptor, val):
                    continue
                if best_val is None or val > best_val:
                    best_val = val
                    best_conf = block.confidence
            if best_val is not None:
                return best_val, best_conf, "segmental_center"

        return self._extract_by_row_match(descriptor)

    # ── Row helpers ───────────────────────────────────────────────────────────

    def _row_matches_synonym(self, row_text: str, descriptor: FieldDescriptor) -> bool:
        lowered = row_text.lower()
        for synonym in descriptor.label_synonyms:
            if synonym.lower() in lowered:
                return True
        return False

    def _nearest_value_in_row(
        self,
        row: list[OcrBlock],
        descriptor: FieldDescriptor,
    ) -> tuple[float | None, float]:
        label_blocks = [
            block
            for block in row
            if any(syn.lower() in block.text.lower() for syn in descriptor.label_synonyms)
        ]
        if not label_blocks:
            label_blocks = [row[0]]

        label_right = max(block.right for block in label_blocks)
        label_center_y = sum(block.center_y for block in label_blocks) / len(label_blocks)

        candidates: list[tuple[float, float, float]] = []
        for block in row:
            if any(syn.lower() in block.text.lower() for syn in descriptor.label_synonyms):
                continue
            if block.center_x < label_right - 5:
                continue
            if abs(block.center_y - label_center_y) > 25.0:
                continue
            val = self._parse_float(block.text)
            if val is None:
                continue
            if self._is_scale_marker(val):
                continue
            distance = block.center_x - label_right
            candidates.append((distance, val, block.confidence))

        if not candidates:
            return None, 0.0

        candidates.sort(key=lambda item: item[0])
        _, value, confidence = candidates[0]
        return value, confidence

    def _semantic_fallback(
        self,
        descriptor: FieldDescriptor,
    ) -> tuple[float | None, float]:
        for synonym in descriptor.label_synonyms:
            pattern = re.compile(
                re.escape(synonym) + r"[^\d]{0,24}(-?\d+(?:[.,]\d+)?)",
                re.IGNORECASE,
            )
            match = pattern.search(self.full_text)
            if not match:
                continue
            val = self._parse_float(match.group(1))
            if val is not None and not self._is_scale_marker(val):
                return val, 0.75
        return None, 0.0

    @staticmethod
    def _parse_float(text: str) -> float | None:
        match = _FLOAT_RE.search(text.replace(",", "."))
        if not match:
            return None
        try:
            return float(match.group().replace(",", "."))
        except ValueError:
            return None

    @staticmethod
    def _in_range(descriptor: FieldDescriptor, value: float) -> bool:
        low, high = descriptor.valid_range
        return low <= value <= high

    # ── Unit conversion ───────────────────────────────────────────────────────

    def _convert_to_metric(self, raw_fields: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
        converted: dict[str, dict[str, Any]] = {}

        for descriptor in FIELD_DESCRIPTORS:
            key = descriptor.key
            field = raw_fields[key]
            val = field.get("value")
            if val is None or self.units != "imperial":
                converted[key] = {
                    "value": val,
                    "unit": descriptor.unit_in_output,
                    "confidence": field.get("confidence", 0.0),
                    "is_imputed": False,
                }
                continue

            if key in _MASS_FIELDS:
                val = round(float(val) * LBS_TO_KG, 2)
            elif key in _WATER_FIELDS:
                val = round(float(val) * LB_WATER_TO_L, 2)
            elif key == "Height" and float(val) < 100.0:
                val = round(float(val) * 2.54, 1)

            converted[key] = {
                "value": val,
                "unit": descriptor.unit_in_output,
                "confidence": field.get("confidence", 0.0),
                "is_imputed": False,
            }

        return converted

    # ── Clinical imputation ───────────────────────────────────────────────────

    def _impute_missing_fields(
        self,
        fields: dict[str, dict[str, Any]],
    ) -> dict[str, dict[str, Any]]:
        result = {key: value.copy() for key, value in fields.items()}

        def val(key: str) -> float | None:
            raw = result.get(key, {}).get("value")
            return float(raw) if isinstance(raw, (int, float)) else None

        age = val("Age")
        gender = val("Gender")
        height = val("Height")
        weight = val("Weight")
        bfm = val("BFM_(Body_Fat_Mass)")

        if result.get("TBW_(Total_Body_Water)", {}).get("value") is None and weight is not None:
            imputed_tbw: float | None = None
            if bfm is not None:
                imputed_tbw = round((weight - bfm) * 0.732, 2)
            elif age is not None and height is not None and gender is not None:
                if gender == 1.0:
                    imputed_tbw = round(
                        2.447 - (0.09156 * age) + (0.1074 * height) + (0.3362 * weight),
                        2,
                    )
                else:
                    imputed_tbw = round(
                        -2.097 + (0.1069 * height) + (0.2466 * weight),
                        2,
                    )
            if imputed_tbw is not None:
                result["TBW_(Total_Body_Water)"] = {
                    "value": imputed_tbw,
                    "unit": "L",
                    "confidence": 1.0,
                    "is_imputed": True,
                }

        if (
            result.get("50kHz-Whole_Body_Phase_Angle", {}).get("value") is None
            and weight is not None
            and height is not None
            and height > 0
            and age is not None
            and gender is not None
        ):
            bmi = weight / ((height / 100.0) ** 2)
            if gender == 1.0:
                imputed_pa = round(8.6 - (0.044 * age) + (0.015 * bmi), 1)
            else:
                imputed_pa = round(7.6 - (0.035 * age) + (0.012 * bmi), 1)
            result["50kHz-Whole_Body_Phase_Angle"] = {
                "value": imputed_pa,
                "unit": "deg",
                "confidence": 1.0,
                "is_imputed": True,
            }

        if result.get("ECW/TBW", {}).get("value") is None and age is not None:
            imputed_ecw = round(0.370 + (age * 0.0004), 3)
            result["ECW/TBW"] = {
                "value": imputed_ecw,
                "unit": "ratio",
                "confidence": 1.0,
                "is_imputed": True,
            }

        return result
