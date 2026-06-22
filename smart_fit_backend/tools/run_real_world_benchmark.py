import json
from pathlib import Path

# Fix for PaddleX bug on Windows
import os
os.environ["PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT"] = "0"
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")

import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from template_extractor import TemplateExtractor
from scan_preprocess import load_scan_image

BENCHMARK_DIR = Path(__file__).resolve().parent.parent.parent / "benchmark_real_world"

def run_real_world_benchmark():
    extractor = TemplateExtractor()
    results = []

    for version_dir in ["120", "270", "570"]:
        dir_path = BENCHMARK_DIR / version_dir
        if not dir_path.exists():
            continue
            
        for img_path in dir_path.glob("*.jpg"):
            if img_path.name == "scan.jpg":
                gt_path = dir_path / "ground_truth.json"
                
                with open(img_path, "rb") as f:
                    scan = load_scan_image(f.read())
                
                start_time = os.times().elapsed if hasattr(os.times(), 'elapsed') else 0
                res = extractor.extract(scan.image)
                
                fields = res.get("canonical_fields", {})
                layout = res.get("layout", {})
                detected_version = layout.get("template", "").replace("InBody", "")
                
                is_version_correct = detected_version == version_dir
                
                expected_gt = {}
                if gt_path.exists():
                    with open(gt_path, "r", encoding="utf-8") as f:
                        expected_gt = json.load(f)
                        
                total_gt_fields = len(expected_gt)
                correct_fields = 0
                extracted_fields_count = 0
                total_fields_supported = 12
                
                confs = []
                for key, fdata in fields.items():
                    val = fdata.get("value")
                    if val is not None and not fdata.get("is_imputed", False):
                        extracted_fields_count += 1
                        confs.append(fdata.get("confidence", 0.0))
                        
                    if key in expected_gt:
                        expected_val = expected_gt[key]
                        if val is not None and abs(val - expected_val) / (expected_val if expected_val else 1) <= 0.03:
                            correct_fields += 1
                            
                coverage = extracted_fields_count / total_fields_supported * 100
                accuracy = (correct_fields / total_gt_fields * 100) if total_gt_fields > 0 else 0.0
                avg_conf = (sum(confs) / len(confs) * 100) if confs else 0.0
                
                report = {
                    "version": version_dir,
                    "accuracy": round(accuracy, 1),
                    "coverage": round(coverage, 1),
                    "avg_confidence": round(avg_conf, 1)
                }
                results.append(report)
                
                print(json.dumps(report, indent=2))
                
                with open(dir_path / "report.json", "w") as f:
                    json.dump(report, f, indent=2)

if __name__ == "__main__":
    run_real_world_benchmark()
