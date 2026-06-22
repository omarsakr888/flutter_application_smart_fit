import sys
from pathlib import Path
sys.path.insert(0, str(Path("smart_fit_backend")))
from section_extractor import SectionBlock, extract_label_value
from ocr_normalizer import parse_normalized_float

blocks = [
    SectionBlock("Besal Meatolc Rate", 0.30, 183.0, 189.0, 233.0, 197.0),
    SectionBlock("1154 kcal (1255 ~ 1451)", 0.64, 303.0, 189.0, 366.0, 197.0),
    SectionBlock("Rene cbe/2k34", 0.02, 183.0, 243.0, 241.0, 250.0),
    SectionBlock("1307", 0.66, 303.0, 241.0, 319.0, 249.0)
]

labels = ["Basal Metabolic Rate", "BMR", "Metabolic Rate", "Metabolc Rate"]
val, conf, raw = extract_label_value(blocks, labels, direction="right")
print(f"Extracted: {val}, {conf}, {raw}")

for cand in blocks:
    print(cand.text, "->", parse_normalized_float(cand.text))
