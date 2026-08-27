# Munajat — Guided post-prayer sequence

**Date:** 2026-08-25
**Status:** Approved design — ready for implementation plan
**Author:** Achraf Trabelsi (with Claude Code)
**Driver:** Give 1.1.0 a headline feature worth shipping, alongside the localisation and deployment-target fixes already committed (`ee36b1e`, `bd2f1cb`).

## 1. Context

1.1.0 currently carries only plumbing: an English fallback for unsupported languages, `CFBundleLocalizations` so the store lists all three languages, and a deployment target lowered from iOS 18.4 to 17.0. Real fixes, but nothing a user notices and nothing that shows on a screenshot.

The download numbers say discovery is organic and works: 28 first-time downloads in three months with no promotion, across 11 storefronts, led by Senegal (10), France (6) and the United States (4). What is missing is a reason to click on the listing, and a reason to open the app five times a day instead of twice.

**The 4.3(a) constraint.** Munajat 1.0 was rejected on 2026-05-13 as "similar binary, metadata, and/or concept" and the appeal was refused. The pivot that got the app through was substance: contextual entry by life-state, and built-in memorization. A plain digital tasbih — a big button and a number — is the single most common feature in this category and would pull the app back toward the template it was rejected for.

This design therefore does **not** add a free-form counter. It adds a *guided ritual*: the post-prayer adhkar of Hisn al-Muslim, in their canonical order, decomposed into countable steps, using the app's own content, sources and audio. The differentiator is the guidance and the fidelity to the source, not the counting.

## 2. Goals

- One feature a reviewer understands in fifteen seconds and a user reaches for five times a day.
- Reuse the existing `after_prayer_adhkar` content, its sources and its audio — no parallel content pipeline.
- Ship without touching any existing subsystem: no SwiftData migration, no navigation surgery, no change to `DhikrProgress`, `AudioPlayer` or `StreakService` internals.
- Stay correct religiously: the order of the sequence is the order of Hisn al-Muslim, not a product decision.

## 3. Non-goals

- **No free-form tasbih.** See the 4.3(a) reasoning above. If it is ever added, it should be a deliberate, separate decision.
- **No prayer times, no geolocation.** The two conditional steps are labelled, not computed. Adding prayer times invites a permission prompt and a whole subsystem for one badge.
- **No prayer selector.** Considered and dropped: it promises prayer-time awareness the app does not have.
- **No session history or statistics.** A `TasbihSession` SwiftData model was considered and rejected as YAGNI. Addable later without breaking anything.
- **No French translation of the Quranic steps.** Āyat al-Kursī and the three sūrahs need a sourced translation, not one improvised in a spec. Those steps fall back to the existing English, as the whole app does today. Tracked as follow-up.

## 4. The sequence

### 4.1 Splitting rule

The order is the JSON order of `after_prayer_adhkar`, which is the Hisn al-Muslim order. **Nothing is reordered.**

An item is split **only when the dhikr it bundles carry different repetition counts**, because a guided flow cannot count "33" against a blob that holds three formulas and a closing tahlīl. Two items qualify:

- item 1 bundles `أَسْتَغْفِرُ اللهَ` three times with the salām formula once
- item 4 bundles the three tasbihāt thirty-three times each with the tahlīl that completes the hundred

The count is what forces the split, not the number of distinct dhikr. **Item 5 is deliberately left whole** even though it holds three sūrahs: al-Ikhlāṣ, al-Falaq and an-Nās are each recited once, in immediate succession, and the JSON supplies Arabic *and* English for the three as a single unit. Splitting it would mean dividing a Quranic translation by hand, which §3 rules out — and would buy nothing, since every part would carry the same count of one.

The other six items pass through untouched.

### 4.2 The twelve steps

| # | Step | Source | Reps | Auto-advance |
|---|------|--------|------|--------------|
| 1 | `أَسْتَغْفِرُ اللهَ` | item 1, split | 3 | yes |
| 2 | `اللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ…` | item 1, split | 1 | no |
| 3 | Tahlīl — full formula | item 2, as-is | 1 | no |
| 4 | Tahlīl — with `لَا حَوْلَ وَلَا قُوَّةَ` | item 3, as-is | 1 | no |
| 5 | `سُبْحَانَ اللهِ` | item 4, split | 33 | yes |
| 6 | `الْحَمْدُ لِلَّهِ` | item 4, split | 33 | yes |
| 7 | `اللهُ أَكْبَرُ` | item 4, split | 33 | yes |
| 8 | `لَا إِلَهَ إِلَّا اللهُ وَحْدَهُ…` — completes the hundred | item 4, split | 1 | no |
| 9 | al-Ikhlāṣ, al-Falaq, an-Nās | item 5, as-is | 1 | no |
| 10 | Āyat al-Kursī | item 6, as-is | 1 | no |
| 11 | `لَا إِلَهَ إِلَّا اللهُ… يُحْيِي وَيُمِيتُ` — *after Fajr and Maghrib* | item 7, as-is | 10 | no |
| 12 | `اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا` — *after Fajr* | item 8, as-is | 1 | no |

Steps 5 to 8 total 100, which is the point of that group and is enforced by a test.

Steps 11 and 12 carry an `onlyAfter` scope. They are shown with a badge and skippable in one tap; they are never hidden, because hiding them would teach the user the sequence is shorter than it is.

### 4.3 Advancing

**Every finished step chains into the next one.** Extra taps past the target are ignored rather than counted into the next dhikr.

This replaces the original design, which used a per-step `advancesAutomatically` flag: automatic inside a group of like recitations, and an explicit confirmation wherever the nature of the dhikr changed, to mark a breath before the tahlīl formulas, the sūrahs and Āyat al-Kursī. Tested in the hand on 2026-08-27, that read as a bug rather than as a rhythm — nothing tells the user which steps will ask for a tap, so the button looked like it appeared at random. The flag, `awaitingConfirmation` and `confirmAdvance()` are all gone; the model is one state simpler for it. Only the two conditional steps keep a way out, through "Passer".

**Counting and advancing are separate operations.** `increment()` only counts; the view holds the filled ring for 320 ms and then calls `advanceIfFinished()`. The first version advanced inside the same call, which meant a single-repetition step swapped itself out before the progress ring could draw — the tap appeared to do nothing at all. The same beat now applies at 33/33, giving a pause at the end of each third.

Free navigation between steps (previous/next at will, with a count kept per step) was considered on 2026-08-27 and **declined**: the flow stays linear, each step completed in turn.

## 5. Architecture

### 5.1 Why not `DhikrProgress`

`DhikrProgress(@Attribute(.unique) itemId, count, lastUpdated)` is keyed per item and auto-resets on day change. That is correct for morning and evening adhkar, recited once a day. The post-prayer sequence is recited five times a day: reusing `DhikrProgress` would show the sequence already complete at Dhuhr because Fajr had filled it. Session state must be ephemeral, and must not touch the daily counters.

### 5.2 New files

```
Adhkar/Models/PostPrayerSequence.swift    step definition + PrayerScope
Adhkar/Models/PostPrayerSession.swift     pure session logic, no SwiftUI
Adhkar/Views/PostPrayerSessionView.swift  the guided screen
Adhkar/Views/PostPrayerCard.swift         home entry point
AdhkarTests/PostPrayerSequenceTests.swift
```

`PostPrayerStep` carries: `id`, an optional `itemId` linking to the JSON item for source, long translation and audio, its own `arabic` when split, `transliteration` and `translation` as `LocalizedText`, `repetitions`, `advancesAutomatically`, and `onlyAfter`.

`PostPrayerSession` is a plain type with `currentStep`, `increment()`, `skip()`, `confirmAdvance()`, `isComplete` and a `Codable` snapshot. It follows `HifzScheduler`: all logic outside the view, fully unit-testable.

### 5.3 The screen

Presented as a `fullScreenCover` from Home — on macOS, where that modifier does not exist, a `sheet`. One step at a time: Arabic in Amiri, transliteration, `n / N`, and a large tap area.

**The counter is pinned below the scroll view, outside it.** Card heights run from two words for `سُبْحَانَ اللهِ` to the whole of Āyat al-Kursī, and a counter laid out under the card travelled roughly a thousand points between steps — far enough to leave the screen entirely. Only the text scrolls. The counter also carries an identity per step, so the ring is replaced on a step change rather than animated backwards from full to empty, and a short guard swallows taps during the cross-fade so a double tap cannot skip a dhikr. `.sensoryFeedback(.impact, trigger:)` per tap, `.success` on step change. Below, the list of twelve steps with a check on those done — that list is what makes it read as a guided ritual rather than a counter, and it is what the App Store screenshot will show. A global progress bar on top, a close button, and access to the full JSON item (source, English translation, audio) through `itemId`.

`AudioPlayer` is reused unchanged.

### 5.4 State

The view holds the session in `@State`, with the `Codable` snapshot mirrored to `@SceneStorage` so backgrounding mid-hundred does not lose progress. No SwiftData model, no schema change, no App Group involvement.

On completion, one call: `streak.recordDhikrCompleted(context: modelContext)`. The sequence feeds the existing streak like any completed dhikr.

### 5.5 Entry point

`PostPrayerCard` on `HomeView`, built on the `HomeContextCard` pattern: injected action, orange gradient circle, title and hint, chevron; `HomeView` owns the presentation state. Symbol `hands.and.sparkles.fill`.

The deep link `munajat://tasbih` is registered next to the existing `munajat://category/<id>` in `AdhkarApp.onOpenURL`, so a future widget can route straight into the sequence. No widget change in this version.

## 6. Constraints observed

No `import UIKit`. `#if os(iOS) || os(visionOS)` around iOS-only modifiers. `Color("CardBackground")` rather than semantic UIKit colours. New UI strings as static `LocalizedText` in `L10n.swift`.

The six split steps get hand-written French, which makes them the first French content in an app whose 294 items currently have none.

## 7. Testing

`AdhkarTests/PostPrayerSequenceTests.swift`, Swift Testing, written before the implementation:

- the sequence has twelve steps, in the JSON order
- every referenced `itemId` exists in `adhkar.json` — this is the guard that fails loudly if `build_adhkar.py` regenerates content and changes ids
- steps 5 to 8 total exactly 100
- `increment()` advances only at `repetitions`, never before, and ignores taps past the target
- a step with `advancesAutomatically == false` waits for `confirmAdvance()`
- `skip()` moves past a conditional step without corrupting progress
- a finished session reports `isComplete`
- the `Codable` snapshot round-trips faithfully

## 8. Decisions taken during design

| Question | Decision |
|---|---|
| Free counter, dhikr-backed counter, or guided sequence? | Guided sequence — the only option that does not regress the 4.3(a) differentiation |
| Three tasbihāt only, or the full Hisn sequence? | Full sequence, twelve steps |
| Prayer selector? | No — promises prayer times the app lacks |
| Where does it live? | Card on Home; the five tab slots are full and a sixth would create a "More" overflow |
| Session persistence? | Ephemeral plus `@SceneStorage`; no SwiftData model |
| Auto-advance? | Per-step: automatic inside a group, explicit where the dhikr changes |
