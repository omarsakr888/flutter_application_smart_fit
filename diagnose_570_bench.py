#!/usr/bin/env python3
"""Diagnose remaining InBody570 benchmark failures: SMM, BFM, Trunk."""
import os
os.environ["PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT"] = "0"
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")

import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from scan_preprocess import load_scan_image
from template_loader import load_template
from template_extractor import TemplateExtractor

image_path = "test_inbody_versions/inbody570.png"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

extractor = TemplateExtractor()
template = load_template("InBody570")
img_h, img_w = scan.image.shape[:2]

print(f"Image: {img_w}x{img_h}")
print(f"Units default: {template.get('units_default')}")
print()

for section_name in ["muscle_fat", "obesity", "segmental_lean"]:
    for pre in [False, True]:
        label = f"{section_name} (pre={pre})"
        blocks = extractor._section_blocks(scan.image, img_w, img_h, template, section_name, preprocess=pre)
        print(f"=== {label} ===")
        for b in blocks:
            print(f"  y={b.y1:.0f}-{b.y2:.0f} x={b.x1:.0f}-{b.x2:.0f} '{b.text}' conf={b.confidence:.2f}")
        print()
