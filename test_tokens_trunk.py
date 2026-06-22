import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent / "smart_fit_backend"
sys.path.insert(0, str(BACKEND_DIR))

from scan_preprocess import load_scan_image
from template_loader import load_template
from template_extractor import TemplateExtractor

image_path = "test_inbody_versions/uploaded_570.jpg"
with open(image_path, "rb") as f:
    scan = load_scan_image(f.read())

extractor = TemplateExtractor()
template = load_template("InBody570")
img_h, img_w = scan.image.shape[:2]

blocks = extractor._section_blocks(scan.image, img_w, img_h, template, "segmental_lean")
print("Blocks near Trunk:")
for b in blocks:
    if 680 < b.cy < 780:
        print(f"y={b.y1:.3f}-{b.y2:.3f} x={b.x1:.3f}-{b.x2:.3f} text='{b.text}' conf={b.confidence:.2f}")
