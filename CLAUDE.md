# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Personal iOS SwiftUI app showing Islamic adhkar (daily remembrances). Single Xcode project, no Swift Package or external dependencies. Targets iOS 18.4 / macOS 15.4 / visionOS — code must compile for **all three** platforms.

## Build & run

**Always use the XcodeBuildMCP tools** for any Xcode-side work — build, run, install/launch on simulator or device, unit tests, screenshots, UI automation, log capture, scheme/sim listing. Do **not** fall back to `xcodebuild` / `xcrun simctl` shell commands when an MCP equivalent exists.

Typical flow:
1. `session_show_defaults` once per session to confirm project / scheme / simulator are set (use `session_set_defaults` to configure them — defaults here: project `Adhkar.xcodeproj`, scheme `Adhkar`, bundle ID `com.tadevv.Adhkar`).
2. `build_run_sim` to build + install + launch in one call.
3. `screenshot` for visual checks, `snapshot_ui` for view-hierarchy + coordinates, `test_sim` for unit tests, `record_sim_video` / log capture as needed.
4. Use `discover_projs` / `list_schemes` / `list_sims` only if defaults are missing or wrong.

Fallback raw commands (only if MCP unavailable):

```bash
xcodebuild -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

No test target exists yet — adding one requires Xcode UI (File → New → Target) because the `.pbxproj` is fragile to edit by hand.

## Regenerating content & assets

```bash
# Hisn al-Muslim JSON (Arabic + English translations + audio URLs + sources)
python3 scripts/build_adhkar.py
# Output: Adhkar/adhkar.json (133 categories, ~294 items)

# App icon (light/dark/tinted iOS variants + macOS resolutions)
python3 scripts/make_icon.py
```

`build_adhkar.py` requires two source files in `/tmp/`:
- `/tmp/hisn_ar.json` from `rn0x/hisn_almuslim_json`
- `/tmp/husn_en.json` from `wafaaelmaandy/Hisn-Muslim-Json` (UTF-8 BOM, decode with `utf-8-sig`)

Matching is two-phase Jaccard on token sets (chapter→chapter, then item→item). The brittle 60-char prefix matching from V1 is gone — coverage went from ~48% to 94-95%.

## Architecture (non-obvious bits)

### Synchronized folders (Xcode 16+)
The project uses `PBXFileSystemSynchronizedRootGroup`. **Any file dropped in `Adhkar/` auto-bundles** as either source or resource based on extension. Don't edit `project.pbxproj` to add files — drop them in and they appear.

### Cross-platform constraints (iOS + macOS + visionOS)
- **No `import UIKit`** — fails on macOS native (`SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx xros xrsimulator`).
- Use `.sensoryFeedback(.impact, trigger:)` instead of `UIImpactFeedbackGenerator`.
- Use `Color("CardBackground")` (asset catalog) instead of `Color(.secondarySystemBackground)`.
- For iOS-only APIs (e.g. `AVAudioSession`), guard with `#if canImport(UIKit) && os(iOS)`.

### Asset symbols collide with manual statics
Xcode 16 auto-generates `Color.cardBackground` from `Assets.xcassets/CardBackground.colorset`. **Never redeclare** `static let cardBackground` in `Color+Extension.swift` — it produces `error: invalid redeclaration`. The asset is the source of truth (white in light, deep navy in dark).

### Font registration is runtime, not Info.plist
`INFOPLIST_KEY_UIAppFonts` is NOT one of the Xcode-mapped Info.plist keys, so adding it to build settings has no effect. We register fonts at app launch via `FontRegistrar.registerBundledFonts()` (CoreText `CTFontManagerRegisterFontsForURL`). Three bundled TTFs: `Amiri-Regular`, `Amiri-Bold`, `AmiriQuran` (the last is tuned for Quranic verses with full diacritics).

### Data flow
`Adhkar/adhkar.json` (bundled) → `DataProvider.loadCategoriesThrowing(from:)` parses to `[AdhkarCategory]` via `Codable` → `static let adharCategories` holds the result, sorted by `order`. Decode failure triggers `assertionFailure` in Debug.

JSON schema highlights:
- `AdhkarType` enum is `String` raw-valued; case names match JSON `type` strings.
- `Adhkar` struct uses `CodingKeys` to map `arabic ↔ dhikr` and `items ↔ adhkarList` (Swift property names stayed for backward compatibility, JSON uses cleaner names).
- Sources live in `item.source` (Arabic, from `rn0x` footnotes). Some are clean refs (`البخاري 11/113`), some are narration intros — that's a known content limitation.

### Localization
`LocalizedText` (struct with optional `ar`/`fr`/`en`) is the workhorse. `resolved(for:)` reads `UserDefaults.standard.array(forKey: "AppleLanguages")` — **not `Locale.current`** — so launch args (`-AppleLanguages "(fr)"`) and per-app language settings are honored. UI strings live in `L10n.swift` as a flat enum of static `LocalizedText`. No `.xcstrings` file.

### Audio
`AudioPlayer` (`@Observable`) streams `http://hisnmuslim.com/...` URLs but **upgrades them to HTTPS at play time** to clear iOS ATS. Calls `AVAudioSession.setCategory(.playback, mode: .spokenAudio)` so audio plays even on silent. `stop()` discards the player entirely (next play starts at zero); used on screen dismiss and dhikr-page swipe via `onChange(of: selectedIndex)`.

### Persistence
- **Counters**: SwiftData `DhikrProgress(@Attribute(.unique) itemId, count, lastUpdated)`. Auto-reset on day change via `Calendar.current.isDateInToday(lastUpdated)` check in `DhikrPageView.onAppear`.
- **Favorites**: `FavoritesStore` (`@Observable`) backed by `UserDefaults` array under key `favoriteCategoryIds`. Migrates legacy `favorite_<id>` Bool keys from Phase 1.
- **Notification prefs**: `NotificationManager` persists per-slot enable + hour/minute in `UserDefaults`.

### Visual language
- **Forced dark mode**: `RootTabView` has `.preferredColorScheme(.dark)`. Light-mode code paths in `AdaptiveBackground` still exist but are dead — keep them for now in case the user toggles back.
- **Single accent color**: every section uses `.orange` (returned from `AdhkarSection.accentColor`). Earlier per-section colors are gone — don't reintroduce them.
- **Tab tint**: `.tint(.orange)` on `RootTabView`'s `TabView`.
- **Pattern**: `CrescentStarPattern` (gold metallic crescents + 5-point stars, `Path.subtracting()` for the crescent shape) drawn via `Canvas`. Applied as background **only** on home and dhikr-detail (`AdaptiveBackground(decorated: true)`); Favorites/Search/Settings stay quiet. Static — no animation.

### Important gotchas
- The naive crescent `addEllipse + addEllipse + eoFill` produces a ring with a notch if the inner disk sticks out of the outer (`innerR + offset > outerR`). Use `Path.subtracting(_:)` (iOS 16+) for proper boolean subtraction.
- `Calendar.current` may be a non-Gregorian calendar on user devices (Islamic locale). For hour-of-day comparisons that drive UI logic (e.g. featured-card time window), explicitly use `Calendar(identifier: .gregorian)`.
- `AdhkarSection` cases used in JSON section field must match the Swift enum cases. New section = update both.
- `AdhkarType` enum has ~144 cases but only 133 have entries in `TYPE_TO_TITLE` (the manual map in `scripts/build_adhkar.py`). The extra 11 cases produce icons but no JSON content — they're invisible in the grid until added to the script's mapping.

### Phase history
The app went through 7 explicit phases (bug fixes → JSON migration → content import → UX refonte → SwiftData/audio → notifications/i18n → polish/icon). The plan file under `~/.claude/plans/` references these phases and the rationale for each architectural choice.
