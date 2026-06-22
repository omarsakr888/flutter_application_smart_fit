import sys

with open('dump.txt', 'r', encoding='utf-16le') as f, open('dump_numbers.txt', 'w', encoding='utf-8') as out:
    for line in f:
        line = line.strip()
        if any(c.isdigit() for c in line):
            out.write(line + "\n")
