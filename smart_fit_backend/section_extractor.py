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


def blocks_from_crop(engine: EasyOcrEngine, crop: np.ndarray, preprocess: bool = False) -> list[SectionBlock]:
    if crop.size == 0:
        return []
        
    if preprocess:
        import cv2
        # Apply CLAHE
        lab = cv2.cvtColor(crop, cv2.COLOR_BGR2LAB)
        l, a, b_ch = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8,8))
        cl = clahe.apply(l)
        limg = cv2.merge((cl, a, b_ch))
        crop = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)

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
    if not t:
        return False
    for syn in synonyms:
        s = syn.lower().strip()
        if s in t:
            return True
        if len(t) >= 4 and t in s:
            return True
        if len(s) >= 4 and SequenceMatcher(None, t, s).ratio() >= 0.65:
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
                    and abs(b.cx - anchor.cx) < max(15.0, (anchor.x2 - anchor.x1) * 0.8)
                ],
                key=lambda b: b.y1,
            )[:3]
        else:
            candidates = []

        if value_type == "gender_word":
            for cand in candidates[:2]:
                low = cand.text.lower()
                if "female" in low or low == "f" or (len(low) >= 4 and SequenceMatcher(None, low, "female").ratio() >= 0.65):
                    return 0.0, cand.confidence, cand.text
                if "male" in low or low == "m" or (len(low) >= 4 and SequenceMatcher(None, low, "male").ratio() >= 0.65):
                    return 1.0, cand.confidence, cand.text
            continue

        # Collect numeric tokens on same row (handles split "156." + "9cm" and "47"+"6"→"47.6")
        numeric_parts: list[str] = []
        confs: list[float] = []
        first_num = None
        prev_cand = None

        for cand in candidates[:6]:
            cleaned = cand.text.replace("cm", "").replace("kg", "").replace("kcal", "").strip()
            if re.search(r"\d", cleaned):
                if first_num is None:
                    first_num = cand
                    numeric_parts.append(cand.text)
                    confs.append(cand.confidence)
                    prev_cand = cand
                elif abs(cand.cy - first_num.cy) <= 8.0:
                    # Detect adjacent split tokens: e.g. "47" followed by "6" with small gap → "47.6"
                    horiz_gap = cand.x1 - prev_cand.x2
                    prev_clean = prev_cand.text.strip()
                    curr_clean = cand.text.strip()
                    # Join with '.' if: small gap AND previous token looks like integer AND next is 1 digit
                    if (horiz_gap <= 15
                            and re.fullmatch(r'\d{1,3}', prev_clean)
                            and re.fullmatch(r'\d', curr_clean)):
                        # Replace last part with merged decimal form
                        numeric_parts[-1] = f"{prev_clean}.{curr_clean}"
                    else:
                        numeric_parts.append(cand.text)
                    confs.append(cand.confidence)
                    prev_cand = cand

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
    validator: Optional[Callable[[float], bool]] = None,
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
                if validator is None or validator(val):
                    numeric.append((cand, val))

        if not numeric:
            continue

        # Bar-end value is the highest confidence valid numeric, prioritizing numbers with decimals over integer tick marks
        def _score(item):
            c, v = item
            from ocr_normalizer import normalize_numeric_text
            norm_text = normalize_numeric_text(c.text)
            has_decimal = "." in norm_text
            return (1 if has_decimal else 0, c.confidence)

        cand, val = max(numeric, key=_score)
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
        # Use a generous y_tol (1.5× row height) to catch bar-end values
        # that may sit slightly above or below the label baseline
        y_tol = max(15.0, (anchor.y2 - anchor.y1) * 1.5)
        row = _row_blocks(blocks, anchor, y_tol)
        for cand in row:
            if cand.x1 <= anchor.x2:
                continue
            val = parse_normalized_float(cand.text)
            # Filter for plausible absolute trunk mass (5-100kg/lb) to ignore scale % values (>100%)
            if val is not None and 5 <= val <= 100:
                conf = anchor.confidence * 0.4 + cand.confidence * 0.6
                if conf > best[1]:
                    best = (val, conf, cand.text)
    return best
