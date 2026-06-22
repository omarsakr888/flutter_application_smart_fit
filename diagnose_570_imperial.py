#!/usr/bin/env python3
"""Diagnose why inbody570.png benchmark image triggers imperial detection."""
import os
os.environ["PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT"] = "0"
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")

import sys
import re
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from scan_preprocess import load_scan_image
from easyocr_engine import EasyOcrEngine

image_path = "test_inbody_versions/inbody570.png"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

engine = EasyOcrEngine()
img_h, img_w = scan.image.shape[:2]
raw_blocks = engine.extract_blocks(scan.image)

full_text = " ".join(b.text for b in raw_blocks)
print("=== Full OCR text ===")
print(full_text[:2000])

print("\n=== Checking imperial triggers ===")

# Check each rule
if re.search(r"\(\s*lbs?\s*\)", full_text, re.IGNORECASE):
    print("TRIGGER: parenthesized (lbs)")
    
if re.search(r"\(\s*ft\s*/\s*in\s*\)", full_text, re.IGNORECASE):
    print("TRIGGER: parenthesized (ft/in)")

if re.search(r"\(\s*inches\s*\)", full_text, re.IGNORECASE):
    print("TRIGGER: parenthesized (inches)")
    
if re.search(r"Height\s*:?\s*\d+\s*ft", full_text, re.IGNORECASE):
    print("TRIGGER: Height ... ft")

if re.search(r"\b\d{1,2}\s*ft\s*\d{1,2}\s*in\b", full_text, re.IGNORECASE):
    print("TRIGGER: X ft Y in pattern")

if re.search(r"\b\d{1,2}\s*'\s*\d{1,2}\s*\"", full_text):
    print("TRIGGER: X' Y\" pattern")

m = re.search(r"\b\d+(\.\d+)?\s*lbs?\b", full_text, re.IGNORECASE)
if m:
    print(f"TRIGGER: numeric lbs pattern -> '{m.group()}'")

print("\n=== Checking top 25% tokens for lb/lbs/ft/ft/in ===")
for b in raw_blocks:
    # approximate y normalization
    y_norm = (b.bbox[0][1] + b.bbox[2][1]) / 2 / img_h
    if y_norm < 0.25:
        low = b.text.lower().strip()
        if low in {"lb", "lbs", "ft", "ft/in"}:
            print(f"  TRIGGER in header: '{b.text}' at y_norm={y_norm:.3f}")
        elif any(t in low for t in ["lb", "lbs", "ft", "in"]):
            print(f"  Near-trigger in header: '{b.text}' at y_norm={y_norm:.3f}")

print("\n=== Weight-area tokens (y_norm 0.05-0.20) ===")
for b in raw_blocks:
    y_norm = (b.bbox[0][1] + b.bbox[2][1]) / 2 / img_h
    if 0.05 <= y_norm <= 0.20:
        print(f"  y={y_norm:.3f} '{b.text}' conf={b.confidence:.2f}")
