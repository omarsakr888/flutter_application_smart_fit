#!/usr/bin/env python3
"""Trace exactly which code path selects SMM=40 and Trunk=8 in the benchmark 570."""
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
from section_extractor import (
    extract_bar_end_value, extract_label_value, extract_trunk_from_segmental, _row_blocks
)
from ocr_normalizer import parse_normalized_float

image_path_570 = "test_inbody_versions/inbody570.png"
image_path_270 = "test_inbody_versions/inbody270.png"

with open(image_path_570, "rb") as f:
    scan_570 = load_scan_image(f.read())
with open(image_path_270, "rb") as f:
    scan_270 = load_scan_image(f.read())

extractor = TemplateExtractor()
tpl_570 = load_template("InBody570")
tpl_270 = load_template("InBody270")

print("=== 270 SMM TRACE ===")
img_h, img_w = scan_270.image.shape[:2]
for section in ("muscle_fat", "obesity"):
    for pre in [False, True]:
        blocks = extractor._section_blocks(scan_270.image, img_w, img_h, tpl_270, section, preprocess=pre)
        val, conf, raw = extract_label_value(blocks, ["SMM", "Skeletal Muscle Mass", "SHM"], direction="right")
        print(f"  [{section} pre={pre}] label_val -> {val} (conf={conf:.2f}, raw='{raw}')")
        val2, conf2, raw2 = extract_bar_end_value(blocks, ["SMM", "Skeletal Muscle Mass", "SHM"])
        print(f"  [{section} pre={pre}] bar_end  -> {val2} (conf={conf2:.2f}, raw='{raw2}')")

import cv2
import easyocr
import numpy as np

img = cv2.imread("trunk_crop_test.jpg", cv2.IMREAD_GRAYSCALE)
reader = easyocr.Reader(['en'], gpu=False)

methods = {}
methods["raw"] = img
methods["thresh_binary"] = cv2.threshold(img, 127, 255, cv2.THRESH_BINARY)[1]
methods["thresh_otsu"] = cv2.threshold(img, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)[1]
methods["adaptive_mean"] = cv2.adaptiveThreshold(img, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 11, 2)
methods["adaptive_gaussian"] = cv2.adaptiveThreshold(img, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)

# increase contrast
clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
cl1 = clahe.apply(img)
methods["clahe"] = cl1
methods["clahe_otsu"] = cv2.threshold(cl1, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)[1]

# upscale and blur then otsu
upscaled = cv2.resize(img, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
blur = cv2.GaussianBlur(upscaled, (5,5), 0)
methods["upscale_blur_otsu"] = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY | cv2.THRESH_OTSU)[1]

print("=== PREPROCESSING OCR TEST ===")
for name, p_img in methods.items():
    res = reader.readtext(p_img)
    texts = [r[1] for r in res]
    print(f"{name:20s}: {texts}")



