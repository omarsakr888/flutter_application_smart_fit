import sys
from pathlib import Path
import json

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from smart_fit_backend.scan_preprocess import load_scan_image
from smart_fit_backend.easyocr_engine import EasyOcrEngine
from smart_fit_backend.ocr_engine import OcrEngine
from smart_fit_backend.document_analyser import DocumentAnalyser
from smart_fit_backend.template_extractor import TemplateExtractor
from smart_fit_backend.response_builder import ResponseBuilder

image_path = "test_inbody_versions/uploaded_570.jpg"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

engine = EasyOcrEngine()
raw_blocks = engine.extract_blocks(scan.image)
tokens, full_text = OcrEngine.from_blocks(raw_blocks, scan.width, scan.height)

analyzer = DocumentAnalyser()
layout = analyzer.analyse(tokens, full_text)

extractor = TemplateExtractor()
raw_fields = extractor.extract(scan.image)

builder = ResponseBuilder()
final_result = builder.build(raw_fields["fields"], layout, block_count=len(layout.raw_tokens))

print(f"Detected Layout: {layout.model}")
print(f"Detected Units: {layout.units}")

print("\n--- FINAL EXTRACTED FIELDS ---")
for k, v in final_result["fields"].items():
    print(f"{k}: {v}")

