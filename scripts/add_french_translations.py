#!/usr/bin/env python3
"""Enrich Adhkar/Resources/adhkar.json with the published French translation
of Hisn al-Muslim (La Citadelle du Musulman).

Source: /tmp/hisn_fr.json — raw finalData.json from
https://github.com/AleaToir3/hisnul-muslim-api-json
(pinned commit 57e451b34d5f98a9b75e1858ffd4ad8cad64bdd4):

  curl -sL https://raw.githubusercontent.com/AleaToir3/hisnul-muslim-api-json/57e451b34d5f98a9b75e1858ffd4ad8cad64bdd4/finalData.json -o /tmp/hisn_fr.json

The upstream file has a few structural glitches (doubled braces, one
double-nested list); they are repaired before parsing. Matching is
Arabic -> Arabic on normalized token sets (same normalization as
build_adhkar.py): token containment >= 0.6, with a normalized-substring
fallback for texts too short to tokenize reliably.

Writes ONLY translation.fr and transliteration.fr — verbatim from the
source, never overwriting an existing non-empty value, never touching
id/arabic/source/count/audio/translation.en. Idempotent. Prints a
coverage report and the unmatched item ids.
"""
import json
import re
from pathlib import Path

SRC = Path('/tmp/hisn_fr.json')
DST = Path(__file__).resolve().parent.parent / 'Adhkar' / 'Resources' / 'adhkar.json'

# ---------- Arabic normalization & tokenisation (same as build_adhkar.py) ----------
DIACRITICS = re.compile(r'[ً-ٰٟۖ-ۭ]')
TATWEEL = re.compile(r'ـ')

def norm_ar(s: str) -> str:
    if not s:
        return ""
    s = DIACRITICS.sub('', s)
    s = TATWEEL.sub('', s)
    s = (s.replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا')
           .replace('ى', 'ي').replace('ئ', 'ي').replace('ؤ', 'و')
           .replace('ة', 'ه'))
    # Deliberate delta vs build_adhkar.py's norm_ar: strip Arabic punctuation
    # before collapsing whitespace, so inconsistent spacing around commas
    # (e.g. "صائم ، إني" vs "صائم، إني" between the two sources) can't
    # defeat the short-text substring fallback below.
    s = re.sub(r'[،؛؟]', ' ', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return re.sub(r'[^؀-ۿ\s]', '', s)

SHORT_STOP = {"و", "في", "من", "ما", "لا", "هو", "ال", "اله", "الله", "يا", "ان", "اذا", "علي"}

def tokens(s: str) -> set:
    return {t for t in norm_ar(s).split() if len(t) >= 3 and t not in SHORT_STOP}

def containment(a: set, b: set) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / min(len(a), len(b))

# ---------- Load + repair the French source ----------
raw = SRC.read_text(encoding='utf-8')
# Doubled braces sit alone at line boundaries; braces inside strings
# (Quranic {...} quotes) are single and never touched by these patterns.
raw = re.sub(r'\{\{(\s*\n)', r'{\1', raw)
raw = re.sub(r'(\n\s*)\}\}(,?\s*\n)', r'\1}\2', raw)
chapters = json.loads(raw)

fr_items = []

def collect(node):
    if isinstance(node, dict) and node.get('ar') and node.get('fr'):
        fr_items.append(node)
    elif isinstance(node, list):
        for child in node:
            collect(child)

for ch in chapters:
    collect(ch.get('dua', []))

fr_index = [(it, tokens(it['ar']), norm_ar(it['ar'])) for it in fr_items]
print(f"French source: {len(chapters)} chapters, {len(fr_items)} usable items")

# ---------- Enrich adhkar.json in place ----------
data = json.loads(DST.read_text(encoding='utf-8'))
matched = fr_added = tic_added = 0
unmatched = []

for cat in data['categories']:
    for item in cat['items']:
        toks = tokens(item['arabic'])
        norm = norm_ar(item['arabic'])
        best, score = None, 0.0
        for fr_it, fr_toks, _ in fr_index:
            s = containment(toks, fr_toks)
            if s > score:
                best, score = fr_it, s
        ok = best is not None and score >= 0.6 and len(toks) >= 3
        if not ok and norm:
            # Short-text fallback: best-candidate substring containment after
            # normalization — NOT first-match-in-source-order, which produced
            # factually wrong translations for short/generic texts (e.g. "الله
            # أكبر" grabbing an unrelated chapter's entry before the correct
            # Takbir one, just because it happened to appear earlier in the
            # source file). A candidate qualifies only if one normalized string
            # contains the other AND the length ratio is >= 0.5 (guards against
            # a 3-word phrase matching inside an unrelated 40-word paragraph).
            # Among qualifying candidates, prefer an exact normalized match;
            # otherwise take the closest length match (highest ratio). No
            # qualifying candidate -> stays unmatched (safe: app falls back to
            # English in that case) rather than risk a wrong fr.
            candidates = []
            for fr_it, _, fr_norm in fr_index:
                if not fr_norm:
                    continue
                if norm in fr_norm or fr_norm in norm:
                    ratio = min(len(norm), len(fr_norm)) / max(len(norm), len(fr_norm))
                    if ratio >= 0.5:
                        candidates.append((fr_it, fr_norm, ratio))
            if candidates:
                exact = [c for c in candidates if c[1] == norm]
                pool = exact if exact else candidates
                best = max(pool, key=lambda c: c[2])[0]
                ok = True
        if not ok:
            unmatched.append(item['id'])
            continue
        matched += 1
        tr = item.setdefault('translation', {})
        if not tr.get('fr') and best.get('fr'):
            tr['fr'] = best['fr'].strip()
            fr_added += 1
        tl = item.get('transliteration') or {}
        if not tl.get('fr') and best.get('tic'):
            tl['fr'] = best['tic'].strip()
            item['transliteration'] = tl
            tic_added += 1

DST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
total = sum(len(c['items']) for c in data['categories'])
print(f"Matched {matched}/{total} items — added fr: {fr_added}, transliteration: {tic_added}")
print(f"Unmatched ({len(unmatched)}): {', '.join(unmatched) or 'none'}")
