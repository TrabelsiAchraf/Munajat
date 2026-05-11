# Munajat — Dhikr & Dua

> **مناجاة** — intimate prayer, whispered remembrance of Allah.

A personal SwiftUI app for daily Islamic adhkar (remembrances) — morning, evening, sleep, prayer, travel, and more. Built around the *Hisn al-Muslim* corpus with Arabic text, translations, audio recitations and per-item counters.

Targets **iOS 18.4 / macOS 15.4 / visionOS** from a single codebase.

---

## Screenshots

<p align="center">
  <img src="docs/screenshots/home.png"      width="210" alt="Home" />
  <img src="docs/screenshots/detail.png"    width="210" alt="Dhikr detail" />
  <img src="docs/screenshots/favorites.png" width="210" alt="Favorites" />
  <img src="docs/screenshots/settings.png"  width="210" alt="Settings" />
</p>

<p align="center"><sub>Home · Dhikr detail with counter · Favorites · Settings</sub></p>

---

## Features

- **133 categories / ~294 items** from *Hisn al-Muslim* (rn0x + wafaaelmaandy sources)
- **Trilingual UI**: Arabic, French, English — switchable at launch via `AppleLanguages`
- **Streaming audio** for each dhikr (hisnmuslim.com), upgraded to HTTPS at play time to clear iOS ATS
- **Per-item counters** persisted with SwiftData, auto-reset on day change
- **Per-category progress bar** at the top of each dhikr screen, live-updated as counters reach their targets
- **Completion celebration**: once-per-day overlay with "ما شاء الله", gold halo, sparkles and success haptic when every dhikr in a category is done
- **Daily streak**: SwiftData history of opens + best-record tracking, surfaced on the home screen and the widget
- **Home-screen widget** (iOS) — small + medium, shows the suggested dhikr for the current time of day and the live streak count, tap → deep-links into the right category via `munajat://`
- **Share dhikr as image**: each detail view exports a 1080×1920 PNG card (gradient + crescent pattern + Amiri body + translation + footer) via `ImageRenderer` + a `Transferable` wrapper, no UIKit
- **Favorites** with UserDefaults migration from the legacy per-key Bool format
- **Daily reminders** (morning / evening / sleep) via `UNCalendarNotificationTrigger`
- **Time-aware home**: surfaces the right category for the current hour as a featured card
- **Accessibility**: every interactive element has a localized `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityValue`; decorative patterns hidden from VoiceOver
- **Privacy-first**: zero analytics, zero tracking, App Sandbox + minimal entitlements (App Group only for app↔widget streak sharing)
- **Custom Arabic typography**: Amiri Regular/Bold for body, AmiriQuran for verses (full diacritics, registered at runtime via `CTFontManager`)
- **Islamic visual language**: gold crescents + 8-point stars over a deep-navy theme, drawn with `Canvas` and `Path.subtracting` for clean shapes

## Tech stack

- **SwiftUI** with `@Observable` state, `NavigationStack`, `TabView`
- **SwiftData** for the dhikr counter and the daily streak history
- **WidgetKit** with a `TimelineProvider` rotating at 04:00 / 12:00 / 19:00 local
- **App Group** (`group.com.tadevv.Munajat`) UserDefaults suite so the widget reads streak data without spinning up SwiftData
- **Deep linking** via `munajat://category/<id>` (`onOpenURL` → lifted `NavigationPath`)
- **AVFoundation** for audio streaming with `.spokenAudio` session
- **CoreText** for runtime font registration (no `UIAppFonts` in Info.plist)
- **UserNotifications** for daily reminders
- **ImageRenderer + Transferable** for sharing dhikr cards as PNG, cross-platform
- Cross-platform: no `import UIKit`, asset-catalog colors instead of `UIColor.secondarySystemBackground`, `.sensoryFeedback` instead of `UIImpactFeedbackGenerator`, iOS-only modifiers wrapped behind `#if os(iOS) || os(visionOS)`

## Architecture highlights

- **Xcode 26 synchronized folders** (`PBXFileSystemSynchronizedRootGroup`): any file dropped in `Adhkar/` or `MunajatWidget/` auto-bundles
- **Two-target project** wired entirely via the `xcodeproj` Ruby gem (see `scripts/setup_widget_target.rb`, `scripts/share_files_with_widget.rb`) — no manual pbxproj editing. Shared source files are attached to the widget via a `PBXFileSystemSynchronizedBuildFileExceptionSet` so they aren't duplicated.
- **Widget embed is iOS-only**: a `platformFilter` on the "Embed Foundation Extensions" build file keeps macOS / visionOS builds from choking on the iOS-only widget.
- **URL scheme injection without rebuilding Info.plist**: `Adhkar-SupportingFiles/Adhkar-URLTypes.plist` is set as `INFOPLIST_FILE` while `GENERATE_INFOPLIST_FILE = YES` stays on — Xcode 14+ merges the custom keys into the generated file.
- **Single accent color** (orange) across every section to keep the visual language coherent
- **`LocalizedText`** reads `UserDefaults` `AppleLanguages` rather than `Locale.current`, so launch flags (`-AppleLanguages "(fr)"`) and per-app language settings are honored
- **Crescent shapes** use `Path.subtracting(_:)` (iOS 16+) instead of the naive `addEllipse + eoFill` ring which notches when the inner disk sticks out of the outer
- **Streak day boundaries** use `Calendar(identifier: .gregorian)` explicitly so devices set to a Hijri locale don't reshuffle the day window

## Build & run

The project ships with `.mcp.json` configured for [XcodeBuildMCP](https://github.com/xcode-build-mcp/xcodebuildmcp) — preferred over raw `xcodebuild` for build / install / launch / screenshot / unit tests.

Fallback raw command:

```bash
xcodebuild -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

A booted simulator can be launched with:

```bash
SIM_ID=$(xcrun simctl create "Test" "iPhone 16" "com.apple.CoreSimulator.SimRuntime.iOS-18-5")
xcrun simctl boot $SIM_ID
xcrun simctl install $SIM_ID path/to/Adhkar.app
xcrun simctl launch $SIM_ID com.tadevv.Adhkar
# Force language at launch
xcrun simctl launch $SIM_ID com.tadevv.Adhkar -AppleLanguages "(fr)" -AppleLocale "fr_FR"
```

## Content generation

The bundled `Adhkar/adhkar.json` is regenerated from upstream sources:

```bash
# Needs /tmp/hisn_ar.json (rn0x/hisn_almuslim_json) and /tmp/husn_en.json (wafaaelmaandy)
python3 scripts/build_adhkar.py

# App icon (iOS light/dark/tinted + every macOS resolution)
python3 scripts/make_icon.py
```

The merge uses two-phase Jaccard matching on token sets (chapter → chapter, then item → item) — coverage went from ~48 % in the V1 prefix matcher to **94–95 %**.

## Project layout

```
Adhkar/                          # Main app sources (auto-bundled via synchronized folder)
  Resources/                     # adhkar.json corpus + Amiri TTFs + Assets.xcassets
MunajatWidget/                   # iOS widget extension (synchronized folder)
MunajatWidget-SupportingFiles/   # Widget Info.plist + entitlements (outside sync group)
Adhkar-SupportingFiles/          # Main app Info.plist merge file (CFBundleURLTypes)
scripts/
  build_adhkar.py                # Hisn al-Muslim merger
  make_icon.py                   # Icon renderer
  setup_widget_target.rb         # Idempotent widget-target wiring via xcodeproj gem
  share_files_with_widget.rb     # Attach shared source files to the widget target
CLAUDE.md                        # Project guide (architecture, gotchas, conventions)
```

## Credits

- **Hisn al-Muslim** by Sa'id bin Ali bin Wahaf al-Qahtani — the source corpus
- [rn0x/hisn_almuslim_json](https://github.com/rn0x/hisn_almuslim_json) — Arabic text, audio URLs, sources
- [wafaaelmaandy/Hisn-Muslim-Json](https://github.com/wafaaelmaandy/Hisn-Muslim-Json) — English translations
- [Amiri font](https://github.com/aliftype/amiri) by Khaled Hosny — Arabic typography
- Audio hosted by hisnmuslim.com

## Status

Personal project, getting close to App Store submission. Built across seven explicit phases (bug fixes → JSON migration → content import → UX redesign → SwiftData/audio → notifications/i18n → polish/icon), then a store-readiness pass (streak, share-as-image, accessibility, privacy links, macOS cross-platform fixes), Phase 0/4 (Widget Extension + `munajat://` deep links wired via the `xcodeproj` Ruby gem) and finally a completion progress bar + celebration overlay. Open items before submission: hosting the privacy/support pages, registering the App Group in the Developer Portal, capturing App Store screenshots (iPhone 6.9" + iPad 13" × AR/FR/EN), and writing the listing copy.
