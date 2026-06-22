import sys
from pathlib import Path
import json

BACKEND_DIR = Path("smart_fit_backend")
sys.path.insert(0, str(BACKEND_DIR))

from scan_preprocess import load_scan_image
from template_extractor import TemplateExtractor

extractor = TemplateExtractor()
extractor._engine.load()

def analyze_scan(img_name, tmpl_name):
    print(f"\n======================================")
    print(f"  {img_name}")
    print(f"======================================")
    
    img_path = Path("test_inbody_versions") / img_name
    scan = load_scan_image(img_path.read_bytes())
    
    with open(BACKEND_DIR / "templates" / tmpl_name) as f:
        tmpl = json.load(f)
        
    sections = tmpl.get("sections", {}).keys()
    for sec_name in sections:
        extractor._section_cache.clear()
        blocks = extractor._section_blocks(scan.image, scan.width, scan.height, tmpl, sec_name)
        
        print(f"\n--- Section: {sec_name} ---")
        for b in blocks:
            print(f"[{b.text}] (conf: {b.confidence:.2f}) x1:{b.x1:.1f} y1:{b.y1:.1f} cx:{b.cx:.1f} cy:{b.cy:.1f}")

analyze_scan("inbody120.png", "120_template.json")
analyze_scan("inbody270.png", "270_template.json")
analyze_scan("inbody570.png", "570_template.json")
