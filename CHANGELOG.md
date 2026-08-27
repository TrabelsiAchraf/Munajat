# Changelog

Notable changes per release. The user-facing wording lives in
`marketing/release-notes/<version>/`; this file is for whoever works on the
code.

## 1.1.0 — build 270820261735 — 2026-08-27

On TestFlight 2026-08-27. Awaiting App Review.

### Added

- **Guided post-prayer sequence.** The twelve post-salām adhkar of Hisn
  al-Muslim, walked step by step, each with its own counter. Entered from a
  card on Home or via `munajat://tasbih`. Completion feeds the existing
  streak.
  Design: `docs/superpowers/specs/2026-08-25-post-prayer-guided-sequence-design.md`
  Plan: `docs/superpowers/plans/2026-08-25-post-prayer-guided-sequence.md`
- `CFBundleLocalizations = [en, fr, ar]` in the app's Info.plist, so the App
  Store product page and the per-app language setting in Settings finally
  know the app is trilingual.
- `-MarketingScreen post_prayer` slug, so the new screen can be captured by
  `scripts/make_screenshots.py`.

### Changed

- Deployment targets lowered: iOS 18.4 → **17.0**, macOS 15.4 → 14.0,
  visionOS 2.4 → 1.0. 18.4 was the Xcode default at project creation, not a
  requirement — the project builds clean at 17.0 with no availability
  diagnostics. iOS 17 supports the same devices as 18, so this adds users who
  have not updated, not new hardware. Going below 17 would mean dropping
  SwiftData (17 files), `@Model` and `@Observable`.

### Fixed

- Unsupported languages fell back to Arabic. `LocalizedText.resolved(for:)`
  only had cases for `fr` and `en`, so a Turkish, Indonesian, Urdu or Malay
  device showed an Arabic interface. English is now the default.
- `fullScreenCover` is unavailable on macOS, which broke that build for three
  commits. Guarded with `#if os(iOS) || os(visionOS)`, `.sheet` elsewhere.

### Design decisions worth not undoing

Three interaction designs were tried; only the third survived hand-testing.
All are recorded in the spec with their rationale.

1. A per-step confirmation button, meant to mark a breath where the nature of
   the dhikr changes, **read as a bug** — nothing tells the user which steps
   will ask. Removed; every finished step chains.
2. The counter laid out under the step card **travelled ~1000 points**
   between steps, because card heights run from two words to the whole of
   Āyat al-Kursī. It is now pinned below the scroll view.
3. Counting and advancing had to be **split** (`increment()`, then
   `advanceIfFinished()` after a 320 ms hold): doing both in one gesture meant
   a single-repetition step swapped itself out before the progress ring could
   draw, so the tap looked inert.

Also declined: free previous/next navigation between steps, and a free-form
tasbih counter. The latter is a standing non-goal — 1.0 was rejected under
guideline 4.3(a) for resembling other Hisn al-Muslim apps, and a big button
with a number is the most generic feature in the category.

### Note on verification

The test suite (43 tests) covers the logic and caught nothing in the list
above. Every interaction defect was found by tapping the build. `simctl`
cannot tap, and iOS 26 puts an undismissable system confirmation in front of
custom-scheme URLs opened from outside the app, so headless verification
reaches the render and stops there. Test the build by hand before shipping.

## 1.0.0 — build 2 — 2026-05-18

First public release, after build 1 was rejected under guideline 4.3(a) on
2026-05-13 (appeal refused 2026-05-15) as sharing a concept with other Hisn
al-Muslim apps. Build 2 answered that with two structural features rather
than cosmetic differentiation:

- **Contextual home** — 15 life-state contexts (8 emotions, 7 trials)
  surfacing 3 to 7 curated dhikr each, from 69 manually curated
  dhikr-to-context associations.
- **Memorization** — per-dhikr Hifz cards on a simplified SM-2 spaced
  repetition schedule, with a review session and four self-rating levels.

Design and plan: `docs/superpowers/specs/2026-05-17-context-home-and-memorization-design.md`,
`docs/superpowers/plans/2026-05-17-context-home-and-memorization.md`.

Also in 1.0: 294 public-domain invocations from Hisn al-Muslim in AR/FR/EN
with RTL, audio per dhikr, tap-to-count with daily reset, daily streak,
share-as-image, Home Screen widget with `munajat://` deep linking,
Amiri typography, dark mode only, fully on-device.
