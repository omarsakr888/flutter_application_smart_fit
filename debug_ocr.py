import cv2
import json
from pathlib import Path
from easyocr_engine import EasyOcrEngine
from roi_utils import crop_roi, normalized_to_pixel, upscale_for_ocr

engine = EasyOcrEngine()
engine.load()

def test_roi(version, tmpl_file, scan_file):
    print(f"\n--- {version} ---")
    img = cv2.imread(scan_file)
    with open(tmpl_file) as f:
        tmpl = json.load(f)
    
    img_h, img_w = img.shape[:2]
    
    keys = ["age_roi", "height_roi", "weight_roi", "tbw_roi", "bfm_roi", "bmr_roi", "pbf_roi"]
    for k in keys:
        roi = tmpl.get(k, {}).get("roi")
        if not roi: continue
        
        pixel_roi = normalized_to_pixel(roi, img_w, img_h, pad_frac=0.10)
        crop = crop_roi(img, pixel_roi)
        crop = upscale_for_ocr(crop, min_height=60)
        
        # Test numeric_only=True and False
        txt1, conf1 = engine.extract_region_text(crop, numeric_only=True)
        txt2, conf2 = engine.extract_region_text(crop, numeric_only=False)
        
        print(f"{k:15}: num_only='{txt1}' (c={conf1:.2f}) | text_only='{txt2}' (c={conf2:.2f})")

test_roi("InBody120", "smart_fit_backend/templates/120_template.json", "test_inbody_versions/inbody120.png")
test_roi("InBody270", "smart_fit_backend/templates/270_template.json", "test_inbody_versions/inbody270.png")
test_roi("InBody570", "smart_fit_backend/templates/570_template.json", "test_inbody_versions/inbody570.png")
