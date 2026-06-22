import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from smart_fit_backend.scan_preprocess import load_scan_image
from smart_fit_backend.easyocr_engine import EasyOcrEngine
from smart_fit_backend.template_extractor import TemplateExtractor
from smart_fit_backend.response_builder import ResponseBuilder

image_path = "test_inbody_versions/uploaded_570.jpg"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

engine = EasyOcrEngine()
blocks, full_text = engine.extract_text(scan.image)

from smart_fit_backend.document_analyser import DocumentAnalyser
layout = DocumentAnalyser().analyse(scan.image, blocks, full_text)

extractor = TemplateExtractor()
raw_fields = extractor.extract(scan.image)

builder = ResponseBuilder()
final_result = builder.build(raw_fields["fields"], layout, block_count=len(layout.raw_tokens))

print("Layout Units:", layout.units)
print("\n--- FINAL FIELDS ---")
for key, data in final_result["fields"].items():
    print(f"Field: {key:30} | Final Value: {data.get('value')} | Raw: {data.get('raw_text')} | Conf: {data.get('confidence')} | Valid: {data.get('validation_status')}")

