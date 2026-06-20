"""version_detector.py — Detect InBody report version before ROI extraction."""
from __future__ import annotations

import logging

import numpy as np

from easyocr_engine import EasyOcrEngine
from roi_utils import crop_roi, normalized_to_pixel, upscale_for_ocr
from section_extractor import blocks_from_crop
from template_loader import load_all_templates

logger = logging.getLogger("smart_fit_backend.ocr.version_detector")

_HEADER_ROI = {"x": 0.0, "y": 0.0, "w": 1.0, "h": 0.12}
_BODY_ROI = {"x": 0.0, "y": 0.0, "w": 1.0, "h": 0.70}


def detect_version(engine: EasyOcrEngine, image: np.ndarray) -> tuple[str, float, str]:
    """Return (report_type, confidence, detection_method)."""
    templates = load_all_templates()
    h, w = image.shape[:2]

    header_crop = crop_roi(image, normalized_to_pixel(_HEADER_ROI, w, h, pad_frac=0.0))
    blocks = blocks_from_crop(engine, header_crop)
    header_text = " ".join(b.text for b in blocks).upper()

    scores: dict[str, float] = {}
    for tid, tmpl in templates.items():
        score = 0.0
        for anchor in tmpl.get("version_anchors", []):
            anchor_u = anchor.upper().replace(" ", "")
            text_u = header_text.replace(" ", "")
            if anchor_u in text_u or anchor.upper() in header_text:
                score += 0.60
                break
        if tid == "InBody570" and (" FT " in f" {header_text} " or "LB)" in header_text):
            score += 0.25
        if tid == "InBody120" and ("ATHLETEHOME" in header_text or "01060444060" in header_text):
            score += 0.35
        if tid in {"InBody120", "InBody270"} and "CM" in header_text:
            score += 0.10
        scores[tid] = score

    best = max(scores, key=scores.get)
    if scores[best] >= 0.50:
        header_conf = sum(b.confidence for b in blocks) / len(blocks) if blocks else 0.0
        return best, min(0.99, scores[best] + header_conf * 0.15), "header_anchor"

    body_crop = crop_roi(image, normalized_to_pixel(_BODY_ROI, w, h, pad_frac=0.0))
    body_blocks = blocks_from_crop(engine, body_crop)
    body_text = " ".join(b.text for b in body_blocks).upper()

    for tid, tmpl in templates.items():
        for marker in tmpl.get("unique_section_markers", []):
            if marker.upper() in body_text:
                scores[tid] = scores.get(tid, 0.0) + 0.45

    best = max(scores, key=scores.get)
    if scores[best] >= 0.40:
        return best, min(0.95, scores[best]), "section_marker"

    aspect = w / h if h else 1.0
    if aspect > 0.76:
        return "InBody570", 0.35, "aspect_ratio_fallback"
    if "ATHLETEHOME" in header_text:
        return "InBody120", 0.35, "branding_fallback"

    logger.warning("Version detection uncertain; defaulting to InBody270")
    return "InBody270", 0.25, "default_fallback"
