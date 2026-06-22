from smart_fit_backend.easyocr_engine import EasyOcrEngine
from smart_fit_backend.scan_preprocess import load_scan_image
import json

def main():
    with open("test_inbody_versions/inbody570.png", "rb") as f:
        image_bytes = f.read()
        
    scan = load_scan_image(image_bytes)
    engine = EasyOcrEngine()
    
    blocks = engine.extract_blocks(scan.image)
    
    print("Found blocks containing 'Trunk':")
    for b in blocks:
        if "Trunk" in b.text or "trunk" in b.text.lower() or "run" in b.text.lower():
            print(f"Block: {repr(b.text)} at cx:{b.center_x}, cy:{b.center_y}")
            
    print("Found blocks with a number around 17.9:")
    for b in blocks:
        if "17.9" in b.text:
            print(f"Block: {repr(b.text)} at cx:{b.center_x}, cy:{b.center_y}")

if __name__ == "__main__":
    main()
