import sys
import cv2
import easyocr

def dump_blocks(image_path):
    reader = easyocr.Reader(['en'], gpu=False)
    img = cv2.imread(image_path)
    results = reader.readtext(img)
    
    for bbox, text, conf in results:
        xs = [p[0] for p in bbox]
        ys = [p[1] for p in bbox]
        cx = sum(xs)/4
        cy = sum(ys)/4
        print(f"[{text}] (conf: {conf:.2f}) cx:{cx:.1f} cy:{cy:.1f} bbox: {bbox}")

if __name__ == "__main__":
    dump_blocks("test_inbody_versions/inbody570.png")
