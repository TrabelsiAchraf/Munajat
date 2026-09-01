#!/usr/bin/env python3
"""Assert App Store Connect character limits on marketing/config/store_listing.md.

Scans every '**<Field>**' header followed by a fenced block and checks it
against ASC limits. Exits 1 if any field is over."""
import re
import sys
from pathlib import Path

LIMITS = {"Name": 30, "Subtitle": 30, "Promotional Text": 170, "Keywords": 100, "Description": 4000}
EXPECTED_BLOCKS = 15  # 3 locales x 5 fields (Name, Subtitle, Promotional Text, Description, Keywords)
md = Path(__file__).resolve().parent.parent / 'marketing' / 'config' / 'store_listing.md'
text = md.read_text(encoding='utf-8')
pattern = re.compile(
    r'\*\*(Name|Subtitle|Promotional Text|Keywords|Description)\*\*[^\n]*\n+```\n(.*?)\n```',
    re.DOTALL)
matches = pattern.findall(text)
failures = 0
for field, content in matches:
    n = len(content.strip())
    over = n > LIMITS[field]
    failures += over
    print(f"{'OVER' if over else 'OK  '} {field}: {n}/{LIMITS[field]}")

if len(matches) != EXPECTED_BLOCKS:
    print(f"ERROR: expected {EXPECTED_BLOCKS} field blocks, matched {len(matches)} — "
          f"a header may have been renamed/removed and is silently being skipped.")
    sys.exit(1)

sys.exit(1 if failures else 0)
