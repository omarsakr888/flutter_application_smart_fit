import sys
from pathlib import Path
sys.path.insert(0, str(Path("smart_fit_backend")))
from section_extractor import _match_label

blocks = [
    "Sum of Ine above",
    "Weight",
    "59.1",
    "(43.,9",
    "59.5)",
    "Muscle-Fat Analysis",
    "Under",
    "Normol",
    "Over",
    "105",
    "Ma",
    "13",
    "412",
    "JE]]",
    "a",
    "130",
    "3",
    "Weight",
    "59",
    "BM",
    "J03",
    "19",
    "14",
    "F0",
    "150",
    "I0",
    "SHM",
    "0",
    "19.6",
    "Ton",
    "1",
    "20",
    "3",
    "40",
    "40",
    "0",
    "Body Fat Wass 0 3",
    "22.8"
]

syns = ["SMM", "Skeletal Muscle Mass", "SHM"]

for b in blocks:
    if _match_label(b, syns):
        print(f"Matched: {b}")
