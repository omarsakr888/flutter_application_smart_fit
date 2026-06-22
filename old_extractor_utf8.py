"""template_extractor.py ΓÇö ROI-first template-aware InBody extraction pipeline."""
from __future__ import annotations

import logging
import re
from typing import Any, Callable

import numpy as np

from document_analyser import DocumentLayout
from easyocr_engine import EasyOcrEngine
from field_extractor import FIELD_DESCRIPTORS
from ocr_normalizer import parse_normalized_float
from response_builder import ResponseBuilder
from roi_utils import crop_roi, normalized_to_pixel
from section_extractor import (
    blocks_from_crop,
    extract_bar_end_value,
    extract_label_value,
    extract_trunk_from_segmental,
)
from template_loader import load_template
from version_detector import detect_version

logger = logging.getLogger("smart_fit_backend.ocr.template_extractor")

_UNIT_BY_KEY = {d.key: d.unit_in_output for d in FIELD_DESCRIPTORS}


class TemplateExtractor:
    """Detect version ΓåÆ load template ΓåÆ OCR section ROIs with anchor alignment."""

    def __init__(self) -> None:
        self._engine = EasyOcrEngine()
        self._builder = ResponseBuilder()
        self._section_cache: dict[str, list] = {}

    def extract(self, image: np.ndarray) -> dict[str, Any]:
        img_h, img_w = image.shape[:2]
        self._section_cache.clear()

        report_type, version_conf, detect_method = detect_version(self._engine, image)
        template = load_template(report_type)

        logger.info(
            "Template extraction: version=%s (conf=%.2f, method=%s)",
            report_type,
            version_conf,
            detect_method,
        )

        raw_fields: dict[str, dict[str, Any]] = {}
        roi_count = 0

        extractors: list[tuple[str, str, Callable[..., Any]]] = [
            ("age_roi", "Age", self._extract_age),
            ("gender_roi", "Gender", self._extract_gender),
            ("height_roi", "Height", self._extract_height),
            ("weight_roi", "Weight", self._extract_weight),
            ("smm_roi", "SMM_(Skeletal_Muscle_Mass)", self._extract_smm),
            ("bmr_roi", "BMR_(Basal_Metabolic_Rate)", self._extract_bmr),
            ("tbw_roi", "TBW_(Total_Body_Water)", self._extract_tbw),
            ("segmental_ffm_roi", "FFM_of_Trunk", self._extract_trunk),
            ("ecw_tbw_roi", "ECW/TBW", self._extract_ecw_tbw),
            ("phase_angle_roi", "50kHz-Whole_Body_Phase_Angle", self._extract_phase),
            ("bfm_roi", "BFM_(Body_Fat_Mass)", self._extract_bfm),
            ("pbf_roi", "PBF_(Percent_Body_Fat)", self._extract_pbf),
        ]

        for roi_key, legacy_key, fn in extractors:
            field_cfg = template.get(roi_key, {})
            unit = _UNIT_BY_KEY.get(legacy_key, "")

            if field_cfg.get("present") is False:
                raw_fields[legacy_key] = _empty_field(
                    unit, field_cfg.get("section", ""), absent=True
                )
                continue

            value, conf, raw_text, section = fn(image, img_w, img_h, template, field_cfg)
            roi_count += 1
            value = _convert_to_metric(value, field_cfg)

            raw_fields[legacy_key] = {
                "value": value,
                "unit": unit,
                "confidence": round(conf, 4),
                "source_region": section,
                "extraction_method": "template_anchor",
                "raw_text": raw_text,
            }

        layout = DocumentLayout(
            model=report_type,
            units="metric",
            sections={
                name: (sec["roi"]["y"], sec["roi"]["y"] + sec["roi"]["h"])
                for name, sec in template.get("sections", {}).items()
                if "roi" in sec
            },
            has_ecw_tbw_section=report_type == "InBody570",
            has_phase_angle=False,
            has_segmental_rows=report_type == "InBody570",
            raw_tokens=[],
            full_text="",
            average_ocr_confidence=version_conf,
        )

        result = self._builder.build(raw_fields=raw_fields, layout=layout, block_count=roi_count)
        result["ocr"]["engine"] = "easyocr_template"
        result["ocr"]["detection_method"] = detect_method
        result["ocr"]["version_confidence"] = version_conf
        result["template"] = report_type
        return result

    def _section_blocks(
        self,
        image: np.ndarray,
        img_w: int,
        img_h: int,
        template: dict,
        section_name: str,
    ) -> list:
        cache_key = section_name
        if cache_key in self._section_cache:
            return self._section_cache[cache_key]

        sections = template.get("sections", {})
        sec = sections.get(section_name)
        if not sec or "roi" not in sec:
            self._section_cache[cache_key] = []
            return []

        crop = crop_roi(image, normalized_to_pixel(sec["roi"], img_w, img_h, pad_frac=0.02))
        blocks = blocks_from_crop(self._engine, crop)
        self._section_cache[cache_key] = blocks
        return blocks

    def _header_blocks(self, image, w, h, template) -> list:
        blocks = list(self._section_blocks(image, w, h, template, "header"))
        # Only top rows of body composition (demographics bleed into this section)
        bc = self._section_blocks(image, w, h, template, "body_composition")
        if bc:
            cutoff_y = min(b.cy for b in bc) + (max(b.cy for b in bc) - min(b.cy for b in bc)) * 0.35
            blocks.extend([b for b in bc if b.cy <= cutoff_y][:12])
        return blocks

    def _extract_age(self, image, w, h, template, cfg):
        blocks = self._header_blocks(image, w, h, template)
        labels = [b for b in blocks if _match_label_simple(b.text, ["Age"])]
        for anchor in labels:
            y_tol = max(8.0, (anchor.y2 - anchor.y1) * 0.9)
            row = sorted(
                [b for b in blocks if b is not anchor and abs(b.cy - anchor.cy) <= y_tol and b.x1 > anchor.x1 - 5],
                key=lambda b: b.x1,
            )
            for cand in row[:3]:
                v = parse_normalized_float(cand.text)
                if v is not None and 10 <= v <= 110 and v == int(v) and len(cand.text.strip()) <= 3:
                    return float(int(v)), cand.confidence, cand.text, "header"
        # Fallback: short standalone integer in header blocks only
        for b in blocks:
            text = b.text.strip()
            if len(text) > 3 or _looks_like_date(text):
                continue
            v = parse_normalized_float(text)
            if v is not None and 10 <= v <= 110 and v == int(v):
                return float(int(v)), b.confidence, b.text, "header"
        return None, 0.0, "", "header"

    def _extract_gender(self, image, w, h, template, cfg):
        blocks = self._header_blocks(image, w, h, template)
        val, conf, raw = extract_label_value(
            blocks, ["Gender", "Female", "Male"], value_type="gender_word"
        )
        if val is None:
            for b in blocks:
                low = b.text.lower()
                if "female" in low:
                    return 0.0, b.confidence, b.text, "header"
                if "male" in low and "female" not in low:
                    return 1.0, b.confidence, b.text, "header"
        return val, conf, raw, "header"

    def _extract_height(self, image, w, h, template, cfg):
        blocks = self._header_blocks(image, w, h, template)
        fmt = cfg.get("expected_format", "decimal")
        if fmt == "composite_ft_in":
            val, conf, raw = extract_label_value(
                blocks, ["Height"], value_type="composite_ft_in"
            )
            return val, conf, raw, "header"
        # Metric: look for cm-labelled value first
        for b in blocks:
            t = b.text.lower()
            if "cm" in t or "," in b.text:
                v = parse_normalized_float(
                    b.text.replace("cm", "").replace("cmn", "").replace(",", ".")
                )
                if v and 100 <= v <= 230:
                    return v, b.confidence, b.text, "header"
        for i, b in enumerate(blocks):
            if re.match(r"^\d{3}$", b.text.strip()):
                if i + 1 < len(blocks) and "cm" in blocks[i + 1].text.lower():
                    merged = b.text + "." + blocks[i + 1].text.replace("cm", "").replace("cmn", "").strip()
                    v = parse_normalized_float(merged)
                    if v and 100 <= v <= 230:
                        conf = (b.confidence + blocks[i + 1].confidence) / 2
                        return v, conf, merged, "header"
        return None, 0.0, "", "header"

    def _extract_weight(self, image, w, h, template, cfg):
        for section in ("muscle_fat", "body_composition"):
            blocks = self._section_blocks(image, w, h, template, section)
            val, conf, raw = extract_bar_end_value(blocks, ["Weight"])
            if val is None:
                val, conf, raw = extract_label_value(
                    blocks, ["Weight", "Weight (kg)", "Weight (lb)"], direction="right"
                )
            if val is not None and _plausible_weight(val, cfg):
                return val, conf, raw, section
        return None, 0.0, "", "body_composition"

    def _extract_smm(self, image, w, h, template, cfg):
        for section in ("muscle_fat", "obesity"):
            blocks = self._section_blocks(image, w, h, template, section)
            val, conf, raw = extract_bar_end_value(
                blocks, ["SMM", "Skeletal Muscle Mass", "SHM"]
            )
            if val is not None and _plausible_smm(val, cfg):
                return val, conf, raw, section
        return None, 0.0, "", "muscle_fat"

    def _extract_bmr(self, image, w, h, template, cfg):
        section = cfg.get("section", "research_params")
        sections = [section] if section == "bmr_standalone" else ["research_params", "bmr_standalone"]
        for sec in sections:
            if sec not in template.get("sections", {}):
                continue
            blocks = self._section_blocks(image, w, h, template, sec)
            val, conf, raw = extract_label_value(
                blocks,
                ["Basal Metabolic Rate", "BMR", "Metabolic Rate", "Metabolc Rate"],
                direction="right",
            )
            if val is not None and 800 <= val <= 3500:
                return val, conf, raw, sec
            # OCR may split 1154 as separate blocks ΓÇö pick best kcal-range number
            for b in blocks:
                if "kcal" in b.text.lower() or "kal" in b.text.lower():
                    continue
                v = parse_normalized_float(b.text)
                if v is not None and 800 <= v <= 3500:
                    return v, b.confidence, b.text, sec
        return None, 0.0, "", section

    def _extract_tbw(self, image, w, h, template, cfg):
        blocks = self._section_blocks(image, w, h, template, "body_composition")
        val, conf, raw = extract_label_value(
            blocks, ["Total Body Water", "TBW"], direction="right"
        )
        if val is None:
            val, conf, raw = extract_bar_end_value(blocks, ["Total Body Water", "TBW"])
        if val is None and template.get("units_default") == "imperial":
            val, conf, raw = extract_label_value(
                blocks, ["Total Body Water", "TBW"], direction="below"
            )
        return val, conf, raw, "body_composition"

    def _extract_trunk(self, image, w, h, template, cfg):
        blocks = self._section_blocks(image, w, h, template, "segmental_lean")
        val, conf, raw = extract_trunk_from_segmental(blocks)
        if val is None:
            # Figure layout: trunk mass often largest kg value near "Trunk"
            for b in blocks:
                v = parse_normalized_float(b.text)
                if v and 10 <= v <= 50:
                    val, conf, raw = v, b.confidence, b.text
                    break
        return val, conf, raw, "segmental_lean"

    def _extract_ecw_tbw(self, image, w, h, template, cfg):
        section = "ecw_tbw_section"
        if section not in template.get("sections", {}):
            return None, 0.0, "", section
        blocks = self._section_blocks(image, w, h, template, section)
        val, conf, raw = extract_bar_end_value(blocks, ["ECW/TBW"])
        if val is not None and 0.30 <= val <= 0.45:
            return val, conf, raw, section
        return None, 0.0, "", section

    def _extract_phase(self, image, w, h, template, cfg):
        return None, 0.0, "", "research_params"

    def _extract_bfm(self, image, w, h, template, cfg):
        imperial = template.get("units_default") == "imperial"
        sections = ("obesity",) if imperial else ("obesity", "muscle_fat", "body_composition")
        for section in sections:
            blocks = self._section_blocks(image, w, h, template, section)
            val, conf, raw = extract_bar_end_value(blocks, ["Body Fat Mass", "BFM"])
            if val is None:
                val, conf, raw = extract_label_value(
                    blocks, ["Body Fat Mass", "BFM"], direction="right"
                )
            if val is not None and _plausible_bfm(val, cfg, imperial=imperial):
                if section == "body_composition" and val > 24:
                    continue
                return val, conf, raw, section
        return None, 0.0, "", "body_composition"

    def _extract_pbf(self, image, w, h, template, cfg):
        blocks = self._section_blocks(image, w, h, template, "obesity")
        val, conf, raw = extract_bar_end_value(
            blocks, ["PBF", "Percent Body Fat"]
        )
        if val is not None and 5 <= val <= 60:
            return val, conf, raw, "obesity"
        # PBF bar may bleed into segmental section on some scans
        blocks2 = self._section_blocks(image, w, h, template, "segmental_lean")
        val2, conf2, raw2 = extract_bar_end_value(blocks2, ["PBF", "Percent Body Fat"])
        return val2, conf2, raw2, "obesity"


def _empty_field(unit: str, section: str, *, absent: bool = False) -> dict[str, Any]:
    return {
        "value": None,
        "unit": unit,
        "confidence": 0.0,
        "source_region": section,
        "extraction_method": "absent_on_model" if absent else "none",
        "raw_text": "",
    }


def _convert_to_metric(value: float | None, field_cfg: dict[str, Any]) -> float | None:
    if value is None:
        return None
    convert_to = field_cfg.get("convert_to")
    if not convert_to:
        return round(value, 2)
    factor = field_cfg.get("conversion_factor")
    if convert_to == "kg" and factor:
        return round(value * factor, 2)
    if convert_to == "L":
        return round(value / 2.20462, 2)
    return round(value, 2)


def _plausible_weight(val: float, cfg: dict) -> bool:
    if cfg.get("convert_to") == "kg":
        return 30 <= val <= 400  # lb range before conversion
    return 30 <= val <= 200


def _plausible_smm(val: float, cfg: dict) -> bool:
    if cfg.get("convert_to") == "kg":
        return 15 <= val <= 120
    return 10 <= val <= 80


def _plausible_bfm(val: float, cfg: dict, *, imperial: bool = False) -> bool:
    if cfg.get("convert_to") == "kg" or imperial:
        return 5 <= val <= 95  # lb before conversion for imperial scans
    return 3 <= val <= 100


def _looks_like_date(text: str) -> bool:
    if "/" in text or "-" in text:
        return True
    return bool(re.search(r"20\d{2}|:\d{2}", text))


def _match_label_simple(text: str, synonyms: list[str]) -> bool:
    t = text.lower().strip().rstrip(":")
    for syn in synonyms:
        s = syn.lower().strip()
        if s == t or s in t:
            return True
    return False
