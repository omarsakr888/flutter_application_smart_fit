import cv2
import json
import os
from pathlib import Path
from roi_utils import crop_roi, normalized_to_pixel, upscale_for_ocr

os.makedirs("debug_crops", exist_ok=True)

def test_roi(version, tmpl_file, scan_file):
    img = cv2.imread(scan_file)
    with open(tmpl_file) as f:
        tmpl = json.load(f)
    
    img_h, img_w = img.shape[:2]
    print(f"{version}: {img_w}x{img_h}")
    
    keys = ["age_roi", "height_roi", "weight_roi", "tbw_roi", "bfm_roi", "bmr_roi", "pbf_roi"]
    for k in keys:
        roi = tmpl.get(k, {}).get("roi")
        if not roi: continue
        
        pixel_roi = normalized_to_pixel(roi, img_w, img_h, pad_frac=0.10)
        crop = crop_roi(img, pixel_roi)
        crop_up = upscale_for_ocr(crop, min_height=60)
        
        cv2.imwrite(f"debug_crops/{version}_{k}.png", crop)
        cv2.imwrite(f"debug_crops/{version}_{k}_up.png", crop_up)
        
        print(f"  {k:15}: y={pixel_roi.y}:{pixel_roi.y+pixel_roi.h}, x={pixel_roi.x}:{pixel_roi.x+pixel_roi.w}")

test_roi("InBody120", "smart_fit_backend/templates/120_template.json", "test_inbody_versions/inbody120.png")
