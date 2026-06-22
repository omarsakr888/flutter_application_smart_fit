import sys
from pathlib import Path
sys.path.insert(0, str(Path("smart_fit_backend")))
from section_extractor import SectionBlock, extract_label_value
from ocr_normalizer import parse_normalized_float

blocks = [
    SectionBlock("Total Body Water", 0.58, 287.0, 75.0, 379.0, 89.0),
    SectionBlock("Intracellular Water", 0.77, 69.0, 97.0, 163.0, 113.0),
    SectionBlock("39.9", 0.45, 215.0, 93.0, 251.0, 113.0),
    SectionBlock("64.2", 0.81, 311.0, 105.0, 347.0, 125.0)
]

val, conf, raw = extract_label_value(blocks, ["Total Body Water", "TBW"], direction="below")
print(f"Below extracted: {val}, {conf}, {raw}")

for b in blocks:
    if "Total" in b.text:
        cx = (b.x1 + b.x2) / 2
        w = b.x2 - b.x1
        xtol = max(10.0, w * 0.8)
        print(f"Anchor cx: {cx}, xtol: {xtol}")
    elif b.text == "39.9":
        cx = (b.x1 + b.x2) / 2
        print(f"39.9 cx: {cx}, diff: {abs(cx - 333.0)}")
    elif b.text == "64.2":
        cx = (b.x1 + b.x2) / 2
        print(f"64.2 cx: {cx}, diff: {abs(cx - 333.0)}")
