import sys
from pathlib import Path
import cv2

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from test_ocr_accuracy import run_ocr_on_image
from template_extractor import TemplateExtractor

extractor = TemplateExtractor()
result = run_ocr_on_image(extractor, Path("test_inbody_versions/inbody120.png"), "InBody120")

print("BMR from extractor:", next((f for f in result.fields if f.key == "BMR_(Basal_Metabolic_Rate)"), None))
