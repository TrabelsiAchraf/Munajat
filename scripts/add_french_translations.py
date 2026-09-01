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
build_adhkar.py): a candidate qualifies only if token containment >= 0.6
AND the token-count ratio >= 0.5 (guards against a short generic candidate
"fitting inside" an unrelated long item), selected deterministically by
largest token intersection then highest ratio. Items too short/generic to
token-match safely fall back to normalized-substring containment with the
same qualification + tie-break shape.

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

# Same class of upstream structural glitch as the doubled-brace repair below:
# the pinned source has at least one stray CJK character embedded mid-word
# in an otherwise-French string (confirmed: a single "内" in the candidate
# used for fear_unjust_ruler_1 — an isolated one-off, not systemic; scanned
# all 283 usable source items and found exactly this one occurrence). Strip
# CJK Unified Ideographs + fullwidth forms from copied fr/tic text as a
# corruption repair, not a content edit — logged whenever it actually fires.
CJK_STRIP = re.compile(r'[一-鿿　-〿]')

def strip_cjk(text: str, *, item_id: str, field: str) -> str:
    cleaned = CJK_STRIP.sub('', text)
    if cleaned != text:
        print(f"  repaired stray CJK character(s) in {field} for {item_id}: {text!r} -> {cleaned!r}")
    return cleaned

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

# Repetition-count boilerplate ("(سبع مرات)" = "(seven times)", "(ثلاثاً)" =
# "(three times)") appears, verbatim, on a large fraction of the corpus'
# duas and carries zero topical content — but two UNRELATED duas that happen
# to share a repeat count (e.g. both "... 7 times") pick up "سبع"+"مرات" as
# shared tokens, which can be enough to push containment/ratio over the
# matching thresholds for otherwise-short items (confirmed: this alone
# hijacked morning_adhkar_10 — Hasbiya Allah, recited 7x — to an unrelated
# "ask Allah to heal you, 7x" hadith). Excluded the same way "و"/"في"/etc.
# are: they're structural, not content, words.
NUMERAL_STOP = {
    "مره", "مرات", "مرتين",
    "واحد", "واحده",
    "ثلاث", "ثلاثه", "ثلاثا", "ثلاثين",
    "اربع", "اربعه", "اربعا", "اربعين",
    "خمس", "خمسه", "خمسا", "خمسين",
    "ست", "سته", "ستا", "ستين",
    "سبع", "سبعه", "سبعا", "سبعين",
    "ثمان", "ثمانيه", "ثمانيا", "ثمانين",
    "تسع", "تسعه", "تسعا", "تسعين",
    "عشر", "عشره", "عشرا", "عشرين",
    "مايه", "ميه", "الف",  # normalized forms of مائة/مئة (hundred) — NOT "مائه"/"مئه":
    # norm_ar converts ئ->ي BEFORE stripping diacritics-adjacent forms, so
    # "مائة" normalizes to "مايه", not "مائه" (a mistake caught here by
    # actually running norm_ar on each candidate rather than hand-deriving).
}

# Narrative-attribution boilerplate ("قال" = "said", as in "man qala..." /
# "the Prophet said...") is near-universal across hadith-sourced entries and
# carries no topical content — but it inflated the shared-token count enough
# to pick a WRONG same-shape hadith over the right one for a short summary
# item (confirmed: morning_adhkar_18/evening_adhkar_18 — "Subhan Allah wa
# bihamdihi, 100x, sins forgiven" — matched a *different* hadith, "Subhan
# Allah al-Azim wa bihamdihi, a palm tree in Paradise", via "قال"+"سبحان"+
# "وبحمده" overlap alone). Excluded for the same reason NUMERAL_STOP is.
ATTRIBUTION_STOP = {"قال", "وقال", "فقال"}

def tokens(s: str) -> set:
    return {
        t for t in norm_ar(s).split()
        if len(t) >= 3
        and t not in SHORT_STOP
        and t not in NUMERAL_STOP
        and t not in ATTRIBUTION_STOP
    }

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

        # Token path. `containment = |a∩b| / min(|a|,|b|)` alone scores 1.0
        # for ANY candidate whose tokens are a subset of the item's — a
        # generic 1-2-token candidate (e.g. "بسم الله") is a subset of dozens
        # of longer items, and the old strict `s > score` loop kept whichever
        # such candidate happened to appear FIRST in source order, hijacking
        # ~35 unrelated items (the three Quls, Ayat al-Kursi, several
        # morning/evening duas, ...). A candidate now qualifies only if BOTH
        # containment >= 0.6 AND the token-COUNT ratio (min/max token counts)
        # >= 0.5 — a short candidate can no longer "fit inside" a long item.
        # Among qualifiers, select deterministically by largest token
        # intersection first, then highest count ratio.
        #
        # NOTE on morning/evening items specifically: every morning_adhkar_N
        # / evening_adhkar_N pair in this bundle's adhkar.json shares BYTE-
        # IDENTICAL Arabic (the shared dhikr's own text notes the evening
        # substitution inline, e.g. "...وإذا أمسى قال ذلك أيضاً: أمسينا...").
        # Since matching is Arabic-only, identical input deterministically
        # picks the identical candidate for both — there is no tie to break
        # by token count here. A handful of those candidates are themselves
        # phrased in French with an explicit "matin" (morning) framing and no
        # evening counterpart (e.g. "Nous voici au matin..."), which reads as
        # wrong under an evening_adhkar_N item even though the Arabic and
        # matching are both technically correct. See the post-loop pass
        # below that clears those specific evening assignments.
        # NOTE — deviation beyond the literal ratio>=0.5 rule, flagged for
        # review: the ratio gate alone also excludes a small class of
        # LEGITIMATE matches — long Quranic-recitation items (the Quls,
        # Ayat al-Kursi) whose only source counterpart is a short, abbreviated
        # reference caption (e.g. source id 95's ar is literally the opening
        # words of each surah followed by "..." — 7 tokens — for an item
        # reciting the full ~40-token surah text). All confirmed-damaging
        # candidates from the original bug have an absolute token
        # intersection <= 4 (single generic words like "بسم" or short
        # phrases); the legitimate abbreviated references have intersection
        # >= 5 specific, surah-identifying tokens (e.g. "الفلق", "الناس" for
        # the Quls; "القيوم" etc. for Ayat al-Kursi). Bypassing the ratio
        # requirement when intersection >= 5 (containment >= 0.6 still
        # required) recovers these without reopening the hijack bug — see
        # fix-report for the numeric evidence per item.
        best, best_key = None, None
        for fr_it, fr_toks, _ in fr_index:
            if not toks or not fr_toks:
                continue
            inter = len(toks & fr_toks)
            cont = containment(toks, fr_toks)
            ratio = min(len(toks), len(fr_toks)) / max(len(toks), len(fr_toks))
            if cont >= 0.6 and (ratio >= 0.5 or inter >= 5):
                key = (inter, ratio)
                if best_key is None or key > best_key:
                    best, best_key = fr_it, key
        ok = best is not None and len(toks) >= 3
        if not ok and norm:
            # Short-text fallback (items too short/generic to token-match
            # safely at all, e.g. single-word or 2-word dhikr): best-candidate
            # substring containment after normalization — NOT
            # first-match-in-source-order, which produced factually wrong
            # translations (e.g. "الله أكبر" grabbing an unrelated chapter's
            # entry before the correct Takbir one, just because it appeared
            # earlier in the source file). A candidate qualifies only if one
            # normalized string contains the other AND the length ratio is
            # >= 0.5 (guards against a 3-word phrase matching inside an
            # unrelated 40-word paragraph). Among qualifiers, prefer an exact
            # normalized match; within that (or the general) pool, break ties
            # deterministically the same way as the token path: largest token
            # intersection first, then highest length ratio. No qualifying
            # candidate -> stays unmatched (safe: app falls back to English)
            # rather than risk a wrong fr.
            candidates = []
            for fr_it, fr_toks, fr_norm in fr_index:
                if not fr_norm:
                    continue
                if norm in fr_norm or fr_norm in norm:
                    ratio = min(len(norm), len(fr_norm)) / max(len(norm), len(fr_norm))
                    if ratio >= 0.5:
                        inter = len(toks & fr_toks)
                        candidates.append((fr_it, fr_norm, ratio, inter))
            if candidates:
                exact = [c for c in candidates if c[1] == norm]
                pool = exact if exact else candidates
                best = max(pool, key=lambda c: (c[3], c[2]))[0]
                ok = True
        if not ok:
            unmatched.append(item['id'])
            continue
        matched += 1
        tr = item.setdefault('translation', {})
        if not tr.get('fr') and best.get('fr'):
            tr['fr'] = strip_cjk(best['fr'].strip(), item_id=item['id'], field='translation.fr')
            fr_added += 1
        tl = item.get('transliteration') or {}
        if not tl.get('fr') and best.get('tic'):
            tl['fr'] = strip_cjk(best['tic'].strip(), item_id=item['id'], field='transliteration.fr')
            item['transliteration'] = tl
            tic_added += 1

# ---------- Evening/morning-shared-Arabic guard ----------
# morning_adhkar_N and evening_adhkar_N always share identical Arabic (see
# note above), so an evening item can end up assigned a French text that
# explicitly says "matin" (morning) with no "soir" (evening) counterpart —
# faithful to the shared Arabic, but wrong to show under an evening-labelled
# dhikr. Per policy: never ship the morning-framed text under an evening
# item; drop it back to unmatched (English fallback) instead of guessing a
# rewording. Bidirectional morning-and-evening phrasing (has both "matin"
# and "soir", e.g. "par Toi nous sommes au matin et par Toi... au soir") is
# left alone — it's correct either way.
morning_evening_dropped = []
for cat in data['categories']:
    for item in cat['items']:
        if not item['id'].startswith('evening_adhkar_'):
            continue
        fr_text = (item.get('translation') or {}).get('fr') or ''
        low = fr_text.lower()
        if 'matin' in low and 'soir' not in low:
            item['translation'].pop('fr', None)
            if item.get('transliteration', {}).get('fr'):
                item['transliteration'].pop('fr', None)
                tic_added -= 1
            matched -= 1
            fr_added -= 1
            unmatched.append(item['id'])
            morning_evening_dropped.append(item['id'])

DST.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
total = sum(len(c['items']) for c in data['categories'])
print(f"Matched {matched}/{total} items — added fr: {fr_added}, transliteration: {tic_added}")
print(f"Unmatched ({len(unmatched)}): {', '.join(unmatched) or 'none'}")
if morning_evening_dropped:
    print(f"Dropped as morning-framed-under-evening ({len(morning_evening_dropped)}): {', '.join(morning_evening_dropped)}")
