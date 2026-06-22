import os
import re
import json

directory = r'c:\Users\zash0\Downloads\flutter_application_smart_fit\lib\screens'
strings = set()

for root, _, files in os.walk(directory):
    for f in files:
        if f.endswith('.dart'):
            with open(os.path.join(root, f), 'r', encoding='utf-8') as file:
                content = file.read()
                matches = re.findall(r"Text\(\s*'([^'\\]*(?:\\.[^'\\]*)*)'\s*", content)
                for m in matches:
                    strings.add(m)

print(json.dumps(list(strings), indent=2))
