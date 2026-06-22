import sys
from pathlib import Path
import json

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from scan_preprocess import load_scan_image
from document_analyser import DocumentAnalyser

image_path = "test_inbody_versions/uploaded_570.jpg"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

analyzer = DocumentAnalyser()
layout = analyzer.analyse(scan.image)
print("Detected units:", layout.units)
