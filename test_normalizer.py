import sys
from pathlib import Path
sys.path.insert(0, str(Path("smart_fit_backend")))
from ocr_normalizer import normalize_numeric_text, parse_normalized_float

print("21.8 (10.3  ->", parse_normalized_float("21.8 (10.3"))
print("16.5)       ->", parse_normalized_float("16.5)"))
