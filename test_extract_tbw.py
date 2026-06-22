import sys
from pathlib import Path
sys.path.insert(0, str(Path("smart_fit_backend")))
from section_extractor import SectionBlock, extract_label_value

blocks = [
    SectionBlock("Total Body Water", 0.58, 287.0, 75.0, 333.0, 82.0),
    SectionBlock("Intracellular Water", 0.77, 69.0, 97.0, 116.0, 105.0),
    SectionBlock("39.9", 0.45, 215.0, 93.0, 233.0, 103.0),
    SectionBlock("64.2", 0.81, 311.0, 105.0, 329.0, 115.0)
]

val, conf, raw = extract_label_value(blocks, ["Total Body Water", "TBW"], direction="below")
print(f"Below extracted: {val}, {conf}, {raw}")
