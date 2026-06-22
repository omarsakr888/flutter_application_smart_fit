#!/usr/bin/env python3
"""
Precision diagnostic: capture exact bounding boxes for SMM and Trunk rows
on the imperial inbody570.png benchmark image.
Saves annotated crop images showing every OCR block.
"""
import os
os.environ["PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT"] = "0"
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")

import sys
from pathlib import Path
import cv2
import numpy as np

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from scan_preprocess import load_scan_image
from template_loader import load_template
from template_extractor import TemplateExtractor
from roi_utils import crop_roi, normalized_to_pixel
from section_extractor import SectionBlock, blocks_from_crop
from easyocr_engine import EasyOcrEngine
from roi_utils import upscale_for_ocr

OUT = Path("debug/smm_trunk_precision")
OUT.mkdir(parents=True, exist_ok=True)

image_path = "test_inbody_versions/inbody570.png"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

extractor = TemplateExtractor()
template = load_template("InBody570")
img_h, img_w = scan.image.shape[:2]
engine = EasyOcrEngine()

print(f"Image: {img_w}x{img_h}, units={template.get('units_default')}")

def annotate_blocks(crop, blocks, title, path):
    """Draw bounding boxes on crop image and save."""
    vis = crop.copy()
    if len(vis.shape) == 2:
        vis = cv2.cvtColor(vis, cv2.COLOR_GRAY2BGR)
    for b in blocks:
        x1, y1, x2, y2 = int(b.x1), int(b.y1), int(b.x2), int(b.y2)
        color = (0, 200, 0)  # green default
        # Highlight numerics in blue
        try:
            float(b.text.replace(",", ".").replace(" ", ""))
            color = (255, 100, 0)
        except ValueError:
            pass
        cv2.rectangle(vis, (x1, y1), (x2, y2), color, 1)
        cv2.putText(vis, b.text[:12], (x1, max(0, y1-2)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.3, color, 1)
    cv2.imwrite(str(path), vis)
    print(f"  Saved: {path}")

# ── Gather all blocks for each section, both preprocess modes ────────────────
for section_name in ["muscle_fat", "obesity"]:
    for pre in [False, True]:
        blocks = extractor._section_blocks(scan.image, img_w, img_h, template, section_name, preprocess=pre)
        label = f"{section_name}_pre{int(pre)}"
        
        # Get the actual crop for annotation
        sec_cfg = template["sections"].get(section_name, {})
        roi = sec_cfg.get("roi", {})
        if roi:
            from roi_utils import crop_roi, normalized_to_pixel
            rect = normalized_to_pixel(roi, img_w, img_h)
            crop = crop_roi(scan.image, rect)
        else:
            crop = scan.image

        annotate_blocks(crop, blocks, label, OUT / f"{label}.png")

        # Print blocks with SMM context
        smm_anchor = [b for b in blocks if "SMM" in b.text or "Skeletal" in b.text]
        if smm_anchor:
            anchor = smm_anchor[0]
            print(f"\n=== SMM row [{label}] ===")
            print(f"  ANCHOR: '{anchor.text}' y={anchor.y1:.0f}-{anchor.y2:.0f} x={anchor.x1:.0f}-{anchor.x2:.0f} conf={anchor.confidence:.2f}")
            # Show all blocks in same row (±15px of anchor cy)
            row = [b for b in blocks if abs(b.cy - anchor.cy) <= 20 and b is not anchor]
            row.sort(key=lambda b: b.x1)
            for b in row:
                print(f"  ROW: '{b.text}' y={b.y1:.0f}-{b.y2:.0f} x={b.x1:.0f}-{b.x2:.0f} conf={b.confidence:.2f} dist_x={b.x1-anchor.x2:.0f}")

# ── Segmental lean — Trunk analysis ──────────────────────────────────────────
print("\n" + "="*60)
print("TRUNK ANALYSIS — segmental_lean section")
print("="*60)
for pre in [False, True]:
    blocks = extractor._section_blocks(scan.image, img_w, img_h, template, "segmental_lean", preprocess=pre)
    label = f"segmental_lean_pre{int(pre)}"
    
    sec_cfg = template["sections"].get("segmental_lean", {})
    roi = sec_cfg.get("roi", {})
    if roi:
        from roi_utils import normalized_to_pixel, crop_roi
        rect = normalized_to_pixel(roi, img_w, img_h)
        crop = crop_roi(scan.image, rect)
        annotate_blocks(crop, blocks, label, OUT / f"{label}.png")

    trunk_blocks = [b for b in blocks if "Trunk" in b.text or "trunk" in b.text.lower()]
    if trunk_blocks:
        anchor = trunk_blocks[0]
        print(f"\n  TRUNK ANCHOR [{label}]: y={anchor.y1:.0f}-{anchor.y2:.0f} x={anchor.x1:.0f}-{anchor.x2:.0f}")
        row = [b for b in blocks if abs(b.cy - anchor.cy) <= 20 and b is not anchor]
        row.sort(key=lambda b: b.x1)
        print(f"  Row blocks (±20px cy):")
        for b in row:
            print(f"    '{b.text}' y={b.y1:.0f}-{b.y2:.0f} x={b.x1:.0f}-{b.x2:.0f} conf={b.confidence:.2f}")
        if not row:
            print("  (no blocks in row)")
    else:
        print(f"\n  [{label}] No Trunk anchor found in {len(blocks)} blocks")

# ── Wider scan — search full width for Trunk value ────────────────────────────
print("\n" + "="*60)
print("WIDE SEARCH: Looking for ~39.6 anywhere in image at Trunk y-position")
print("="*60)

# First find Trunk y position from narrow segmental_lean
blocks_narrow = extractor._section_blocks(scan.image, img_w, img_h, template, "segmental_lean", preprocess=True)
trunk_anchors = [b for b in blocks_narrow if "Trunk" in b.text]
if trunk_anchors:
    trunk_anchor = trunk_anchors[0]
    trunk_cy = trunk_anchor.cy
    print(f"Trunk anchor cy={trunk_cy:.0f} (in full image coords)")
    
    # Crop a wide strip at that y position (full width, ±25px)
    y_offset = int(template["sections"]["segmental_lean"]["roi"]["y"] * img_h)
    abs_cy = trunk_cy + y_offset
    y_top = max(0, int(abs_cy) - 25)
    y_bot = min(img_h, int(abs_cy) + 25)
    wide_strip = scan.image[y_top:y_bot, 0:img_w]
    cv2.imwrite(str(OUT / "trunk_wide_strip.png"), wide_strip)
    print(f"  Wide strip saved: y={y_top}-{y_bot} (full width)")
    
    # OCR the wide strip
    scaled = upscale_for_ocr(wide_strip, min_height=80)
    raw = engine.extract_blocks(scaled)
    sh, sw = scaled.shape[:2]
    sx = img_w / sw
    sy = (y_bot - y_top) / sh
    print(f"  Blocks in wide strip:")
    for b in raw:
        xs = [p[0]*sx for p in b.bbox]
        ys = [p[1]*sy for p in b.bbox]
        print(f"    '{b.text}' x={min(xs):.0f}-{max(xs):.0f} y={min(ys):.0f}-{max(ys):.0f} conf={b.confidence:.2f}")
else:
    print("No Trunk anchor found in narrow scan")

print(f"\nAll debug images saved to: {OUT.resolve()}")
