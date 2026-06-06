"""fix_regex.py - Patches the broken regex on line 599 of field_extractor.py"""
path = "smart_fit_backend/field_extractor.py"
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    # Find the offending line with the broken character class
    if "m2 = re.search" in line and "Pattern 2" not in line and "field_extractor" not in line:
        # Replace with a safe version using no character class
        lines[i] = "        m2 = re.search(r\"(\\d{1,2})'\\s*(\\d{1,2}\\.?\\d*)(?:\\\"|'')?\"" + ", text)\n"
        print(f"Patched line {i + 1}")
        break

with open(path, "w", encoding="utf-8") as f:
    f.writelines(lines)

print("Done. Running syntax check...")
import ast
with open(path, encoding="utf-8") as f:
    src = f.read()
try:
    ast.parse(src)
    print("Syntax OK")
except SyntaxError as e:
    print(f"Still broken: {e}")
