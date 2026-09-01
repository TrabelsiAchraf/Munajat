# ASO Growth Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the 1.2.0 release backing the ASO repositioning: French translations + transliterations for the dhikr library, an App Store review prompt, a readable Hisn al-Muslim source label, and the corrected trilingual store listing.

**Architecture:** Content is enriched **in place** in `Adhkar/Resources/adhkar.json` by a new standalone Python script (never regenerating via `build_adhkar.py`, which would renumber ids used by `contexts.json` and `PostPrayerSequence`). Review prompting is a pure, unit-tested gate (`ReviewPromptGate`) wired into the existing celebration overlay. Marketing copy lives in `marketing/`, guarded by a new char-limit checker script.

**Tech Stack:** Swift/SwiftUI (iOS+macOS+visionOS), Swift Testing, Python 3 (stdlib only), XcodeBuildMCP for build/test.

**Spec:** `docs/superpowers/specs/2026-09-01-aso-growth-phase1-design.md`

## Global Constraints

- Code must compile for iOS, macOS AND visionOS (`SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx xros xrsimulator`). No `import UIKit` in shared code.
- Never modify religious content: the enrichment script copies the published French translation **verbatim** from the source dataset; no invented text, no invented references.
- Never touch existing JSON fields: `id`, `arabic`, `source`, `count`, `audio`, `translation.en` stay byte-identical. Only `translation.fr` and `transliteration.fr` may be **added**.
- French source dataset: `https://github.com/AleaToir3/hisnul-muslim-api-json`, pinned commit `57e451b34d5f98a9b75e1858ffd4ad8cad64bdd4`, downloaded to `/tmp/hisn_fr.json` (same `/tmp` convention as the ar/en sources).
- No new dependencies, no third-party analytics, no feature work beyond this plan.
- New test files require `ruby scripts/sync_test_sources.rb` (test group is a plain PBXGroup).
- Use XcodeBuildMCP tools for build/test (`session_show_defaults` once, then `build_sim` / `test_sim`). Raw `xcodebuild` only for the macOS platform check (MCP macOS workflow may not be enabled).
- Commit message style: `feat(content):`, `feat:`, `feat(ui):`, `docs(marketing):`, `chore(release):` + trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: French translations + transliterations in adhkar.json

**Files:**
- Create: `scripts/add_french_translations.py`
- Create: `AdhkarTests/FrenchContentCoverageTests.swift`
- Modify: `Adhkar/Resources/adhkar.json` (generated change, committed)

**Interfaces:**
- Consumes: `DataProvider.loadCategoriesThrowing(from:)`, `DataProvider.loadContextsThrowing(from:)` (existing), `Adhkar.translation: LocalizedText?`, `Adhkar.transliteration: LocalizedText?` (existing model fields; transliteration already rendered by `AdhkarDetailsView`'s DisclosureSection).
- Produces: `adhkar.json` items enriched with `"translation": {"en": …, "fr": …}` and `"transliteration": {"fr": …}`. No code consumer changes needed — `LocalizedText.resolved(for:)` already falls back en↔fr.

- [ ] **Step 1: Write the failing coverage test**

Create `AdhkarTests/FrenchContentCoverageTests.swift`:

```swift
// AdhkarTests/FrenchContentCoverageTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("French content coverage")
struct FrenchContentCoverageTests {
    /// Guards the ASO promise: every dhikr surfaced by a life context must
    /// have a French translation (the top download countries are
    /// francophone). Fails loudly if a data regeneration drops them.
    @Test func everyContextReferencedDhikrHasFrenchTranslation() throws {
        let categories = try DataProvider.loadCategoriesThrowing(from: Bundle.main)
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        let byId = Dictionary(
            uniqueKeysWithValues: categories.flatMap(\.adhkarList).map { ($0.id, $0) }
        )
        for context in contexts {
            for id in context.dhikrIds {
                let dhikr = try #require(byId[id], "context \(context.id) references missing item \(id)")
                #expect(!(dhikr.translation?.fr ?? "").isEmpty, "\(id) (context \(context.id)) missing fr translation")
            }
        }
    }

    @Test func overallFrenchCoverageAtLeast250Items() throws {
        let categories = try DataProvider.loadCategoriesThrowing(from: Bundle.main)
        let items = categories.flatMap(\.adhkarList)
        let withFr = items.filter { !($0.translation?.fr ?? "").isEmpty }
        #expect(withFr.count >= 250, "only \(withFr.count)/\(items.count) items have a French translation")
    }
}
```

- [ ] **Step 2: Register the test file and verify it fails**

Run: `ruby scripts/sync_test_sources.rb`
Then run the suite via XcodeBuildMCP `test_sim` (call `session_show_defaults` first if not yet done this session).
Expected: the two new tests FAIL (0 items currently have `translation.fr`). All pre-existing suites still pass.

- [ ] **Step 3: Download the pinned French source**

```bash
curl -sL "https://raw.githubusercontent.com/AleaToir3/hisnul-muslim-api-json/57e451b34d5f98a9b75e1858ffd4ad8cad64bdd4/finalData.json" -o /tmp/hisn_fr.json
python3 -c "print(open('/tmp/hisn_fr.json').read(200))"
```

Expected: file starts with `[` then `{"cat_id": 1, "tt_fr": "Les mérites…"`.

- [ ] **Step 4: Write the enrichment script**

Create `scripts/add_french_translations.py`:

```python
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
            # Short-text fallback: whole-string containment after normalization.
            for fr_it, _, fr_norm in fr_index:
                if fr_norm and (norm in fr_norm or fr_norm in norm):
                    best, ok = fr_it, True
                    break
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
```

- [ ] **Step 5: Run the script and check the report**

Run: `python3 scripts/add_french_translations.py`
Expected: `Matched ≥ 270/294`, unmatched list printed. Every id referenced by `contexts.json` must be matched (the dry-run showed the 5 short context texts are caught by the substring fallback). If a context-referenced id is still unmatched: **STOP — do not hand-write a translation.** Report the ids to Achraf for validated manual sourcing.

- [ ] **Step 6: Sanity-check that only fr keys were added**

```bash
python3 - << 'EOF'
import json, subprocess
old = json.loads(subprocess.run(['git', 'show', 'HEAD:Adhkar/Resources/adhkar.json'],
                                capture_output=True, text=True).stdout)
new = json.load(open('Adhkar/Resources/adhkar.json'))
o = {i['id']: i for c in old['categories'] for i in c['items']}
n = {i['id']: i for c in new['categories'] for i in c['items']}
assert o.keys() == n.keys(), "item ids changed!"
for k in o:
    for f in ('arabic', 'source', 'count', 'audio'):
        assert o[k].get(f) == n[k].get(f), f"{k}: field {f} changed!"
    assert (o[k].get('translation') or {}).get('en') == (n[k].get('translation') or {}).get('en'), f"{k}: en changed!"
    assert not (o[k].get('transliteration') or {}) or o[k]['transliteration'].items() <= n[k]['transliteration'].items(), f"{k}: transliteration lost!"
print("OK — only fr additions")
EOF
```

Expected: `OK — only fr additions`.

- [ ] **Step 7: Run the test suite to verify it passes**

Run the full suite via XcodeBuildMCP `test_sim`.
Expected: `FrenchContentCoverageTests` PASS, all pre-existing suites PASS (notably the PostPrayerSequence itemId guard, which proves ids survived).

- [ ] **Step 8: Spot-check in the simulator**

`build_run_sim`, open a context (e.g. Anxious) with the app language set to French (`-AppleLanguages "(fr)"` launch arg or device language), take a `screenshot`. Expected: French translation shown under the Arabic, transliteration DisclosureSection present.

- [ ] **Step 9: Commit**

```bash
git add scripts/add_french_translations.py AdhkarTests/FrenchContentCoverageTests.swift Adhkar/Resources/adhkar.json Adhkar.xcodeproj/project.pbxproj
git commit -m "feat(content): French translations + Latin transliterations for the dhikr library

Enriched in place from the published French edition of Hisn al-Muslim
(AleaToir3/hisnul-muslim-api-json @ 57e451b), matched Arabic-to-Arabic.
Only translation.fr / transliteration.fr added; ids, Arabic text, sources,
counts, audio and English translations untouched.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: App Store review prompt (ReviewPromptGate)

**Files:**
- Create: `Adhkar/Services/ReviewPromptGate.swift`
- Create: `AdhkarTests/ReviewPromptGateTests.swift`
- Modify: `Adhkar/Views/AdhkarDetailsView.swift` (celebration wiring, ~lines 78–80 and 130–141)

**Interfaces:**
- Consumes: existing celebration flow — `handleProgressChange(old:new:)` calls `markCelebrationShown()`; `CompletionOverlay(accent:onDismiss:)` closure sets `showCelebration = false`.
- Produces: `ReviewPromptGate.shouldRequest(celebrationCount:lastRequest:now:) -> Bool` (pure), `recordCelebration(in:)`, `recordRequest(in:now:)`, `shouldRequestNow(in:now:)` (UserDefaults-backed, keys `review.celebrationCount` / `review.lastRequestDate`).

- [ ] **Step 1: Write the failing tests**

Create `AdhkarTests/ReviewPromptGateTests.swift`:

```swift
// AdhkarTests/ReviewPromptGateTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("ReviewPromptGate")
struct ReviewPromptGateTests {
    @Test func neverBeforeSecondCelebration() {
        #expect(!ReviewPromptGate.shouldRequest(celebrationCount: 0, lastRequest: nil))
        #expect(!ReviewPromptGate.shouldRequest(celebrationCount: 1, lastRequest: nil))
    }

    @Test func firesFromSecondCelebrationWhenNeverAsked() {
        #expect(ReviewPromptGate.shouldRequest(celebrationCount: 2, lastRequest: nil))
        #expect(ReviewPromptGate.shouldRequest(celebrationCount: 40, lastRequest: nil))
    }

    @Test func respectsSixtyDayCooldown() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let fiftyNineDaysAgo = now.addingTimeInterval(-59 * 86_400)
        let sixtyOneDaysAgo = now.addingTimeInterval(-61 * 86_400)
        #expect(!ReviewPromptGate.shouldRequest(celebrationCount: 5, lastRequest: fiftyNineDaysAgo, now: now))
        #expect(ReviewPromptGate.shouldRequest(celebrationCount: 5, lastRequest: sixtyOneDaysAgo, now: now))
    }

    @Test func userDefaultsRoundTrip() {
        let suite = "test.reviewPromptGate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(!ReviewPromptGate.shouldRequestNow(in: defaults))
        ReviewPromptGate.recordCelebration(in: defaults)
        #expect(!ReviewPromptGate.shouldRequestNow(in: defaults))
        ReviewPromptGate.recordCelebration(in: defaults)
        #expect(ReviewPromptGate.shouldRequestNow(in: defaults))
        ReviewPromptGate.recordRequest(in: defaults)
        #expect(!ReviewPromptGate.shouldRequestNow(in: defaults))
    }
}
```

- [ ] **Step 2: Register and verify failure**

Run: `ruby scripts/sync_test_sources.rb`, then `test_sim`.
Expected: FAIL — `ReviewPromptGate` not defined.

- [ ] **Step 3: Implement the gate**

Create `Adhkar/Services/ReviewPromptGate.swift`:

```swift
// Adhkar/Services/ReviewPromptGate.swift
import Foundation

/// Decides when to ask for an App Store rating: from the second category
/// completion celebration onwards, at most once every 60 days. Apple's own
/// 3-prompts-per-year cap still applies on top of this gate.
struct ReviewPromptGate {
    static let celebrationCountKey = "review.celebrationCount"
    static let lastRequestKey = "review.lastRequestDate"
    static let minimumCelebrations = 2
    static let minimumDaysBetweenRequests = 60.0

    static func shouldRequest(celebrationCount: Int, lastRequest: Date?, now: Date = .now) -> Bool {
        guard celebrationCount >= minimumCelebrations else { return false }
        guard let lastRequest else { return true }
        return now.timeIntervalSince(lastRequest) >= minimumDaysBetweenRequests * 86_400
    }

    static func recordCelebration(in defaults: UserDefaults = .standard) {
        defaults.set(defaults.integer(forKey: celebrationCountKey) + 1, forKey: celebrationCountKey)
    }

    static func recordRequest(in defaults: UserDefaults = .standard, now: Date = .now) {
        defaults.set(now.timeIntervalSince1970, forKey: lastRequestKey)
    }

    static func shouldRequestNow(in defaults: UserDefaults = .standard, now: Date = .now) -> Bool {
        let ts = defaults.double(forKey: lastRequestKey)
        return shouldRequest(
            celebrationCount: defaults.integer(forKey: celebrationCountKey),
            lastRequest: ts > 0 ? Date(timeIntervalSince1970: ts) : nil,
            now: now
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run `test_sim`. Expected: all `ReviewPromptGate` tests PASS.

- [ ] **Step 5: Wire into the celebration flow**

In `Adhkar/Views/AdhkarDetailsView.swift`:

a. Add below `import SwiftData` (top of file):

```swift
import StoreKit
```

b. Add the environment action next to the other `@Environment` properties (after `@Environment(StreakService.self) private var streak`):

```swift
@Environment(\.requestReview) private var requestReview
```

c. In `markCelebrationShown()` add the counter (the function becomes):

```swift
private func markCelebrationShown() {
    UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: celebrationStorageKey)
    ReviewPromptGate.recordCelebration()
}
```

d. In `celebrationOverlay`, extend the `CompletionOverlay` dismiss closure (the ask happens as the celebration closes, never over it):

```swift
CompletionOverlay(accent: accent) {
    withAnimation(.easeOut(duration: 0.25)) {
        showCelebration = false
    }
    if ReviewPromptGate.shouldRequestNow() {
        ReviewPromptGate.recordRequest()
        requestReview()
    }
}
```

Note: `@Environment(\.requestReview)` (StoreKit) is available iOS 16+ / macOS 13+ / visionOS 1+ — no `#if` guard needed. Keep all additions inside the existing extracted properties/functions; do not chain new modifiers onto `body` (SourceKit type-check budget, see CLAUDE.md).

- [ ] **Step 6: Build for all three platforms**

- `build_sim` (iOS) via XcodeBuildMCP — expected: succeeds.
- macOS check: `xcodebuild -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=macOS' -configuration Debug build -quiet` — expected: succeeds (StoreKit available on macOS 13+).

- [ ] **Step 7: Run the full test suite**

Run `test_sim`. Expected: everything PASSES.

- [ ] **Step 8: Commit**

```bash
git add Adhkar/Services/ReviewPromptGate.swift AdhkarTests/ReviewPromptGateTests.swift Adhkar/Views/AdhkarDetailsView.swift Adhkar.xcodeproj/project.pbxproj
git commit -m "feat: ask for an App Store review after repeated category completions

Gate: from the 2nd completion celebration onward, at most once every
60 days, fired as the celebration overlay dismisses. Pure decision
logic unit-tested; StoreKit requestReview via SwiftUI environment
(iOS 16+/macOS 13+/visionOS 1+, fine on all three platforms).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Readable "Hisn al-Muslim" source label

**Files:**
- Modify: `Adhkar/Localization/L10n.swift` (add one string)
- Modify: `Adhkar/Views/AdhkarDetailsView.swift:307-313` (the `if !dhikr.source.isEmpty` block)

**Interfaces:**
- Consumes: `L10n` flat-enum pattern, `LocalizedText(ar:fr:en:)`, `dhikr.source: String` (Arabic takhrij reference).
- Produces: `L10n.sourceHisnLabel: LocalizedText`.

- [ ] **Step 1: Add the localized label**

In `Adhkar/Localization/L10n.swift`, next to the other dhikr-detail strings, add:

```swift
static let sourceHisnLabel = LocalizedText(ar: "المصدر: حصن المسلم", fr: "Source : Hisn al-Muslim", en: "Source: Hisn al-Muslim")
```

- [ ] **Step 2: Show it above the Arabic reference**

In `Adhkar/Views/AdhkarDetailsView.swift`, replace:

```swift
if !dhikr.source.isEmpty {
    Text(dhikr.source)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
}
```

with:

```swift
if !dhikr.source.isEmpty {
    VStack(spacing: 4) {
        Text(L10n.sourceHisnLabel.resolved())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        Text(dhikr.source)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding(.horizontal)
}
```

- [ ] **Step 3: Build + visual check**

`build_run_sim`, open any dhikr, `screenshot`. Expected: "Source: Hisn al-Muslim" (localized) above the Arabic reference, centered, secondary style. Verify no type-check-time warning appeared on `AdhkarDetailsView.body`.

- [ ] **Step 4: Run tests**

Run `test_sim`. Expected: all PASS (no logic touched).

- [ ] **Step 5: Commit**

```bash
git add Adhkar/Localization/L10n.swift Adhkar/Views/AdhkarDetailsView.swift
git commit -m "feat(ui): readable Hisn al-Muslim attribution above the Arabic source reference

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Store listing 1.2.0 + release notes + char-limit checker

**Files:**
- Modify: `marketing/config/store_listing.md` (full rewrite for 1.2.0)
- Create: `marketing/release-notes/1.2.0/fr.txt`, `en.txt`, `ar.txt`, `NOTES.md`
- Create: `scripts/check_store_listing.py`

**Interfaces:**
- Consumes: nothing from code — pure release assets.
- Produces: the exact texts to paste into App Store Connect; `scripts/check_store_listing.py` exits non-zero when a field exceeds ASC limits (Subtitle 30, Promotional Text 170, Keywords 100, Description 4000).

- [ ] **Step 1: Write the checker script**

Create `scripts/check_store_listing.py`:

```python
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
```

- [ ] **Step 2: Rewrite `marketing/config/store_listing.md`**

Replace the whole file with the following (keep it as the single canonical listing; git history keeps 1.1.0):

`````markdown
# App Store Listing — Munajat 1.2.0

Tout le texte à coller dans App Store Connect → My Apps → Munajat → Version 1.2.0 → Localization.
Trois langues : **French (Primary), English, Arabic**.
Vérification des limites : `python3 scripts/check_store_listing.py`.

Baseline ASO notée le 2026-09-01 : 30 first-time downloads all-time, 8/30 j,
2/7 j, top pays Sénégal 11 · France 6 · US 4. Fenêtre de test : 30 jours
après publication, sans retoucher la fiche.

---

## 🇫🇷 French

**Name** (max 30 chars — changement de nom localisé, passe en review)
```
Munajat — Dhikr & Douas
```

**Subtitle** (max 30 chars)
```
Adhkar selon ton état du cœur
```

**Promotional Text** (max 170 chars — éditable sans resoumission)
```
Trouve le dhikr adapté à ce que tu traverses : anxiété, gratitude, insomnie, épreuve… Nouveau : traductions françaises et translittérations pour les invocations.
```

**Description** (max 4000 chars)
```
Trouve le bon dhikr pour ce que tu vis.

Munajat est la seule app d'adhkar organisée autour de ton état du cœur — pas seulement selon l'heure de la journée.

——

QUAND TU TE SENS…

Anxieux, reconnaissant, triste, en colère, apeuré, heureux, repentant, plein d'espoir. Et dans les épreuves : maladie, deuil, dette, moment important, conflit, insomnie, doute. Munajat te propose les invocations du Coran et de la Sunna qui correspondent à ce moment précis de ta vie — 15 contextes, soigneusement curés à partir du Hisn al-Muslim (La Citadelle du Musulman).

——

EN FRANÇAIS, VRAIMENT

Texte arabe, traduction française, translittération latine pour réciter même sans lire l'arabe, source et récitation audio.

——

APRÈS LA PRIÈRE

Les adhkar de Hisn al-Muslim après le salâm, guidés étape par étape. Les douze invocations dans leur ordre traditionnel, chacune avec son compteur : trois istighfâr, les tasbîhât trente-trois fois chacun jusqu'aux cent, les sourates, Âyat al-Kursî. Tu tapes, l'application enchaîne.

——

MÉMORISE CE QUI COMPTE

Active le mode Mémoriser sur n'importe quel dhikr. L'application le programme dans une boucle de répétition espacée (algorithme SM-2 simplifié) — cinq minutes par jour, et les essentiels s'ancrent.

——

TOUT CE QU'ON ATTEND D'UNE APP D'ADHKAR

• 294 invocations du Coran et de la Sunna, la source citée pour chacune — Hisn al-Muslim
• Audio pour chaque dhikr (nécessite Internet)
• Textes, compteurs et mémorisation disponibles hors ligne
• Compteur tactile avec remise à zéro quotidienne, streak pour soutenir la pratique
• Partage de n'importe quel dhikr sous forme de carte illustrée
• Widget d'écran d'accueil avec le dhikr du moment
• Trilingue : arabe, français, anglais — layout droite-à-gauche en arabe
• Typographie Amiri et Amiri Quran pour les versets coraniques
• 100 % local : aucun compte, aucun pistage, aucune publicité

——

CONÇU AVEC SOIN

Pas de pop-up, pas de monétisation cachée. Une app que je voulais pour ma propre pratique quotidienne, et que je partage maintenant.

— Achraf
```

**Keywords** (max 100 chars, séparés par des virgules sans espace ; ne répète pas les mots du nom/sous-titre)
```
azkar,invocation,islam,musulman,priere,anxiete,sommeil,tristesse,citadelle,rappel,dua
```

---

## 🇬🇧 English

**Name** (max 30 chars — inchangé)
```
Munajat — Dhikr & Dua
```

**Subtitle** (max 30 chars)
```
Adhkar for how you feel
```

**Promotional Text** (max 170 chars)
```
Find the right dhikr for what you're going through — anxiety, gratitude, sleeplessness, hardship. Now with French translations and Latin transliterations.
```

**Description** (max 4000 chars)
```
Find the right dhikr for what you're going through.

Munajat is the only adhkar app organized around the state of your heart — not just the time of day.

——

WHEN YOU FEEL…

Anxious, grateful, sad, angry, fearful, happy, regretful, hopeful. And through life's trials: sickness, mourning, debt, an important moment ahead, conflict, insomnia, doubt. Munajat surfaces the Quranic and prophetic invocations that fit this exact moment of your life — 15 contexts, carefully curated from Hisn al-Muslim (Fortress of the Muslim).

——

READ IT, RECITE IT

Arabic text, translations, Latin transliteration so you can recite even without reading Arabic, sources, and audio recitation.

——

AFTER THE PRAYER

The adhkar of Hisn al-Muslim after the salam, guided step by step. The twelve invocations in their traditional order, each with its own counter: three istighfar, the tasbihat thirty-three times each up to the hundred, the surahs, Ayat al-Kursi. You tap, the app moves you on.

——

MEMORIZE WHAT MATTERS

Tap Memorize on any dhikr. The app schedules it in a spaced-repetition loop (simplified SM-2) — five minutes a day, and the essentials anchor.

——

EVERYTHING YOU EXPECT FROM AN ADHKAR APP

• 294 invocations from the Quran and Sunnah, each with its cited source — Hisn al-Muslim
• Audio for every dhikr (requires Internet)
• Texts, counters and memorization work offline
• Tap-to-count with daily auto-reset, streaks to support the habit
• Share any dhikr as a beautifully rendered card
• Home Screen widget with the dhikr of the moment
• Trilingual: Arabic, French, English — right-to-left layout in Arabic
• Amiri and Amiri Quran typography for Quranic verses
• 100% on-device: no account, no tracking, no ads

——

MADE WITH CARE

No pop-ups, no hidden monetization. An app I wanted for my own daily practice, now shared.

— Achraf
```

**Keywords** (max 100 chars; no competitor names; no words already in name/subtitle)
```
azkar,zikr,muslim,prayer,anxiety,sleep,stress,sadness,grief,hisnulmuslim,remembrance,islam
```

---

## 🇸🇦 Arabic (العربية)

**Name** (max 30 chars)
```
مناجاة — أذكار ودعاء
```

**Subtitle** (max 30 chars)
```
أذكار حسب حالة قلبك
```

**Promotional Text** (max 170 chars)
```
اعثر على الذكر المناسب لما تعيشه — قلق، شكر، أرق، ابتلاء. جديد: ترجمات فرنسية ونقل حرفي لاتيني للأدعية.
```

**Description** (max 4000 chars)
```
اعثر على الذكر المناسب لما تعيشه.

مناجاة هو تطبيق الأذكار الوحيد الذي ينتظم حسب حالة قلبك، لا حسب الساعة فقط.

——

حين تشعر بـ…

قلق، شكر، حزن، غضب، خوف، فرح، ندم، رجاء. وفي الابتلاءات: مرض، فقد، دَين، قبل أمر مهم، خلاف، أرق، شك. يقدّم لك مناجاة الأدعية القرآنية والنبوية المناسبة لهذه اللحظة بالذات — ١٥ حالة مختارة بعناية من حصن المسلم.

——

اقرأه ورتّله

النص العربي، والترجمة (فرنسية وإنجليزية)، والنقل الحرفي اللاتيني، والمصدر، والتلاوة الصوتية.

——

بعد الصلاة

أذكار حصن المسلم بعد السلام، مُوجَّهة خطوة بخطوة. الأذكار الاثنا عشر بترتيبها المأثور، ولكل ذكر عدّاده: الاستغفار ثلاثًا، والتسبيحات ثلاثًا وثلاثين حتى المئة، والسور، وآية الكرسي. تنقر، والتطبيق ينتقل بك.

——

احفظ ما يهمك

اضغط «احفظ» على أي ذكر ليدخل دورة مراجعة متباعدة (SM-2 مبسّطة) — خمس دقائق يومياً وتترسّخ الأذكار الأساسية.

——

كل ما تنتظره من تطبيق أذكار

• ٢٩٤ دعاء من القرآن والسنة، مع ذكر المصدر لكل دعاء — حصن المسلم
• تلاوة لكل ذكر (تتطلب الإنترنت)
• النصوص والعدّادات والحفظ تعمل دون اتصال
• عدّاد لمسي يُعاد ضبطه يومياً، وسلسلة يومية للمواظبة
• مشاركة أي ذكر على هيئة بطاقة جميلة
• ودجت للشاشة الرئيسية يعرض ذكر اللحظة
• ثلاثي اللغة: عربي، فرنسي، إنجليزي — بتخطيط من اليمين إلى اليسار
• خط أميري وأميري قرآن للآيات
• ١٠٠٪ محلي: بدون حساب، بدون تتبع، بدون إعلانات

——

صُنع بعناية

بدون نوافذ منبثقة، بدون اشتراك خفي. تطبيق أردته لممارستي اليومية، وأشاركه الآن.

— أشرف
```

**Keywords** (max 100 chars — pas d'espaces, virgules seulement)
```
دعاء,حصن,المسلم,قرآن,إسلام,مسلم,صلاة,ذكر,حفظ,قلق,نوم,أذكار
```

---

## 📨 App Review Information — Notes (delta vs 1.1.0)

Reprendre les notes 1.1.0 (git : `marketing/config/store_listing.md@872135c`) en ajoutant au début de la section KEY FLOWS :

```
Since 1.1.0: the dhikr library gained French translations and Latin
transliterations (same public-domain Hisn al-Muslim source), a visible
"Source: Hisn al-Muslim" label on each dhikr, and a standard SKStoreReview
prompt shown at most after a 2nd completed category and then no more than
once per 60 days. No new permissions, no new network calls.
```

---

## 🆕 What's New in This Version

Voir `marketing/release-notes/1.2.0/` (un `.txt` par langue + NOTES.md).
`````

- [ ] **Step 3: Run the checker**

Run: `python3 scripts/check_store_listing.py`
Expected: every line `OK`, exit 0. If a field is OVER, trim that field's text (shorten wording, never break the no-competitor/no-repeat keyword rules) and re-run.

- [ ] **Step 4: Write the release notes**

Create `marketing/release-notes/1.2.0/fr.txt`:

```
• Traductions françaises pour les invocations de toute la bibliothèque
• Translittérations latines pour réciter même sans lire l'arabe
• La source Hisn al-Muslim affichée clairement sous chaque dhikr
```

Create `marketing/release-notes/1.2.0/en.txt`:

```
• French translations across the dhikr library
• Latin transliterations so you can recite even without reading Arabic
• A clear Hisn al-Muslim source label under every dhikr
```

Create `marketing/release-notes/1.2.0/ar.txt`:

```
• ترجمات فرنسية لأدعية المكتبة كاملة
• نقل حرفي لاتيني للتلاوة حتى دون قراءة العربية
• عرض واضح للمصدر «حصن المسلم» تحت كل ذكر
```

Create `marketing/release-notes/1.2.0/NOTES.md`:

```markdown
# Notes de formulation — 1.2.0

Release ASO phase 1 (spec : docs/superpowers/specs/2026-09-01-aso-growth-phase1-design.md).

- On ne mentionne pas la demande d'avis (interne, pas une feature utilisateur).
- « toute la bibliothèque » : couverture réelle ≥ 250/294 avec fallback anglais
  pour le reste — formulation validée car chaque invocation affiche une
  traduction (fr ou en) ; ne pas durcir en « chaque invocation en français ».
- Sous-titre EN retenu : « Adhkar for how you feel ». Alternatives écartées :
  « Dhikr for Every Moment » (répète « Dhikr » déjà dans le nom — gaspille un
  mot-clé), « Adhkar for what you live » (calque non idiomatique).
- Keywords : ne répètent aucun mot du nom/sous-titre de la même locale ;
  aucun nom de concurrent ; « quran » écarté (l'app n'est pas une app Coran).
- Baseline du test 30 jours notée en tête de store_listing.md.
```

- [ ] **Step 5: Commit**

```bash
git add marketing/config/store_listing.md marketing/release-notes/1.2.0/ scripts/check_store_listing.py
git commit -m "docs(marketing): store listing 1.2.0 — ASO phase 1 repositioning

Situation-first hook, real context names, verifiable Hisn al-Muslim
attribution instead of a bare authenticity claim, offline claim scoped
to texts, keywords rebuilt without repeating name/subtitle words.
Char limits enforced by scripts/check_store_listing.py.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Version bump 1.2.0 + CHANGELOG

**Files:**
- Modify: `Adhkar.xcodeproj/project.pbxproj` (MARKETING_VERSION on every configuration that has one)
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `xcodeproj` Ruby gem (already used by `scripts/setup_widget_target.rb`).
- Produces: version 1.2.0 across app + widget targets (must match for extension embedding).

- [ ] **Step 1: Record how many configurations carry the version**

Run: `grep -c "MARKETING_VERSION = 1.1.0;" Adhkar.xcodeproj/project.pbxproj`
Note the count N.

- [ ] **Step 2: Bump with the xcodeproj gem**

```bash
ruby -e '
require "xcodeproj"
project = Xcodeproj::Project.open("Adhkar.xcodeproj")
(project.targets.flat_map(&:build_configurations) + project.build_configurations).each do |c|
  c.build_settings["MARKETING_VERSION"] = "1.2.0" if c.build_settings.key?("MARKETING_VERSION")
end
project.save
'
```

- [ ] **Step 3: Verify the bump**

```bash
grep -c "MARKETING_VERSION = 1.2.0;" Adhkar.xcodeproj/project.pbxproj   # expect N
grep -c "MARKETING_VERSION = 1.1.0;" Adhkar.xcodeproj/project.pbxproj   # expect 0 (grep exits 1)
```

- [ ] **Step 4: Update CHANGELOG.md**

Read `CHANGELOG.md` and insert a new section above the `1.1.0` entry, matching the file's existing heading/date format, with this content:

```markdown
## 1.2.0 — 2026-09-XX

### Added
- French translations (published Hisn al-Muslim edition) and Latin
  transliterations across the dhikr library, matched Arabic-to-Arabic
  by `scripts/add_french_translations.py`.
- App Store review prompt: from the 2nd completion celebration, at most
  once per 60 days (`ReviewPromptGate`, unit-tested).
- Readable "Source: Hisn al-Muslim" label above the Arabic reference in
  the dhikr detail view.
- `scripts/check_store_listing.py` guards App Store Connect char limits.

### Marketing
- Store listing rewritten for the situation-first positioning (ASO
  phase 1). Baseline noted: 8 first-time downloads / 30 days.
```

(Replace `XX` with the actual release day when submitting.)

- [ ] **Step 5: Final full verification**

- `test_sim` — expected: entire suite PASSES.
- `build_sim` — expected: iOS build succeeds.
- `xcodebuild -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=macOS' -configuration Debug build -quiet` — expected: succeeds.
- `python3 scripts/check_store_listing.py` — expected: all OK.

- [ ] **Step 6: Commit**

```bash
git add Adhkar.xcodeproj/project.pbxproj CHANGELOG.md
git commit -m "chore(release): bump to 1.2.0 + changelog

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Manual follow-ups (App Store Connect — Achraf)

Not code; do these when submitting 1.2.0:

1. Paste per-locale Name / Subtitle / Promotional Text / Description /
   Keywords from `marketing/config/store_listing.md` (FR primary, EN, AR).
2. Paste What's New from `marketing/release-notes/1.2.0/*.txt`.
3. Update App Review notes with the delta block from store_listing.md.
4. Set the build number (date format, e.g. `0209202XXXXX`) at archive time.
5. Record the release date as day 0 of the 30-day ASO experiment; capture
   impressions / product page views / conversion / downloads / countries
   weekly; do NOT touch the listing during the window.
6. Screenshots (Phase B) are a separate follow-up plan once this ships —
   hero = context picker, using `scripts/make_screenshots.py` +
   `capture_marketing.sh` and `-MarketingScreen`.
7. Before submitting: skim a sample of the new French translations in-app
   (religious content — final validation is yours).
