import sys
from pathlib import Path
import json

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

import template_extractor
from template_extractor import TemplateExtractor
from scan_preprocess import load_scan_image
import easyocr_engine

orig_extract_label_value = template_extractor.extract_label_value
orig_extract_bar_end_value = template_extractor.extract_bar_end_value

def debug_extract_label_value(blocks, labels, value_type="float", direction="right", validator=None):
    val, conf, raw = orig_extract_label_value(blocks, labels, value_type, direction)
    return val, conf, raw

def debug_extract_bar_end_value(blocks, labels, validator=None):
    print(f"  [extract_bar_end_value] Searching for bar end for labels: {labels}")
    val, conf, raw = orig_extract_bar_end_value(blocks, labels, validator)
    print(f"  [extract_bar_end_value] -> Result: {val} (raw: '{raw}', conf: {conf})")
    return val, conf, raw

template_extractor.extract_bar_end_value = debug_extract_bar_end_value

image_path = "test_inbody_versions/uploaded_570.jpg"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

extractor = TemplateExtractor()
print("Starting extraction with patched debug...")
result = extractor.extract(scan.image)

print("\n--- EXTRACTED FIELDS ---")
for k, v in result.get("fields", {}).items():
    print(f"{k}: {v}")

