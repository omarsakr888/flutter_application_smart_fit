#!/usr/bin/env python3
"""
bmr_roi_preprocess_test.py
Save the BMR ROI crop and test multiple preprocessing strategies,
comparing OCR output before and after each strategy.
Selects the highest-confidence result for BMR extraction.
Does NOT hardcode numeric corrections.
"""
import os
os.environ["PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT"] = "0"
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")

import sys
from pathlib import Path
import numpy as np
import cv2

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from scan_preprocess import load_scan_image
from template_loader import load_template
from template_extractor import TemplateExtractor
from roi_utils import crop_roi, normalized_to_pixel
from section_extractor import blocks_from_crop
from easyocr_engine import EasyOcrEngine
from ocr_normalizer import parse_normalized_float, normalize_numeric_text

OUT_DIR = Path("debug/bmr_roi_test")
OUT_DIR.mkdir(parents=True, exist_ok=True)

image_path = "test_inbody_versions/uploaded_570.jpg"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

template = load_template("InBody570")
img_h, img_w = scan.image.shape[:2]

engine = EasyOcrEngine()

bmr_section = template["sections"].get("bmr_standalone")
if bmr_section is None:
    print("ERROR: bmr_standalone section not found in template")
    sys.exit(1)

roi = bmr_section.get("roi")
if roi is None:
    print("ERROR: No ROI for bmr_standalone")
    sys.exit(1)

rect = normalized_to_pixel(roi, img_w, img_h)
crop = crop_roi(scan.image, rect)

if crop.size == 0:
    print("ERROR: BMR crop is empty")
    sys.exit(1)

print(f"BMR crop size: {crop.shape[1]}x{crop.shape[0]} pixels")
cv2.imwrite(str(OUT_DIR / "bmr_raw.png"), crop)

def extract_bmr_candidates(img, label="raw"):
    """Extract all blocks and find BMR label + nearest numeric."""
    from section_extractor import SectionBlock, _match_label, _row_blocks
    from roi_utils import upscale_for_ocr
    
    scaled = upscale_for_ocr(img, min_height=80)
    raw_blocks = engine.extract_blocks(scaled)
    sh, sw = scaled.shape[:2]
    ch, cw = img.shape[:2]
    sx, sy = cw / sw, ch / sh

    blocks = []
    for b in raw_blocks:
        xs = [p[0] * sx for p in b.bbox]
        ys = [p[1] * sy for p in b.bbox]
        blocks.append(SectionBlock(
            text=b.text.strip(),
            confidence=b.confidence,
            x1=min(xs), y1=min(ys),
            x2=max(xs), y2=max(ys)
        ))

    print(f"\n--- [{label}] All blocks ---")
    for b in blocks:
        print(f"  y={b.y1:.0f}-{b.y2:.0f} x={b.x1:.0f}-{b.x2:.0f} '{b.text}' conf={b.confidence:.2f}")

    # Find BMR anchor
    bmr_anchors = [b for b in blocks if _match_label(b.text, ["Basal Metabolic Rate", "BMR", "Metabolic Rate"])]
    if not bmr_anchors:
        print(f"  [{label}] No BMR anchor found")
        return None, 0.0, ""

    best_val, best_conf, best_raw = None, 0.0, ""
    for anchor in bmr_anchors:
        print(f"  [{label}] BMR anchor: '{anchor.text}' conf={anchor.confidence:.2f} cy={anchor.cy:.0f}")
        # Search right
        row = _row_blocks(blocks, anchor, max(12.0, (anchor.y2 - anchor.y1) * 1.2))
        for cand in row:
            if cand.x1 <= anchor.x2:
                continue
            norm = normalize_numeric_text(cand.text)
            v = parse_normalized_float(norm)
            print(f"    right cand: '{cand.text}' -> norm='{norm}' val={v}")
            if v is not None and 800 <= v <= 3500:
                c = anchor.confidence * 0.4 + cand.confidence * 0.6
                if c > best_conf:
                    best_val, best_conf, best_raw = v, c, cand.text

        # Search below (within 30px)
        below = [b for b in blocks if b.y1 > anchor.y2 and b.y1 - anchor.y2 < 35]
        for cand in sorted(below, key=lambda b: b.y1):
            norm = normalize_numeric_text(cand.text)
            v = parse_normalized_float(norm)
            print(f"    below cand: '{cand.text}' -> norm='{norm}' val={v}")
            if v is not None and 800 <= v <= 3500:
                c = anchor.confidence * 0.4 + cand.confidence * 0.6
                if c > best_conf:
                    best_val, best_conf, best_raw = v, c, cand.text

    print(f"  [{label}] RESULT: val={best_val} conf={best_conf:.3f} raw='{best_raw}'")
    return best_val, best_conf, best_raw


# ── Strategy 0: Raw (no preprocessing) ────────────────────────────────────────
val0, conf0, raw0 = extract_bmr_candidates(crop, "raw")

# ── Strategy 1: CLAHE ─────────────────────────────────────────────────────────
lab = cv2.cvtColor(crop, cv2.COLOR_BGR2LAB)
l, a, b_ch = cv2.split(lab)
clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
cl = clahe.apply(l)
crop_clahe = cv2.cvtColor(cv2.merge((cl, a, b_ch)), cv2.COLOR_LAB2BGR)
cv2.imwrite(str(OUT_DIR / "bmr_clahe.png"), crop_clahe)
val1, conf1, raw1 = extract_bmr_candidates(crop_clahe, "CLAHE")

# ── Strategy 2: Grayscale + Otsu threshold ────────────────────────────────────
gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
_, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
crop_thresh = cv2.cvtColor(thresh, cv2.COLOR_GRAY2BGR)
cv2.imwrite(str(OUT_DIR / "bmr_thresh.png"), crop_thresh)
val2, conf2, raw2 = extract_bmr_candidates(crop_thresh, "Otsu-thresh")

# ── Strategy 3: Sharpening ────────────────────────────────────────────────────
kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
crop_sharp = cv2.filter2D(crop, -1, kernel)
cv2.imwrite(str(OUT_DIR / "bmr_sharp.png"), crop_sharp)
val3, conf3, raw3 = extract_bmr_candidates(crop_sharp, "sharpen")

# ── Strategy 4: Dilation ──────────────────────────────────────────────────────
gray4 = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
_, bin4 = cv2.threshold(gray4, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
kernel4 = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
dilated = cv2.dilate(bin4, kernel4, iterations=1)
crop_dil = cv2.cvtColor(dilated, cv2.COLOR_GRAY2BGR)
cv2.imwrite(str(OUT_DIR / "bmr_dil.png"), crop_dil)
val4, conf4, raw4 = extract_bmr_candidates(crop_dil, "dilate")

# ── Summary ───────────────────────────────────────────────────────────────────
print("\n" + "="*60)
print("STRATEGY COMPARISON SUMMARY")
print("="*60)
strategies = [
    ("raw",          val0, conf0, raw0),
    ("CLAHE",        val1, conf1, raw1),
    ("Otsu-thresh",  val2, conf2, raw2),
    ("sharpen",      val3, conf3, raw3),
    ("dilate",       val4, conf4, raw4),
]
best = max(strategies, key=lambda x: x[2] if x[1] is not None else -1)
for name, v, c, r in strategies:
    marker = " <-- BEST" if (name, v, c, r) == best else ""
    print(f"  {name:<14} val={str(v):<8} conf={c:.3f}  raw='{r}'{marker}")

print(f"\nROI crops saved to: {OUT_DIR.resolve()}")
