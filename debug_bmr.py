import sys
from pathlib import Path
import cv2
BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from easyocr_engine import EasyOcrEngine

engine = EasyOcrEngine()
image570 = cv2.imread("test_inbody_versions/inbody570.png")
blocks570 = engine.extract_blocks(image570)
for b in blocks570:
    if 600 < b.bbox[0][1] < 650 and b.bbox[0][0] > 100:
        print(f"570 TEXT: {b.text}, BOX: {b.bbox}")
