# 1.1.0 — notes on the copy

**Version:** 1.1.0
**Build:** 270820261735
**Uploaded to TestFlight:** 2026-08-27

Lengths: fr 681, en 618, ar 482 characters. The App Store field takes 4000.

**Voice:** informal second person in French (*tu*), matching
`marketing/config/store_listing.md` and the in-app strings in `L10n.swift`.
The first draft used *vous* and had to be redone — check the listing before
writing new copy.

## Why it is worded this way

**Guideline 4.3(a).** Version 1.0 was rejected on 2026-05-13 as sharing a
concept with other Hisn al-Muslim apps, and the appeal was refused on
2026-05-15. What got the app through was substance: contextual entry by
life-state, and built-in memorization.

So the copy leads with **the guided sequence and its fidelity to the
source** — the twelve invocations in their traditional order, each with its
text, transliteration, source and recitation. It never says "counter" or
"tasbih". A digital tasbih is the single most common feature in this
category, and describing the feature that way invites exactly the comparison
that got 1.0 rejected.

## What is deliberately not claimed

Prayer times, notifications tied to prayer times, offline audio, iCloud
sync, Apple Watch. None of that shipped in 1.1.0.

## What is left out to keep it short

Steps 11 and 12 of the sequence are recited only after Fajr, and step 11
after Maghrib as well. They are labelled in the app and can be skipped in one
tap. The release notes do not mention the distinction.

**Bugs are not itemised.** An earlier draft listed the language fallback and
the App Store language row as two separate bullets. Users do not read
changelogs to learn what was broken — "a language display bug, plus a few
improvements" carries everything they need. Keep future notes this short.

## Order and framing of the bullet points

The iOS 17 line comes first: it is the only change that decides whether
someone can install the app at all.

It is framed as an invitation, not as a chore. "No need to update your
iPhone" puts the work on the reader; "Your iPhone can't run iOS 18? We're not
leaving you behind" says the app came to them. That matters for this app in
particular — the download numbers lead with Senegal, Congo and Egypt, where
devices are kept for years and the reader is more likely to be on the old
side of that line.
