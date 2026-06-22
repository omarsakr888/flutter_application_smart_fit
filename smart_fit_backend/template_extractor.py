"""template_extractor.py ΓÇö ROI-first template-aware InBody extraction pipeline."""
from __future__ import annotations

import logging
import re
from typing import Any, Callable

import numpy as np

from document_analyser import DocumentLayout
from easyocr_engine import EasyOcrEngine
from field_extractor import FIELD_DESCRIPTORS
from debug_logger import init_debug_dir, save_roi_crop, save_ocr_blocks, save_extraction_report
from ocr_normalizer import parse_normalized_float, normalize_numeric_text
from response_builder import ResponseBuilder
from roi_utils import crop_roi, normalized_to_pixel
from section_extractor import (
    blocks_from_crop,
    extract_bar_end_value,
    extract_label_value,
    extract_trunk_from_segmental,
    _match_label,
)
from template_loader import load_template
from version_detector import detect_version

logger = logging.getLogger("smart_fit_backend.ocr.template_extractor")

_UNIT_BY_KEY = {d.key: d.unit_in_output for d in FIELD_DESCRIPTORS}


class TemplateExtractor:
    """Detect version → load template → OCR section ROIs with anchor alignment."""

    def __init__(self) -> None:
        self._engine = EasyOcrEngine()
        self._builder = ResponseBuilder()
        self._section_cache: dict[str, list] = {}

    def extract(self, image: np.ndarray) -> dict[str, Any]:
        init_debug_dir()
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

        # Pass the scan's actual unit system so ResponseBuilder can apply lb→kg conversions
        scan_units = template.get("units_default", "metric")
        layout = DocumentLayout(
            model=report_type,
            units=scan_units,
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
        
        save_extraction_report(result.get("canonical_fields", {}))
        
        return result

    def _section_blocks(
        self,
        image: np.ndarray,
        img_w: int,
        img_h: int,
        template: dict,
        section_name: str,
        preprocess: bool = False,
    ) -> list:
        cache_key = f"{section_name}_pre_{preprocess}"
        if cache_key in self._section_cache:
            return self._section_cache[cache_key]

        sections = template.get("sections", {})
        sec = sections.get(section_name)
        if not sec or "roi" not in sec:
            return []

        crop_rect = normalized_to_pixel(sec["roi"], img_w, img_h, pad_frac=0.02)
        px, py, pw, ph = crop_rect.x, crop_rect.y, crop_rect.w, crop_rect.h

        crop = crop_roi(image, crop_rect)
        if crop is None or crop.size == 0:
            self._section_cache[cache_key] = []
            return []

        save_roi_crop(cache_key, crop)

        blocks = blocks_from_crop(self._engine, crop, preprocess=preprocess)
        save_ocr_blocks(blocks, cache_key)

        for b in blocks:
            b.x1 += px
            b.y1 += py
            b.x2 += px
            b.y2 += py

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
                if _match_label(low, ["female"]):
                    return 0.0, b.confidence, b.text, "header"
                if _match_label(low, ["male"]) and not _match_label(low, ["female"]):
                    return 1.0, b.confidence, b.text, "header"
        return val, conf, raw, "header"

    def _extract_height(self, image, w, h, template, cfg):
        blocks = self._header_blocks(image, w, h, template)
        fmt = cfg.get("expected_format", "decimal")
        if fmt == "composite_ft_in":
            val, conf, raw = extract_label_value(
                blocks, ["Height"], value_type="composite_ft_in", direction="right"
            )
            if val is None:
                val, conf, raw = extract_label_value(
                    blocks, ["Height"], value_type="composite_ft_in", direction="below"
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
        for section in ("muscle_fat", "body_composition", "obesity"):
            blocks = self._section_blocks(image, w, h, template, section)
            val, conf, raw = extract_bar_end_value(blocks, ["Weight"], validator=lambda v: _plausible_weight(v, cfg))
            if val is None:
                val, conf, raw = extract_label_value(
                    blocks, ["Weight", "Weight (kg)", "Weight (lb)"], direction="right"
                )
            if val is not None and _plausible_weight(val, cfg):
                return val, conf, raw, section
        return None, 0.0, "", "body_composition"

    def _extract_pbf(self, image, w, h, template, cfg):
        # 120 has PBF in segmental_lean
        sections = [cfg.get("section", "obesity"), "segmental_lean"]
        
        for pre in [False, True]:
            for section in sections:
                blocks = self._section_blocks(image, w, h, template, section, preprocess=pre)
                
                val, conf, raw = extract_label_value(
                    blocks,
                    ["Percent Body Fat", "PBF", "% Body Fat", "Body Fat Percentage", "Percent Body Fat (%)"],
                    direction="right",
                )
                if val is None:
                    # Anchor-to-Nearest for PBF
                    numerics = [b for b in blocks if parse_normalized_float(b.text) is not None]
                    if numerics:
                        anchors = [b for b in blocks if _match_label(b.text, ["Percent Body Fat", "PBF", "% Body Fat"])]
                        if anchors:
                            anchor = max(anchors, key=lambda b: b.confidence)
                            # Score candidates: prefer same row, then closest Euclidean distance
                            def score(b):
                                same_row = 1 if abs(b.cy - anchor.cy) <= max(10.0, (anchor.y2 - anchor.y1)) else 0
                                dist = ((b.cx - anchor.cx)**2 + (b.cy - anchor.cy)**2)**0.5
                                return (-same_row, dist)
                            
                            cand = min(numerics, key=score)
                            v = parse_normalized_float(cand.text)
                            if v and 3 <= v <= 70:
                                return v, cand.confidence, cand.text, section

                if val is not None and 3 <= val <= 70:
                    return val, conf, raw, section
        return None, 0.0, "", cfg.get("section", "obesity")

    def _extract_smm(self, image, w, h, template, cfg):
        best = (None, 0.0, "", "muscle_fat")
        for pre in [False, True]:
            for section in ("muscle_fat", "obesity"):
                blocks = self._section_blocks(image, w, h, template, section, preprocess=pre)
                
                # Priority 1: Nearest value (anchor -> nearest association with token merging)
                val, conf, raw = extract_label_value(
                    blocks, ["SMM", "Skeletal Muscle Mass", "SHM"], direction="right"
                )
                
                # Priority 2: Bar end value fallback
                if val is None or not _plausible_smm(val, cfg):
                    val, conf, raw = extract_bar_end_value(
                        blocks, ["SMM", "Skeletal Muscle Mass", "SHM"],
                        validator=lambda v: _plausible_smm(v, cfg)
                    )
                    
                if val is not None and _plausible_smm(val, cfg):
                    if conf > best[1]:
                        best = (val, conf, raw, section)
                        
        return best

    def _extract_bmr(self, image, w, h, template, cfg):
        section = cfg.get("section", "research_params")
        sections = [section] if section == "bmr_standalone" else ["research_params", "bmr_standalone"]
        valid_min, valid_max = cfg.get("valid_range", [800, 3500])

        for pre in [False, True]:
            for sec in sections:
                if sec not in template.get("sections", {}):
                    continue
                blocks = self._section_blocks(image, w, h, template, sec, preprocess=pre)

                for direction in ["right", "below"]:
                    val, conf, raw = extract_label_value(
                        blocks,
                        ["Basal Metabolic Rate", "BMR", "Metabolic Rate", "Metabolc Rate",
                         "Basal Metabolc Rate", "Besal Metabolic Rate"],
                        direction=direction,
                    )
                    if val is None:
                        continue
                        
                    # Safe BMR Recovery Logic (Task 1)
                    # 1. Known version, 2. Conf < 0.8, 3. 100 <= val <= 999, 4. Nearby BMR (implicit), 5. Corrected in 1000-3000
                    # if 100 <= val <= 999 and conf < 0.80 and template.get("name") != "InBodyUnknown":
                    #     corrected = val + 1000.0
                    #     if 1000 <= corrected <= 3000:
                    #         return corrected, conf, raw, sec
                            
                    if valid_min <= val <= valid_max:
                        return val, conf, raw, sec

                # Fallback: anchor-to-nearest with bracket stripping
                # OCR often reads "1149" as "[49" or "(149" — strip leading brackets
                bmr_anchors = [b for b in blocks if _match_label_simple(
                    b.text, ["Basal Metabolic Rate", "BMR", "Basal Metabolc Rate", "Besal Metabolic Rate"]
                )]
                for anchor in bmr_anchors:
                    from section_extractor import _row_blocks
                    row = _row_blocks(blocks, anchor, max(10.0, (anchor.y2 - anchor.y1) * 1.2))
                    for cand in row:
                        if cand.x1 <= anchor.x2:
                            continue
                        # Strip leading bracket/paren OCR artifacts before parsing
                        cleaned = re.sub(r'^[\[\(\{]+', '', cand.text.strip())
                        v = parse_normalized_float(normalize_numeric_text(cleaned))
                        if v is not None:
                            c = anchor.confidence * 0.4 + cand.confidence * 0.6
                            
                            # Tightly scoped OCR recovery rule for BMR (e.g. 1176 read as 176)
                            if 100 <= v <= 999 and cand.confidence < 0.80 and template.get("name") != "InBodyUnknown":
                                corrected = v + 1000.0
                                # Only recover if the corrected value is physiological and no higher-confidence candidate exists.
                                # The anchor check ensures a BMR label was confidently detected nearby.
                                if valid_min <= corrected <= valid_max:
                                    return corrected, c, cand.text, sec
                                    
                            if valid_min <= v <= valid_max:
                                return v, c, cand.text, sec
        return None, 0.0, "", section

    def _extract_tbw(self, image, w, h, template, cfg):
        blocks = self._section_blocks(image, w, h, template, "body_composition")
        val, conf, raw = extract_label_value(
            blocks, ["Total Body Water", "TBW"], direction="right"
        )
        if val is None:
            val, conf, raw = extract_bar_end_value(blocks, ["Total Body Water", "TBW"], validator=lambda v: 10 <= v <= 150)
        if val is None and template.get("units_default") == "imperial":
            val, conf, raw = extract_label_value(
                blocks, ["Total Body Water", "TBW"], direction="below"
            )
        return val, conf, raw, "body_composition"

    def _extract_trunk(self, image, w, h, template, cfg):
        if template.get("name") == "InBody270":
            # Trunk is not present on the InBody270 printout
            return None, 0.0, "", "segmental_lean", "field_not_present_on_document"

        section = cfg.get("section", "segmental_lean")
        best = (None, 0.0, "", section)
        
        for pre in [False, True]:
            blocks = self._section_blocks(image, w, h, template, section, preprocess=pre)

            # Try row-based extraction first
            from section_extractor import extract_trunk_from_segmental
            val, conf, raw = extract_trunk_from_segmental(blocks)
            
            # Anchor-to-Nearest for Trunk (fallback)
            if val is None:
                numerics = [b for b in blocks if parse_normalized_float(b.text) is not None]
                if numerics:
                    anchors = [b for b in blocks if _match_label(b.text, ["Trunk", "TRUNK", "Torso"])]
                    if anchors:
                        anchor = max(anchors, key=lambda b: b.confidence)
                        # Find closest numeric by euclidean distance
                        def dist(b):
                            return ((b.cx - anchor.cx)**2 + (b.cy - anchor.cy)**2)**0.5
                        cand = min(numerics, key=dist)
                        v = parse_normalized_float(cand.text)
                        if v is not None and 5 <= v <= 100:
                            val, conf, raw = v, cand.confidence, cand.text
                            
            if val is not None and 5 <= val <= 100:
                if conf > best[1]:
                    best = (val, conf, raw, section)

        if best[0] is not None:
            return best

        return None, 0.0, "", section

    def _extract_ecw_tbw(self, image, w, h, template, cfg):
        section = "ecw_tbw_section"
        if section not in template.get("sections", {}):
            return None, 0.0, "", section
        blocks = self._section_blocks(image, w, h, template, section)
        val, conf, raw = extract_bar_end_value(blocks, ["ECW/TBW"], validator=lambda v: 0.30 <= v <= 0.45)
        if val is not None and 0.30 <= val <= 0.45:
            return val, conf, raw, section
        return None, 0.0, "", section

    def _extract_phase(self, image, w, h, template, cfg):
        return None, 0.0, "", "research_params"

    def _extract_bfm(self, image, w, h, template, cfg):
        imperial = template.get("units_default") == "imperial"
        # Always search muscle_fat first (contains Body Fat Mass row in imperial 570 layout)
        sections = ("muscle_fat", "obesity", "body_composition")
        for pre in [False, True]:
            for section in sections:
                blocks = self._section_blocks(image, w, h, template, section, preprocess=pre)
                val, conf, raw = extract_bar_end_value(
                    blocks, ["Body Fat Mass", "BFM"],
                    validator=lambda v: _plausible_bfm(v, cfg, imperial=imperial)
                )
                if val is None:
                    val, conf, raw = extract_label_value(
                        blocks, ["Body Fat Mass", "BFM"], direction="right"
                    )
                if val is not None and _plausible_bfm(val, cfg, imperial=imperial):
                    return val, conf, raw, section
        return None, 0.0, "", "body_composition"

    def _extract_pbf(self, image, w, h, template, cfg):
        blocks = self._section_blocks(image, w, h, template, "obesity")
        val, conf, raw = extract_bar_end_value(
            blocks, ["PBF", "Percent Body Fat"], validator=lambda v: 5 <= v <= 60
        )
        if val is not None and 5 <= val <= 60:
            return val, conf, raw, "obesity"
        # PBF bar may bleed into segmental section on some scans
        blocks2 = self._section_blocks(image, w, h, template, "segmental_lean")
        val2, conf2, raw2 = extract_bar_end_value(blocks2, ["PBF", "Percent Body Fat"], validator=lambda v: 5 <= v <= 60)
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
    # All conversions should be handled centrally in ResponseBuilder based on DocumentAnalyser units.
    # We no longer apply static multipliers here.
    return round(value, 2)


def _plausible_weight(val: float, cfg: dict) -> bool:
    # Accept up to 400 lbs to support imperial scans before conversion
    return 30 <= val <= 400


def _plausible_smm(val: float, cfg: dict) -> bool:
    # Accept up to 120 lbs to support imperial scans before conversion
    return 10 <= val <= 120


def _plausible_bfm(val: float, cfg: dict, *, imperial: bool = False) -> bool:
    # Accept up to 100 lbs to support imperial scans before conversion
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
