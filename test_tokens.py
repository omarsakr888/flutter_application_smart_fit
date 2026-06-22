import sys
from pathlib import Path
import json

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from smart_fit_backend.scan_preprocess import load_scan_image
from smart_fit_backend.easyocr_engine import EasyOcrEngine
from smart_fit_backend.ocr_engine import OcrEngine

image_path = "test_inbody_versions/uploaded_570.jpg"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

engine = EasyOcrEngine()
raw_blocks = engine.extract_blocks(scan.image)
tokens, full_text = OcrEngine.from_blocks(raw_blocks, scan.width, scan.height)

for tok in tokens:
    if "lb" in tok.text.lower() or "in" in tok.text.lower() or "ft" in tok.text.lower():
        print(f"y={tok.y:.3f} text='{tok.text}'")

