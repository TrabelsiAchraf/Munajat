# Release notes — What's New

One folder per version. Each holds one plain-text file per App Store
localisation, using the same short codes as `marketing/out/` and
`marketing/raw/`: `fr` (primary), `en`, `ar`.

The files are paste-ready: no markdown, no wrapper, nothing to strip. Copy
one into App Store Connect → App Store → Version → What's New in This
Version, for the matching language. The field takes 4000 characters.

```
marketing/release-notes/
  1.1.0/
    fr.txt   ← primary
    en.txt
    ar.txt
    NOTES.md ← why the copy is worded this way; not for the store
```
