import sys
from pathlib import Path
import json

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from smart_fit_backend.scan_preprocess import load_scan_image
from smart_fit_backend.easyocr_engine import EasyOcrEngine
from smart_fit_backend.document_analyser import DocumentAnalyser
from smart_fit_backend.template_extractor import TemplateExtractor
from smart_fit_backend.response_builder import ResponseBuilder
from smart_fit_backend.ocr_engine import OcrEngine

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

print("Layout Units:", layout.units)
print("======================================================")
for key, truth in gt.items():
    raw_fdata = raw_fields["fields"].get(key, {})
    final_fdata = final_result["fields"].get(key, {})
    
    raw_val = raw_fdata.get("raw_text", "")
    norm_val = raw_fdata.get("value", "None")
    final_val = final_fdata.get("value", "None")
    conf = final_fdata.get("confidence", 0.0)
    
    status = "FAIL"
    if final_val is not None and str(final_val) != "None":
        if abs(final_val - truth) <= 0.05 * truth:
            status = "PASS"
            
    print(f"[{status}] {key}")
    print(f"Ground Truth: {truth}")
    print(f"Raw OCR: {raw_val}")
    print(f"Normalized: {norm_val}")
    print(f"Final: {final_val}")
    print(f"Confidence: {conf}")
    print("-------------------------")
