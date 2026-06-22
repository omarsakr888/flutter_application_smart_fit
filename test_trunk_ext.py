from smart_fit_backend.template_extractor import TemplateExtractor
from smart_fit_backend.scan_preprocess import load_scan_image
import cv2
import json

def main():
    extractor = TemplateExtractor()
    with open("smart_fit_backend/templates/120_template.json", "r") as f:
        template = json.load(f)
        
    with open("test_inbody_versions/inbody120.png", "rb") as f:
        image_bytes = f.read()
    scan = load_scan_image(image_bytes)
    res = extractor.extract(scan.image)
    print("Extracted Trunk:", res["fields"]["FFM_of_Trunk"])

if __name__ == "__main__":
    main()
