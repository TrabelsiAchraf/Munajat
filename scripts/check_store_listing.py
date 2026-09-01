#!/usr/bin/env python3
"""Assert App Store Connect character limits on marketing/config/store_listing.md.

Scans every '**<Field>**' header followed by a fenced block and checks it
against ASC limits. Exits 1 if any field is over."""
import re
import sys
from pathlib import Path

LIMITS = {"Subtitle": 30, "Promotional Text": 170, "Keywords": 100, "Description": 4000}
md = Path(__file__).resolve().parent.parent / 'marketing' / 'config' / 'store_listing.md'
text = md.read_text(encoding='utf-8')
pattern = re.compile(
    r'\*\*(Subtitle|Promotional Text|Keywords|Description)\*\*[^\n]*\n+```\n(.*?)\n```',
    re.DOTALL)
failures = 0
for field, content in pattern.findall(text):
    n = len(content.strip())
    over = n > LIMITS[field]
    failures += over
    print(f"{'OVER' if over else 'OK  '} {field}: {n}/{LIMITS[field]}")
sys.exit(1 if failures else 0)
