import re

def norm(text: str) -> str:
    cleaned = text.strip()
    if "," in cleaned and "." not in cleaned:
        cleaned = cleaned.replace(",", ".")
    else:
        cleaned = cleaned.replace(",", "")
    cleaned = re.sub(r"\s*\.\s*", ".", cleaned)
    match = re.search(r"-?\d+(?:\.\d+)?", cleaned)
    return match.group(0) if match else ""

tests = [
    "21.8 (10.3",
    "16.5)",
    "(43.9",
    "59 . 1",
    "1,234.5",
    "19,6",
    "[-]"
]
for t in tests:
    print(f"{t:15} -> {norm(t)}")
