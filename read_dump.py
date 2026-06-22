import sys

with open('dump.txt', 'r', encoding='utf-16le') as f:
    for line in f:
        line = line.strip()
        if "15" in line or "17" in line or "39" in line:
            print(line)
