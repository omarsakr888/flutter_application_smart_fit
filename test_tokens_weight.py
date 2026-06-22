import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from smart_fit_backend.scan_preprocess import load_scan_image
from smart_fit_backend.easyocr_engine import EasyOcrEngine
from smart_fit_backend.ocr_engine import OcrEngine
from smart_fit_backend.document_analyser import DocumentAnalyser
from smart_fit_backend.template_extractor import TemplateExtractor

image_path = "test_inbody_versions/uploaded_570.jpg"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

engine = EasyOcrEngine()
raw_blocks = engine.extract_blocks(scan.image)
tokens, full_text = OcrEngine.from_blocks(raw_blocks, scan.width, scan.height)

extractor = TemplateExtractor()
raw_fields = extractor.extract(scan.image)

print("Raw extracted weight:", raw_fields["fields"].get("Weight"))

for tok in tokens:
    if "26.7" in tok.text or "12.0" in tok.text or "10.4" in tok.text:
        print(f"y={tok.y:.3f} text='{tok.text}'")
