import sys
from pathlib import Path
import cv2
import json

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from scan_preprocess import load_scan_image
from easyocr_engine import EasyOcrEngine
from template_extractor import TemplateExtractor

image_path = "test_inbody_versions/uploaded_570.jpg"

with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())
preprocessed = scan.image

engine = EasyOcrEngine()
blocks = engine.extract_blocks(preprocessed)

print(f"\n--- ALL OCR BLOCKS ({len(blocks)} blocks) ---")
for i, b in enumerate(blocks):
    print(f"Block {i}: TEXT='{b.text}' CONF={b.confidence:.2f} BOX={b.bbox}")

extractor = TemplateExtractor()
template_path = BACKEND_DIR / "templates" / "570_template.json"
with open(template_path) as f:
    template = json.load(f)

h, w = preprocessed.shape[:2]
print(f"\n--- SECTION ROIs (Image w={w}, h={h}) ---")
sections = template.get("sections", {})
for sec_name, sec_data in sections.items():
    roi = sec_data.get("roi")
    if roi:
        rx = int(roi["x"] * w)
        ry = int(roi["y"] * h)
        rw = int(roi["w"] * w)
        rh = int(roi["h"] * h)
        print(f"Section '{sec_name}': NORMALIZED={roi} PIXELS=(x={rx}, y={ry}, w={rw}, h={rh})")

result = extractor.extract(scan.image)

print("\n--- FINAL EXTRACTED VALUES ---")
for field_key, field_data in result.get("fields", {}).items():
    print(f"Field: {field_key:30} | Value: {field_data.get('value')} | Conf: {field_data.get('confidence', 0):.2f}")

print("\n--- FAILURE MATRIX ---")
gt = {
    "Age": 51.0,
    "Gender": 0.0,
    "Height": 156.9,
    "Weight": 59.1,
    "SMM_(Skeletal_Muscle_Mass)": 18.8,
    "BFM_(Body_Fat_Mass)": 23.0,
    "BMI_(Body_Mass_Index)": 24.0,
    "PBF_(Percent_Body_Fat)": 38.9,
    "BMR_(Basal_Metabolic_Rate)": 1149.0,
    "TBW_(Total_Body_Water)": 26.6,
    "FFM_of_Trunk": 17.0,
    "ECW/TBW": 0.397
}

for key, truth in gt.items():
    field = result.get("fields", {}).get(key)
    if not field:
        print(f"MISSING FIELD: {key}")
        continue
    
    val = field.get("value")
    if val is None:
        print(f"[FAIL] {key}: expected {truth}, got None")
    else:
        if abs(val - truth) > 0.05 * truth:
            print(f"[FAIL] {key}: expected {truth}, got {val}")
        else:
            print(f"[PASS] {key}: expected {truth}, got {val}")
