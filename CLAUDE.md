# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Personal iOS SwiftUI app showing Islamic adhkar (daily remembrances). Single Xcode project, no Swift Package or external dependencies. Two targets: the main `Adhkar` app (iOS / macOS / visionOS — code must compile for **all three** platforms) and a `MunajatWidget` Widget Extension (iOS-only).

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

There **is** a test target: `AdhkarTests`, using Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`). Its Xcode group is a plain `PBXGroup`, **not** a synchronized one, so a new test file is not picked up automatically — run `ruby scripts/sync_test_sources.rb` after adding one (idempotent; also prunes references to deleted files).

Adding new Xcode targets is fragile to do by hand on the pbxproj — use the `xcodeproj` Ruby gem (already used for the widget setup; see `scripts/setup_widget_target.rb` and `scripts/share_files_with_widget.rb`). The same gem is the right tool for bulk build-setting edits such as deployment targets or version bumps.

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

### Synchronized folders (Xcode 26+)
The project uses `PBXFileSystemSynchronizedRootGroup`. **Any file dropped anywhere under `Adhkar/` auto-bundles** as either source or resource based on extension — the walk is recursive. Don't edit `project.pbxproj` to add files or folders — drop them in and they appear.

### Source layout
```
Adhkar/                          ← main app target (synchronized root group)
  Adhkar.entitlements            ← app sandbox + App Group group.com.tadevv.Munajat
  PrivacyInfo.xcprivacy          ← stays at root by convention
  App/                           Entry point + root tab navigation + deep-link routing
  Models/                        Pure data types (AdhkarCategory/Type/Section, LocalizedText,
                                 DhikrProgress, DailyActivity)
  Services/                      DataProvider, AudioPlayer, FavoritesStore,
                                 NotificationManager, StreakService
  Localization/                  L10n.swift
  Views/                         SwiftUI screens + ShareableDhikrCard + StreakCard +
                                 CompletionOverlay
  Design/                        Visual primitives (colors, fonts, patterns, button styles,
                                 decorative backgrounds)
  Resources/                     adhkar.json, Amiri TTFs, Assets.xcassets

MunajatWidget/                   ← Widget Extension target (iOS-only, synchronized root group)
  MunajatWidgetBundle.swift      @main + FontRegistrar call so the widget process has Amiri
  CurrentPeriodWidget.swift      Timeline provider, small + medium layouts

MunajatWidget-SupportingFiles/   ← outside the sync group on purpose (Info.plist would
                                   collide as a resource otherwise)
  Info.plist                     NSExtensionPointIdentifier = widgetkit-extension +
                                 CFBundle* template keys
  MunajatWidget.entitlements     App Group group.com.tadevv.Munajat

Adhkar-SupportingFiles/          ← INFOPLIST_FILE merge on the main app
  Adhkar-URLTypes.plist          CFBundleURLTypes for munajat:// — merges with the
                                 auto-generated Info.plist when GENERATE_INFOPLIST_FILE = YES
```
Drop new files in the matching subfolder of either `Adhkar/` or `MunajatWidget/` — the synchronized root group picks them up automatically. Files in `*-SupportingFiles/` are referenced explicitly via build settings (no synced group).

### Cross-platform constraints (iOS + macOS + visionOS)
- **No `import UIKit`** — fails on macOS native (`SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx xros xrsimulator`).
- Use `.sensoryFeedback(.impact, trigger:)` instead of `UIImpactFeedbackGenerator`.
- Use `Color("CardBackground")` (asset catalog) instead of `Color(.secondarySystemBackground)`.
- For iOS-only APIs (e.g. `AVAudioSession`), guard with `#if canImport(UIKit) && os(iOS)`.
- **iOS-only SwiftUI modifiers** need `#if os(iOS) || os(visionOS)`: `.searchable(placement: .navigationBarDrawer(...))`, `TabView.tabViewStyle(.page)`, `.indexViewStyle(.page(...))`, `.navigationBarTitleDisplayMode(.inline)`. `ToolbarItemPlacement.topBarTrailing` is also iOS-only — use `.primaryAction` instead for the cross-platform path.
- **Image rendering for share** uses `ImageRenderer.cgImage` + `Image(decorative:scale:orientation:)` + a `Transferable` PNG wrapper (`ShareableDhikrImage`). No `UIImage` / `UIActivityViewController`.

### Asset symbols collide with manual statics
Xcode 26 auto-generates `Color.cardBackground` from `Assets.xcassets/CardBackground.colorset`. **Never redeclare** `static let cardBackground` in `Color+Extension.swift` — it produces `error: invalid redeclaration`. The asset is the source of truth (white in light, deep navy in dark).

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
- **Streak history**: SwiftData `DailyActivity(@Attribute(.unique) dayKey, itemsRead, firstOpen)`. `dayKey` is `yyyy-MM-dd` in `Calendar(identifier: .gregorian)` + local TZ so device-set Islamic locales don't reshuffle the day boundaries.
- **Streak counters**: `StreakService` (`@Observable @MainActor`) mirrors `currentStreak` / `bestStreak` to `UserDefaults(suiteName: "group.com.tadevv.Munajat")` (App Group) so the widget can read without spinning up SwiftData. Calls `WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPeriodWidget")` after each recompute. The init takes a `nonisolated static func makeSharedDefaults()` default — keep that pattern when reading the suite from non-actor contexts.
- **Celebration shown**: per-category `celebration.lastShown.<categoryId>` timestamp in `UserDefaults.standard` — used by `AdhkarDetailsView` to fire the completion overlay at most once per day per category.

### Guided post-prayer sequence (1.1.0)
- `PostPrayerSequence` is static step data, not JSON: it references items of the `after_prayer_adhkar` category by id for source, translation and audio, and carries its own Arabic only for the steps split out of a bundled item. An item is split **only when the dhikr it bundles carry different repetition counts** — items 1 and 4. Item 5 holds three sūrahs but each is recited once and the JSON supplies them as one unit, so it stays whole. The order is the JSON's, which is Hisn al-Muslim's; do not reorder.
- `PostPrayerSession` is a plain value type holding all progression logic, like `HifzScheduler` — no SwiftUI, fully unit-tested. `increment()` only counts; the view holds the filled ring 320 ms then calls `advanceIfFinished()`. Splitting the two is deliberate: doing both in one gesture meant a single-repetition step swapped out before the ring drew.
- **Not backed by `DhikrProgress`.** That model is keyed per item and resets on day change — right for morning/evening adhkar, wrong for a sequence recited after all five prayers, which would show as already complete at Dhuhr. Session state is `@State` plus a `@SceneStorage` snapshot; no SwiftData model, no migration.
- The counter is pinned **outside** the ScrollView. Card heights run from two words to all of Āyat al-Kursī, and a counter laid out under the card travelled ~1000 points between steps.
- A test asserts every referenced `itemId` exists in `adhkar.json` — the guard that fails loudly if `build_adhkar.py` renumbers items.
- `-MarketingScreen post_prayer` opens the screen for screenshot capture. It is the only headless way in: `simctl` cannot tap, and iOS 26 blocks custom-scheme URLs from outside the app behind an undismissable confirmation.

### Visual language
- **Forced dark mode**: `RootTabView` has `.preferredColorScheme(.dark)`. Light-mode code paths in `AdaptiveBackground` still exist but are dead — keep them for now in case the user toggles back.
- **Single accent color**: every section uses `.orange` (returned from `AdhkarSection.accentColor`). Earlier per-section colors are gone — don't reintroduce them.
- **Tab tint**: `.tint(.orange)` on `RootTabView`'s `TabView`.
- **Pattern**: `CrescentStarPattern` (gold metallic crescents + 5-point stars, `Path.subtracting()` for the crescent shape) drawn via `Canvas`. Applied as background **only** on home and dhikr-detail (`AdaptiveBackground(decorated: true)`); Favorites/Search/Settings stay quiet. Static — no animation.

### Widget extension
- iOS-only target, lives in `MunajatWidget/` (synced source) + `MunajatWidget-SupportingFiles/` (Info.plist + entitlements outside the sync group so the build system doesn't double-process them as resources).
- `MunajatWidgetBundle` is `@main` and re-runs `FontRegistrar.registerBundledFonts()` in its `init` (widget extensions are a separate process from the host app, so the app's launch-time registration doesn't reach them).
- `CurrentPeriodWidget` uses a `TimelineProvider` that emits entries at next 04:00 / 12:00 / 19:00 transitions, matching `AdhkarType.forCurrentHour(now:)`. Reads `streak.current` from the App Group suite.
- Embedded into the main app via "Embed Foundation Extensions" copy phase with a **platform filter** restricted to iOS so macOS/visionOS builds don't fail trying to embed the iOS-only extension. Without that filter the macOS build errors with "embedded content built for the iOS platform".
- Source files **shared** with the widget target (models, services, L10n, fonts, JSON, design helpers) are NOT duplicated — they're listed in a `PBXFileSystemSynchronizedBuildFileExceptionSet` attached to the `Adhkar/` sync group with `target = MunajatWidget`. Edit the list via `scripts/share_files_with_widget.rb`.

### URL scheme + deep linking
- The app registers the scheme `munajat://` for tap-from-widget deep links. `CFBundleURLTypes` lives in `Adhkar-SupportingFiles/Adhkar-URLTypes.plist`, set as `INFOPLIST_FILE` while `GENERATE_INFOPLIST_FILE = YES` stays on — Xcode 14+ **merges** the custom keys into the generated Info.plist. (A `Run Script` phase using PlistBuddy was tried first and blocked by `ENABLE_USER_SCRIPT_SANDBOXING`; the merge approach is what works.)
- Routing: widget `widgetURL(URL("munajat://category/<id>"))` → `AdhkarApp.onOpenURL` parses scheme/host/path → sets `@State pendingDeepLinkCategoryId` → `RootTabView.onChange` switches to `.home` tab, resets `homePath` to `NavigationPath()`, then `.append(category)`. The path is reset before append so repeated widget taps don't stack duplicates.

### Important gotchas
- The naive crescent `addEllipse + addEllipse + eoFill` produces a ring with a notch if the inner disk sticks out of the outer (`innerR + offset > outerR`). Use `Path.subtracting(_:)` (iOS 16+) for proper boolean subtraction.
- `Calendar.current` may be a non-Gregorian calendar on user devices (Islamic locale). For hour-of-day comparisons that drive UI logic (e.g. featured-card time window) AND for streak/celebration day keys, explicitly use `Calendar(identifier: .gregorian)`.
- `AdhkarSection` cases used in JSON section field must match the Swift enum cases. New section = update both.
- `AdhkarType` enum has ~144 cases but only 133 have entries in `TYPE_TO_TITLE` (the manual map in `scripts/build_adhkar.py`). The extra 11 cases produce icons but no JSON content — they're invisible in the grid until added to the script's mapping.
- `AdhkarDetailsView.body` is **dense** — modifiers extracted into named computed properties (`baseContent`, `resetToolbarItem`, `celebrationOverlay`) to keep SourceKit's type-checker under 7s. Adding more chained modifiers directly to the body brings back the "unable to type-check this expression in reasonable time" warning.

### Phase history
The app went through 7 explicit phases (bug fixes → JSON migration → content import → UX refonte → SwiftData/audio → notifications/i18n → polish/icon), then a store-readiness pass (streak + share-as-image + a11y + privacy/support links + macOS cross-platform fixes), then Phase 0/4 (Widget Extension via `xcodeproj` gem + deep linking), then completion progress bar + celebration overlay. The plan file under `~/.claude/plans/` references these phases and the rationale for each architectural choice.
