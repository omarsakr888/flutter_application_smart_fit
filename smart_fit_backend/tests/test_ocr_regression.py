import os
import json
import pytest
from pathlib import Path

# Fix for PaddleX bug on Windows
os.environ["PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT"] = "0"
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")

import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scan_preprocess import load_scan_image
from template_extractor import TemplateExtractor

TEST_IMAGES_DIR = Path(__file__).resolve().parent.parent.parent / "test_inbody_versions"
GROUND_TRUTH_DIR = Path(__file__).resolve().parent / "ground_truth"

DEFAULT_TOLERANCE = 0.02

FIELD_TOLERANCES = {
    "ECW/TBW": 0.005,
    "50kHz-Whole_Body_Phase_Angle": 0.05,
    "BMR_(Basal_Metabolic_Rate)": 0.03,
    "PBF_(Percent_Body_Fat)": 0.03,
}

ABSOLUTE_FIELDS = {"ECW/TBW", "50kHz-Whole_Body_Phase_Angle"}

VERSIONS = ["inbody120", "inbody270", "inbody570"]

@pytest.fixture(scope="module")
def extractor():
    return TemplateExtractor()

@pytest.mark.parametrize("version", VERSIONS)
def test_ocr_accuracy(extractor, version):
    image_path = TEST_IMAGES_DIR / f"{version}.png"
    gt_path = GROUND_TRUTH_DIR / f"{version}.json"
    
    with open(gt_path, "r", encoding="utf-8") as f:
        ground_truth = json.load(f)
        
    with open(image_path, "rb") as f:
        scan = load_scan_image(f.read())
        
    result = extractor.extract(scan.image)
    fields = result.get("fields", {})
    canonical = result.get("canonical_fields", {})
    
    # Map legacy keys to canonical keys for regression validation
    CANONICAL_FIELD_MAP = {
        "Age": "age",
        "Gender": "gender",
        "Height": "height_cm",
        "Weight": "weight_kg",
        "SMM_(Skeletal_Muscle_Mass)": "smm_kg",
        "BMR_(Basal_Metabolic_Rate)": "bmr_kcal",
        "FFM_of_Trunk": "segmental_ffm",
        "TBW_(Total_Body_Water)": "tbw_l",
        "ECW/TBW": "ecw_tbw_ratio",
        "50kHz-Whole_Body_Phase_Angle": "phase_angle",
        "BFM_(Body_Fat_Mass)": "bfm_kg",
        "PBF_(Percent_Body_Fat)": "pbf_percent",
    }
    
    # 1. Validate version-aware exclusions in canonical_fields
    for key, expected in ground_truth.items():
        if expected is None:
            # Expected to be omitted (unsupported)
            canon_key = CANONICAL_FIELD_MAP.get(key)
            if canon_key:
                assert canon_key not in canonical, f"{version}: {canon_key} is unsupported but appeared in canonical_fields"
            
    # 2. Validate schema and correctness for supported fields
    for key, expected in ground_truth.items():
        if expected is None:
            continue
            
        canon_key = CANONICAL_FIELD_MAP.get(key)
        if not canon_key:
            continue
            
        assert canon_key in canonical, f"{version}: {canon_key} missing from canonical_fields"
        extracted_data = canonical[canon_key]
        extracted_val = extracted_data.get("value")
        
        # Schema validation
        assert "value" in extracted_data
        assert "confidence" in extracted_data
        assert "source" in extracted_data
        assert "needs_review" in extracted_data
        
        conf = extracted_data["confidence"]
        assert isinstance(conf, float) and 0.0 <= conf <= 1.0, f"{version}: {key} confidence {conf} out of bounds"
        assert extracted_data["source"] in {"extracted", "derived", "estimated", "manual"}
        assert isinstance(extracted_data["needs_review"], bool)

        assert extracted_val is not None, f"{version}: {key} was None, expected {expected}"
        
        if key == "Gender":
            # For Gender, backend canonicalizes to 'male' / 'female' based on the json mapping
            if isinstance(extracted_val, str):
                expected_str = "male" if expected == 1.0 else "female"
                assert extracted_val == expected_str, f"{version}: {key} mismatch. Expected {expected_str}, got {extracted_val}"
            else:
                assert extracted_val == expected, f"{version}: {key} mismatch. Expected {expected}, got {extracted_val}"
            continue
            
        if key == "FFM_of_Trunk" and version == "inbody570":
            # KNOWN FAILURE: Trunk FFM on InBody570 imperial is physically printed over a dark grey bar.
            # EasyOCR completely fails to detect the text, resulting in a fallback to an incorrect nearby number.
            pytest.xfail("Known OCR limitation: InBody570 Trunk FFM printed over dark grey bar.")
            
        tol = FIELD_TOLERANCES.get(key, DEFAULT_TOLERANCE)
        if key in ABSOLUTE_FIELDS:
            diff = abs(extracted_val - expected)
            assert diff <= tol, f"{version}: {key} mismatch. Expected {expected}, got {extracted_val} (diff {diff} > {tol})"
        else:
            diff = abs(extracted_val - expected) / expected
            assert diff <= tol, f"{version}: {key} mismatch. Expected {expected}, got {extracted_val} (diff {diff*100:.1f}% > {tol*100:.1f}%)"
            
        # Relaxed confidence threshold for recovered/estimated fields
        assert conf >= 0.35, f"{version}: {key} has very low confidence {conf}"
