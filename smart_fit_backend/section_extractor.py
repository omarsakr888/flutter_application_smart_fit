"""section_extractor.py — Anchor-aligned block extraction within template section ROIs."""
from __future__ import annotations

import re
from dataclasses import dataclass
from difflib import SequenceMatcher
from typing import Optional

import numpy as np

from easyocr_engine import EasyOcrEngine
from ocr_normalizer import parse_normalized_float
from ocr_types import OcrBlock
from roi_utils import crop_roi, normalized_to_pixel, upscale_for_ocr


@dataclass
class SectionBlock:
    text: str
    confidence: float
    x1: float
    y1: float
    x2: float
    y2: float

    @property
    def cx(self) -> float:
        return (self.x1 + self.x2) / 2

    @property
    def cy(self) -> float:
        return (self.y1 + self.y2) / 2


def blocks_from_crop(engine: EasyOcrEngine, crop: np.ndarray) -> list[SectionBlock]:
    if crop.size == 0:
        return []
    scaled = upscale_for_ocr(crop, min_height=80)
    raw = engine.extract_blocks(scaled)
    sh, sw = scaled.shape[:2]
    ch, cw = crop.shape[:2]
    sx = cw / sw
    sy = ch / sh

    result: list[SectionBlock] = []
    for block in raw:
        xs = [p[0] * sx for p in block.bbox]
        ys = [p[1] * sy for p in block.bbox]
        result.append(
            SectionBlock(
                text=block.text.strip(),
                confidence=block.confidence,
                x1=min(xs),
                y1=min(ys),
                x2=max(xs),
                y2=max(ys),
            )
        )
    return result


def _match_label(text: str, synonyms: list[str]) -> bool:
    t = text.lower().strip().rstrip(":")
    for syn in synonyms:
        s = syn.lower().strip()
        if s in t or t in s:
            return True
        if len(s) >= 4 and SequenceMatcher(None, t, s).ratio() >= 0.78:
            return True
    return False


def _row_blocks(blocks: list[SectionBlock], anchor: SectionBlock, y_tol: float) -> list[SectionBlock]:
    return sorted(
        [
            b
            for b in blocks
            if b is not anchor and abs(b.cy - anchor.cy) <= y_tol
        ],
        key=lambda b: b.x1,
    )


def _combine_numeric_text(parts: list[str]) -> str:
    return " ".join(parts)


def extract_label_value(
    blocks: list[SectionBlock],
    label_synonyms: list[str],
    *,
    direction: str = "right",
    value_type: str = "float",
) -> tuple[Optional[float], float, str]:
    """Find label block then nearest value block(s) in the given direction."""
    labels = [b for b in blocks if _match_label(b.text, label_synonyms)]
    if not labels:
        return None, 0.0, ""

    best_val: Optional[float] = None
    best_conf = 0.0
    best_raw = ""

    for anchor in labels:
        y_tol = max(8.0, (anchor.y2 - anchor.y1) * 0.8)
        if direction == "right":
            candidates = _row_blocks(blocks, anchor, y_tol)
            candidates = [c for c in candidates if c.x1 >= anchor.x2 - 5]
        elif direction == "below":
            candidates = sorted(
                [
                    b
                    for b in blocks
                    if b is not anchor
                    and b.y1 >= anchor.y2 - 3
                    and abs(b.cx - anchor.cx) < (anchor.x2 - anchor.x1) * 2.5
                ],
                key=lambda b: b.y1,
            )[:3]
        else:
            candidates = []

        if value_type == "gender_word":
            for cand in candidates[:2]:
                low = cand.text.lower()
                if "female" in low or low == "f":
                    return 0.0, cand.confidence, cand.text
                if "male" in low or low == "m":
                    return 1.0, cand.confidence, cand.text
            continue

        # Collect numeric tokens on same row (handles split "156." + "9cm")
        numeric_parts: list[str] = []
        confs: list[float] = []
        for cand in candidates[:4]:
            cleaned = cand.text.replace("cm", "").replace("kg", "").replace("kcal", "").strip()
            if re.search(r"\d", cleaned):
                numeric_parts.append(cand.text)
                confs.append(cand.confidence)

        if not numeric_parts:
            continue

        raw = _combine_numeric_text(numeric_parts)
        if value_type == "composite_ft_in":
            val = _parse_height(raw)
        else:
            val = parse_normalized_float(raw.replace("cm", "").replace("l", ""))

        if val is None:
            continue

        conf = (anchor.confidence * 0.35 + sum(confs) / len(confs) * 0.65)
        if conf > best_conf:
            best_val = val
            best_conf = conf
            best_raw = raw

    return best_val, best_conf, best_raw


def _parse_height(text: str) -> Optional[float]:
    m = re.search(r"(\d+)\s*ft\s*(\d+(?:\.\d+)?)\s*in", text, re.IGNORECASE)
    if m:
        return round((float(m.group(1)) * 12 + float(m.group(2))) * 2.54, 1)
    # Metric split OCR: "156." "9cm"
    merged = text.replace(" ", "").replace("cm", "")
    val = parse_normalized_float(merged)
    if val and 100 <= val <= 230:
        return val
    return parse_normalized_float(text.replace("cm", ""))


def extract_bar_end_value(
    blocks: list[SectionBlock],
    label_synonyms: list[str],
) -> tuple[Optional[float], float, str]:
    """Extract numeric value at the end of a muscle-fat / obesity bar row."""
    labels = [b for b in blocks if _match_label(b.text, label_synonyms)]
    if not labels:
        return None, 0.0, ""

    best: tuple[Optional[float], float, str] = (None, 0.0, "")
    for anchor in labels:
        y_tol = max(10.0, (anchor.y2 - anchor.y1) * 1.2)
        row = _row_blocks(blocks, anchor, y_tol)
        numeric = []
        for cand in row:
            if cand.x1 <= anchor.x2 + 10:
                continue
            val = parse_normalized_float(cand.text)
            if val is not None:
                numeric.append((cand, val))

        if not numeric:
            continue

        # Bar-end value is the rightmost numeric on the row
        cand, val = max(numeric, key=lambda item: item[0].x1)
        conf = anchor.confidence * 0.4 + cand.confidence * 0.6
        if conf > best[1]:
            best = (val, conf, cand.text)

    return best


def extract_trunk_from_segmental(
    blocks: list[SectionBlock],
) -> tuple[Optional[float], float, str]:
    """Find Trunk row in segmental lean section."""
    trunk_anchors = [b for b in blocks if _match_label(b.text, ["Trunk"])]
    if not trunk_anchors:
        return None, 0.0, ""

    best: tuple[Optional[float], float, str] = (None, 0.0, "")
    for anchor in trunk_anchors:
        y_tol = max(8.0, (anchor.y2 - anchor.y1) * 0.9)
        row = _row_blocks(blocks, anchor, y_tol)
        for cand in row:
            if cand.x1 <= anchor.x2:
                continue
            val = parse_normalized_float(cand.text)
            if val is not None and val > 1.0:
                conf = anchor.confidence * 0.4 + cand.confidence * 0.6
                if conf > best[1]:
                    best = (val, conf, cand.text)
    return best
