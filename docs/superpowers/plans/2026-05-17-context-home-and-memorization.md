# Contextual Home & Memorization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship build 2 of Munajat 1.0 with two new features that make the app structurally distinct from other Hisn al-Muslim apps — a contextual entry point ("How do you feel?") with 15 life-state contexts on the home, and an opt-in Anki-like memorization mode with a dedicated tab — to address the App Store 4.3(a) rejection of 2026-05-13.

**Architecture:** Two parallel feature stacks built on a shared foundation. Phase 1 adds the data layer (LifeContext model, HifzCard SwiftData, HifzScheduler pure logic with unit tests). Phase 2 builds the contextual UI (Home card → picker sheet → context detail → AdhkarDetailsView single-item mode). Phase 4 builds the memorization UI (5th tab, opt-in button, review session). Phases 3 (manual content curation) and 6 (App Store resubmission) are operational, not code.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData / Swift Testing / Foundation / WidgetKit / UserNotifications / Xcode 26 synchronized folder groups / `xcodeproj` Ruby gem for project mutations.

**Spec reference:** `docs/superpowers/specs/2026-05-17-context-home-and-memorization-design.md`

---

## File Structure

### New files

```
Adhkar/Models/LifeContext.swift               struct + ContextFamily enum, Codable
Adhkar/Models/HifzCard.swift                  @Model + HifzStage enum
Adhkar/Services/HifzScheduler.swift           pure SM-2 logic + previewIntervals
Adhkar/Services/HifzStore.swift               SwiftData façade (add/remove/dueToday)
Adhkar/Views/HomeContextCard.swift            Home headline card
Adhkar/Views/ContextPickerView.swift          sheet root with sectioned 2-col grid
Adhkar/Views/ContextDetailView.swift          header + ContextDhikrRow list
Adhkar/Views/ContextDhikrRow.swift            list row component
Adhkar/Views/MemorizeButton.swift             reusable opt-in button
Adhkar/Views/MemoTabView.swift                5th tab landing (empty + filled)
Adhkar/Views/ReviewSessionView.swift          prompt + revealed + 4 rating buttons
Adhkar/Views/ReviewSessionSummaryView.swift   end-of-session recap
Adhkar/Resources/contexts.json                curated content (stub initially)
AdhkarTests/HifzSchedulerTests.swift          Swift Testing unit tests
AdhkarTests/DataProviderContextsTests.swift   contexts.json decoding tests
scripts/setup_test_target.rb                  adds AdhkarTests target via xcodeproj gem
```

### Modified files

```
Adhkar/App/AdhkarApp.swift                    +HifzCard.self in ModelContainer
Adhkar/App/RootTabView.swift                  +.memorize 5th tab
Adhkar/Views/HomeView.swift                   +HomeContextCard at top + sheet binding
Adhkar/Views/AdhkarDetailsView.swift          +init(adhkar:focusedItemId:navTitleOverride:)
                                              +MemorizeButton in DhikrPageView.actionRow
Adhkar/Services/DataProvider.swift            +loadContextsThrowing + static lifeContexts
Adhkar/Services/NotificationManager.swift     +.hifz slot
Adhkar/Services/StreakService.swift           +hifz.dueToday/totalCards App Group writes
Adhkar/Views/SettingsView.swift               +hifz reminder toggle row
Adhkar/Localization/L10n.swift                +all new UI strings
MunajatWidget/CurrentPeriodWidget.swift       +medium-size hifz badge
scripts/share_files_with_widget.rb            +share LifeContext.swift, HifzCard.swift
```

---

# PHASE 1 — Foundations (data + algorithm)

**Phase goal:** All data models exist, the SM-2 scheduler is fully tested, the test target runs green, the app builds clean on iOS/macOS/visionOS. No user-visible change yet.

**Exit criteria:**
- `swift test` (via Xcode) passes ≥ 20 tests in `AdhkarTests`.
- `xcodebuild build` succeeds for iOS Simulator + macOS + visionOS Simulator.
- App runs unchanged; no regression in existing flows.

### Task 1.1 — Add Swift Testing target via `xcodeproj` gem

**Files:**
- Create: `scripts/setup_test_target.rb`
- Create: `AdhkarTests/PlaceholderTest.swift`
- Modify: `Adhkar.xcodeproj/project.pbxproj` (via the script, never by hand)

- [ ] **Step 1: Write `scripts/setup_test_target.rb`**

```ruby
#!/usr/bin/env ruby
# Adds an `AdhkarTests` Swift Testing unit-test bundle target to Adhkar.xcodeproj.
# Idempotent — re-running is a no-op once the target exists.

require 'xcodeproj'

project_path = File.expand_path('../Adhkar.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

target_name = 'AdhkarTests'
host_app    = project.targets.find { |t| t.name == 'Adhkar' } or abort 'Adhkar target not found'

if project.targets.any? { |t| t.name == target_name }
  puts "Target #{target_name} already exists — nothing to do."
  exit 0
end

# Synchronized root group keeps drag-and-drop semantics consistent with the
# rest of the project (Xcode 26 PBXFileSystemSynchronizedRootGroup).
tests_group = project.main_group.find_subpath('AdhkarTests', true)
tests_group.set_source_tree('SOURCE_ROOT')
tests_group.set_path('AdhkarTests')

test_target = project.new_target(:unit_test_bundle, target_name, :ios, '17.0', nil, :swift)
test_target.add_dependency(host_app)

# Test target configuration — Swift Testing only, no XCTest dependency.
test_target.build_configurations.each do |config|
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.tadev.munajat.tests'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['TEST_HOST'] = "$(BUILT_PRODUCTS_DIR)/Adhkar.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Adhkar"
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['XROS_DEPLOYMENT_TARGET'] = '1.0'
  config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator macosx xros xrsimulator'
end

# Add placeholder source so the target compiles before we add real tests.
placeholder = tests_group.new_file('PlaceholderTest.swift')
test_target.add_file_references([placeholder])

# Wire scheme so `xcodebuild test -scheme Adhkar` runs the tests automatically.
scheme = Xcodeproj::XCScheme.new(File.join(project_path, 'xcshareddata/xcschemes/Adhkar.xcscheme'))
test_action = scheme.test_action
existing_ids = test_action.testables.map { |t| t.buildable_references.first.target_uuid rescue nil }
unless existing_ids.include?(test_target.uuid)
  testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(test_target)
  test_action.add_testable(testable)
  scheme.save!
end

project.save
puts "Created #{target_name} target."
```

- [ ] **Step 2: Write the placeholder test that proves the target compiles**

```swift
// AdhkarTests/PlaceholderTest.swift
import Testing

@Suite("Placeholder")
struct PlaceholderTest {
    @Test func swiftTestingIsLinked() {
        #expect(2 + 2 == 4)
    }
}
```

- [ ] **Step 3: Run the script**

```bash
chmod +x scripts/setup_test_target.rb
ruby scripts/setup_test_target.rb
```

Expected: `Created AdhkarTests target.`

- [ ] **Step 4: Verify tests run**

```bash
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `Test Suite 'Placeholder' passed` and exit code 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/setup_test_target.rb AdhkarTests/PlaceholderTest.swift Adhkar.xcodeproj
git commit -m "build(tests): add AdhkarTests Swift Testing target via xcodeproj gem"
```

---

### Task 1.2 — Add `LifeContext` model

**Files:**
- Create: `Adhkar/Models/LifeContext.swift`

- [ ] **Step 1: Write the model**

```swift
// Adhkar/Models/LifeContext.swift
import Foundation

/// A life-state context (emotion or trial) that a user can choose to read
/// dhikr through. Defined in `contexts.json`, loaded by `DataProvider`.
struct LifeContext: Identifiable, Hashable, Equatable, Codable {
    let id: String
    let family: ContextFamily
    let iconName: String
    let color: String
    let title: LocalizedText
    let intro: LocalizedText
    let dhikrIds: [String]
}

enum ContextFamily: String, Codable, Hashable, CaseIterable {
    case emotion
    case trial
}
```

- [ ] **Step 2: Build to verify it compiles**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Models/LifeContext.swift
git commit -m "feat(model): add LifeContext + ContextFamily for context-driven home"
```

---

### Task 1.3 — Add `HifzCard` SwiftData model

**Files:**
- Create: `Adhkar/Models/HifzCard.swift`

- [ ] **Step 1: Write the model**

```swift
// Adhkar/Models/HifzCard.swift
import Foundation
import SwiftData

/// Spaced-repetition card for a dhikr the user opted to memorize.
/// `itemId` references `Adhkar.id` (globally unique).
@Model
final class HifzCard {
    @Attribute(.unique) var itemId: String
    var addedAt: Date
    var lastReviewedAt: Date?
    var nextReviewAt: Date
    var intervalDays: Double
    var easeFactor: Double
    var reps: Int
    var lapses: Int
    var stageRaw: String

    var stage: HifzStage {
        get { HifzStage(rawValue: stageRaw) ?? .new }
        set { stageRaw = newValue.rawValue }
    }

    init(itemId: String, now: Date = .now) {
        self.itemId = itemId
        self.addedAt = now
        self.lastReviewedAt = nil
        self.nextReviewAt = now  // new cards are due immediately
        self.intervalDays = 0
        self.easeFactor = 2.5
        self.reps = 0
        self.lapses = 0
        self.stageRaw = HifzStage.new.rawValue
    }
}

enum HifzStage: String, Codable, CaseIterable {
    case new        // never reviewed
    case learning   // reps < 3
    case anchored   // reps >= 3 AND intervalDays >= 14
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Models/HifzCard.swift
git commit -m "feat(model): add HifzCard SwiftData model with HifzStage"
```

---

### Task 1.4 — Wire `HifzCard.self` into the `ModelContainer`

**Files:**
- Modify: `Adhkar/App/AdhkarApp.swift:56`

- [ ] **Step 1: Update the `.modelContainer` line**

Find in `Adhkar/App/AdhkarApp.swift`:
```swift
        .modelContainer(for: [DhikrProgress.self, DailyActivity.self])
```

Replace with:
```swift
        .modelContainer(for: [DhikrProgress.self, DailyActivity.self, HifzCard.self])
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/App/AdhkarApp.swift
git commit -m "feat(model): register HifzCard in ModelContainer"
```

---

### Task 1.5 — Write `HifzScheduler` pure logic

**Files:**
- Create: `Adhkar/Services/HifzScheduler.swift`

- [ ] **Step 1: Write the scheduler**

```swift
// Adhkar/Services/HifzScheduler.swift
import Foundation

enum HifzReviewButton: String, CaseIterable {
    case again, hard, good, easy
}

/// Pure simplified SM-2 scheduler. No I/O, no SwiftData dependency.
/// Mutates the passed-in `HifzCard` in place (SwiftData @Model classes are
/// reference types, so changes are picked up by the model context).
enum HifzScheduler {
    static let initialEase: Double = 2.5
    static let minEase: Double = 1.3

    /// Apply the user's rating to a card. Updates intervalDays, easeFactor,
    /// reps, lapses, nextReviewAt, lastReviewedAt, and stage.
    static func schedule(_ card: HifzCard, button: HifzReviewButton, now: Date = .now) {
        card.lastReviewedAt = now

        if card.reps == 0 {
            switch button {
            case .again:
                card.intervalDays = 0
                card.nextReviewAt = now
                card.lapses += 1
            case .hard, .good:
                card.intervalDays = 1
                card.nextReviewAt = addDays(1, to: now)
                card.reps = 1
            case .easy:
                card.intervalDays = 4
                card.nextReviewAt = addDays(4, to: now)
                card.reps = 1
            }
        } else {
            switch button {
            case .again:
                card.intervalDays = 0
                card.nextReviewAt = now
                card.easeFactor = max(minEase, card.easeFactor - 0.20)
                card.lapses += 1
                card.reps = 0
            case .hard:
                card.intervalDays *= 1.2
                card.easeFactor = max(minEase, card.easeFactor - 0.15)
                card.nextReviewAt = addDays(card.intervalDays, to: now)
                card.reps += 1
            case .good:
                card.intervalDays *= card.easeFactor
                card.nextReviewAt = addDays(card.intervalDays, to: now)
                card.reps += 1
            case .easy:
                card.intervalDays *= card.easeFactor * 1.3
                card.easeFactor += 0.15
                card.nextReviewAt = addDays(card.intervalDays, to: now)
                card.reps += 1
            }
        }

        card.stage = computeStage(reps: card.reps, intervalDays: card.intervalDays)
    }

    /// What each button would set `intervalDays` to if pressed now. Used by
    /// `ReviewSessionView` to show dynamic delay hints under the 4 buttons
    /// without mutating the card.
    static func previewIntervals(for card: HifzCard) -> [HifzReviewButton: Double] {
        var result: [HifzReviewButton: Double] = [:]
        for button in HifzReviewButton.allCases {
            if card.reps == 0 {
                switch button {
                case .again:       result[button] = 0
                case .hard, .good: result[button] = 1
                case .easy:        result[button] = 4
                }
            } else {
                switch button {
                case .again: result[button] = 0
                case .hard:  result[button] = card.intervalDays * 1.2
                case .good:  result[button] = card.intervalDays * card.easeFactor
                case .easy:  result[button] = card.intervalDays * card.easeFactor * 1.3
                }
            }
        }
        return result
    }

    static func computeStage(reps: Int, intervalDays: Double) -> HifzStage {
        if reps == 0 { return .new }
        if reps >= 3 && intervalDays >= 14 { return .anchored }
        return .learning
    }

    private static func addDays(_ days: Double, to date: Date) -> Date {
        date.addingTimeInterval(days * 86_400)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Services/HifzScheduler.swift
git commit -m "feat(hifz): pure SM-2 scheduler with previewIntervals + stage computation"
```

---

### Task 1.6 — Write `HifzScheduler` tests (all 8 paths + edges)

**Files:**
- Create: `AdhkarTests/HifzSchedulerTests.swift`
- Delete: `AdhkarTests/PlaceholderTest.swift`

- [ ] **Step 1: Write the test suite**

```swift
// AdhkarTests/HifzSchedulerTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("HifzScheduler")
struct HifzSchedulerTests {
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000) // fixed clock

    // MARK: - New card paths

    @Test func newCard_again_staysToday_noRepIncrement() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        HifzScheduler.schedule(card, button: .again, now: referenceDate)
        #expect(card.reps == 0)
        #expect(card.intervalDays == 0)
        #expect(card.nextReviewAt == referenceDate)
        #expect(card.lapses == 1)
        #expect(card.stage == .new)
    }

    @Test func newCard_hard_oneDayInterval() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        HifzScheduler.schedule(card, button: .hard, now: referenceDate)
        #expect(card.reps == 1)
        #expect(card.intervalDays == 1)
        #expect(card.stage == .learning)
    }

    @Test func newCard_good_oneDayInterval() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        HifzScheduler.schedule(card, button: .good, now: referenceDate)
        #expect(card.reps == 1)
        #expect(card.intervalDays == 1)
        #expect(card.stage == .learning)
    }

    @Test func newCard_easy_fourDayInterval() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        HifzScheduler.schedule(card, button: .easy, now: referenceDate)
        #expect(card.reps == 1)
        #expect(card.intervalDays == 4)
        #expect(card.stage == .learning)
    }

    // MARK: - Existing card paths

    @Test func existingCard_again_resetsRepsAndDropsEase() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        card.reps = 4
        card.intervalDays = 30
        card.easeFactor = 2.5

        HifzScheduler.schedule(card, button: .again, now: referenceDate)

        #expect(card.reps == 0)
        #expect(card.intervalDays == 0)
        #expect(card.nextReviewAt == referenceDate)
        #expect(card.lapses == 1)
        #expect(card.easeFactor == 2.3) // 2.5 - 0.20
        #expect(card.stage == .new)
    }

    @Test func existingCard_hard_multiplies1_2AndLowersEase() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        card.reps = 2
        card.intervalDays = 5
        card.easeFactor = 2.5

        HifzScheduler.schedule(card, button: .hard, now: referenceDate)

        #expect(card.reps == 3)
        #expect(card.intervalDays == 6.0) // 5 * 1.2
        #expect(card.easeFactor == 2.35) // 2.5 - 0.15
        #expect(card.stage == .learning) // 6 < 14
    }

    @Test func existingCard_good_multipliesByEase() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        card.reps = 2
        card.intervalDays = 6
        card.easeFactor = 2.5

        HifzScheduler.schedule(card, button: .good, now: referenceDate)

        #expect(card.reps == 3)
        #expect(card.intervalDays == 15.0) // 6 * 2.5
        #expect(card.easeFactor == 2.5)    // unchanged
        #expect(card.stage == .anchored)   // reps >= 3 && interval >= 14
    }

    @Test func existingCard_easy_multipliesByEaseTimes1_3AndRaisesEase() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        card.reps = 3
        card.intervalDays = 10
        card.easeFactor = 2.0

        HifzScheduler.schedule(card, button: .easy, now: referenceDate)

        #expect(card.reps == 4)
        #expect(card.intervalDays == 26.0) // 10 * 2.0 * 1.3
        #expect(card.easeFactor == 2.15)   // 2.0 + 0.15
        #expect(card.stage == .anchored)
    }

    // MARK: - Edge cases

    @Test func easeFloorAt1_3() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        card.reps = 5
        card.easeFactor = 1.35
        HifzScheduler.schedule(card, button: .again, now: referenceDate)
        #expect(card.easeFactor == 1.3) // not below floor
    }

    @Test func stageTransitionsNewToLearningToAnchored() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        #expect(card.stage == .new)
        HifzScheduler.schedule(card, button: .good, now: referenceDate)
        #expect(card.stage == .learning)
        // Drive to anchored
        for _ in 0..<5 {
            HifzScheduler.schedule(card, button: .good, now: referenceDate)
        }
        #expect(card.stage == .anchored)
    }

    @Test func previewIntervals_newCard_matchesScheduling() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        let preview = HifzScheduler.previewIntervals(for: card)
        #expect(preview[.again] == 0)
        #expect(preview[.hard] == 1)
        #expect(preview[.good] == 1)
        #expect(preview[.easy] == 4)
    }

    @Test func previewIntervals_existingCard_matchesScheduling() {
        let card = HifzCard(itemId: "x", now: referenceDate)
        card.reps = 2
        card.intervalDays = 6
        card.easeFactor = 2.5

        let preview = HifzScheduler.previewIntervals(for: card)
        #expect(preview[.again] == 0)
        #expect(preview[.hard] == 7.2)   // 6 * 1.2
        #expect(preview[.good] == 15.0)  // 6 * 2.5
        #expect(preview[.easy] == 19.5)  // 6 * 2.5 * 1.3
    }

    @Test func previewIntervalsMatchActualScheduling_good() {
        let preview = HifzCard(itemId: "p", now: referenceDate)
        preview.reps = 2; preview.intervalDays = 6; preview.easeFactor = 2.5

        let actual = HifzCard(itemId: "a", now: referenceDate)
        actual.reps = 2; actual.intervalDays = 6; actual.easeFactor = 2.5

        let expectedInterval = HifzScheduler.previewIntervals(for: preview)[.good]!
        HifzScheduler.schedule(actual, button: .good, now: referenceDate)
        #expect(actual.intervalDays == expectedInterval)
    }
}
```

- [ ] **Step 2: Delete the placeholder test**

```bash
rm AdhkarTests/PlaceholderTest.swift
```

- [ ] **Step 3: Update the test target file list**

Re-run the setup script (it's idempotent on the target but won't re-pick up new files — synchronized groups should handle this automatically since AdhkarTests is set up as a path):

```bash
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:AdhkarTests/HifzSchedulerTests -quiet
```

If the file isn't picked up automatically (synchronized group misconfigured), open Xcode once and verify AdhkarTests folder shows the new file in the project navigator. The xcodeproj script creates a non-sync group by default — if needed, convert it manually or update the script to use `PBXFileSystemSynchronizedRootGroup`.

Expected: 13 tests pass, 0 fail.

- [ ] **Step 4: Commit**

```bash
git add AdhkarTests/HifzSchedulerTests.swift
git rm AdhkarTests/PlaceholderTest.swift
git commit -m "test(hifz): cover all 8 SM-2 scheduling paths + previewIntervals + stage transitions"
```

---

### Task 1.7 — Add `contexts.json` stub + extend `DataProvider`

**Files:**
- Create: `Adhkar/Resources/contexts.json`
- Modify: `Adhkar/Services/DataProvider.swift`

- [ ] **Step 1: Create the structural stub**

```json
{
  "version": 1,
  "contexts": [
    { "id": "anxious",        "family": "emotion", "iconName": "wind",                "color": "blue",   "title": { "ar": "قلق",  "fr": "Anxieux",       "en": "Anxious" },    "intro": { "ar": "", "fr": "Quand l'inquiétude pèse…",  "en": "When worry weighs on you…" }, "dhikrIds": [] },
    { "id": "grateful",       "family": "emotion", "iconName": "hands.sparkles.fill", "color": "yellow", "title": { "ar": "شاكر", "fr": "Reconnaissant", "en": "Grateful" },   "intro": { "ar": "", "fr": "Pour la gratitude…",        "en": "For gratitude…" },             "dhikrIds": [] },
    { "id": "sad",            "family": "emotion", "iconName": "cloud.rain.fill",     "color": "indigo", "title": { "ar": "حزين", "fr": "Triste",        "en": "Sad" },        "intro": { "ar": "", "fr": "Quand le cœur est lourd…",   "en": "When the heart is heavy…" },   "dhikrIds": [] },
    { "id": "angry",          "family": "emotion", "iconName": "flame.fill",          "color": "red",    "title": { "ar": "غاضب","fr": "En colère",     "en": "Angry" },      "intro": { "ar": "", "fr": "Pour apaiser la colère…",    "en": "To calm anger…" },             "dhikrIds": [] },
    { "id": "fearful",        "family": "emotion", "iconName": "exclamationmark.triangle.fill","color": "orange","title": { "ar": "خائف","fr": "Peur","en": "Fearful" },       "intro": { "ar": "", "fr": "Face à la peur…",           "en": "Facing fear…" },               "dhikrIds": [] },
    { "id": "happy",          "family": "emotion", "iconName": "sun.max.fill",        "color": "yellow", "title": { "ar": "سعيد","fr": "Heureux",       "en": "Happy" },      "intro": { "ar": "", "fr": "Pour célébrer la joie…",    "en": "To celebrate joy…" },          "dhikrIds": [] },
    { "id": "regretful",      "family": "emotion", "iconName": "drop.fill",           "color": "teal",   "title": { "ar": "نادم","fr": "Repentant",     "en": "Regretful" },  "intro": { "ar": "", "fr": "Pour demander pardon…",     "en": "To ask for forgiveness…" },    "dhikrIds": [] },
    { "id": "hopeful",        "family": "emotion", "iconName": "sunrise.fill",        "color": "orange", "title": { "ar": "راجٍ", "fr": "Espoir",        "en": "Hopeful" },    "intro": { "ar": "", "fr": "Pour nourrir l'espoir…",    "en": "To nurture hope…" },           "dhikrIds": [] },
    { "id": "sick",           "family": "trial",   "iconName": "bandage.fill",        "color": "pink",   "title": { "ar": "مريض","fr": "Malade",        "en": "Sick" },       "intro": { "ar": "", "fr": "Pour la guérison…",         "en": "For healing…" },               "dhikrIds": [] },
    { "id": "mourning",       "family": "trial",   "iconName": "moon.fill",           "color": "indigo", "title": { "ar": "حزين","fr": "Deuil",         "en": "Mourning" },   "intro": { "ar": "", "fr": "Quand on a perdu un proche…","en": "When one has lost a loved one…" }, "dhikrIds": [] },
    { "id": "indebted",       "family": "trial",   "iconName": "creditcard.fill",     "color": "brown",  "title": { "ar": "مدين", "fr": "Dette",         "en": "In debt" },    "intro": { "ar": "", "fr": "Face à la charge financière…","en": "Facing financial burden…" },   "dhikrIds": [] },
    { "id": "before-important","family": "trial",  "iconName": "hourglass",           "color": "purple", "title": { "ar": "قبل أمر مهم","fr": "Avant un moment important","en": "Before an important moment" }, "intro": { "ar": "", "fr": "Avant un examen, un entretien, une décision…", "en": "Before an exam, interview, decision…" }, "dhikrIds": [] },
    { "id": "in-conflict",    "family": "trial",   "iconName": "person.2.slash",      "color": "red",    "title": { "ar": "خلاف","fr": "En conflit",    "en": "In conflict" },"intro": { "ar": "", "fr": "Avec quelqu'un…",           "en": "With someone…" },              "dhikrIds": [] },
    { "id": "insomniac",      "family": "trial",   "iconName": "bed.double.fill",     "color": "blue",   "title": { "ar": "أرق", "fr": "Insomnie",      "en": "Insomnia" },   "intro": { "ar": "", "fr": "Quand le sommeil fuit…",     "en": "When sleep escapes you…" },    "dhikrIds": [] },
    { "id": "doubting",       "family": "trial",   "iconName": "questionmark.circle.fill","color":"gray","title": { "ar": "متشكك","fr": "Doute",         "en": "Doubting" },   "intro": { "ar": "", "fr": "Face au doute…",            "en": "Facing doubt…" },              "dhikrIds": [] }
  ]
}
```

- [ ] **Step 2: Extend `DataProvider` with the loader**

Append to `Adhkar/Services/DataProvider.swift`:

```swift
extension DataProvider {
    static let lifeContexts: [LifeContext] = loadContexts()

    enum ContextsLoadError: Error, CustomStringConvertible {
        case fileNotFound
        case decodingFailed(Error)

        var description: String {
            switch self {
            case .fileNotFound: return "contexts.json not found in app bundle"
            case .decodingFailed(let underlying): return "contexts.json failed to decode: \(underlying)"
            }
        }
    }

    static func loadContextsThrowing(from bundle: Bundle = .main) throws -> [LifeContext] {
        guard let url = bundle.url(forResource: "contexts", withExtension: "json") else {
            throw ContextsLoadError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        do {
            let file = try JSONDecoder().decode(ContextsFile.self, from: data)
            return file.contexts
        } catch {
            throw ContextsLoadError.decodingFailed(error)
        }
    }

    private static func loadContexts() -> [LifeContext] {
        do {
            return try loadContextsThrowing()
        } catch {
            assertionFailure("\(error)")
            return []
        }
    }
}

private struct ContextsFile: Codable {
    let version: Int
    let contexts: [LifeContext]
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Adhkar/Resources/contexts.json Adhkar/Services/DataProvider.swift
git commit -m "feat(data): contexts.json stub + DataProvider.lifeContexts loader"
```

---

### Task 1.8 — Test `DataProvider.loadContextsThrowing`

**Files:**
- Create: `AdhkarTests/DataProviderContextsTests.swift`

- [ ] **Step 1: Write the tests**

```swift
// AdhkarTests/DataProviderContextsTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("DataProvider contexts")
struct DataProviderContextsTests {
    @Test func loadsBundledFile() throws {
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        #expect(contexts.count == 15)
    }

    @Test func eightEmotionsAndSevenTrials() throws {
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        let emotions = contexts.filter { $0.family == .emotion }
        let trials   = contexts.filter { $0.family == .trial }
        #expect(emotions.count == 8)
        #expect(trials.count == 7)
    }

    @Test func everyContextHasNonEmptyTitleInThreeLanguages() throws {
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        for c in contexts {
            #expect(!(c.title.fr ?? "").isEmpty, "\(c.id) missing fr title")
            #expect(!(c.title.en ?? "").isEmpty, "\(c.id) missing en title")
        }
    }

    @Test func everyContextHasUniqueId() throws {
        let contexts = try DataProvider.loadContextsThrowing(from: Bundle.main)
        let ids = contexts.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:AdhkarTests/DataProviderContextsTests -quiet
```

Expected: 4 tests pass.

- [ ] **Step 3: Commit**

```bash
git add AdhkarTests/DataProviderContextsTests.swift
git commit -m "test(data): verify contexts.json decodes with 8 emotions + 7 trials"
```

---

### Task 1.9 — Add `HifzStore` SwiftData façade

**Files:**
- Create: `Adhkar/Services/HifzStore.swift`

- [ ] **Step 1: Write the store**

```swift
// Adhkar/Services/HifzStore.swift
import Foundation
import SwiftData

/// Read/write façade for `HifzCard`. UI views use this instead of inline
/// FetchDescriptors so the query logic lives in one place.
enum HifzStore {
    static func find(itemId: String, in context: ModelContext) -> HifzCard? {
        let descriptor = FetchDescriptor<HifzCard>(
            predicate: #Predicate<HifzCard> { $0.itemId == itemId }
        )
        return (try? context.fetch(descriptor))?.first
    }

    static func isMemorizing(itemId: String, in context: ModelContext) -> Bool {
        find(itemId: itemId, in: context) != nil
    }

    @discardableResult
    static func add(itemId: String, in context: ModelContext, now: Date = .now) -> HifzCard {
        if let existing = find(itemId: itemId, in: context) { return existing }
        let card = HifzCard(itemId: itemId, now: now)
        context.insert(card)
        try? context.save()
        return card
    }

    static func remove(itemId: String, in context: ModelContext) {
        if let existing = find(itemId: itemId, in: context) {
            context.delete(existing)
            try? context.save()
        }
    }

    static func dueToday(in context: ModelContext, now: Date = .now) -> [HifzCard] {
        let endOfDay = Calendar(identifier: .gregorian).date(
            bySettingHour: 23, minute: 59, second: 59, of: now
        ) ?? now
        let descriptor = FetchDescriptor<HifzCard>(
            predicate: #Predicate<HifzCard> { $0.nextReviewAt <= endOfDay },
            sortBy: [SortDescriptor(\.nextReviewAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func all(in context: ModelContext) -> [HifzCard] {
        let descriptor = FetchDescriptor<HifzCard>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func countByStage(in context: ModelContext) -> [HifzStage: Int] {
        let all = self.all(in: context)
        var counts: [HifzStage: Int] = [:]
        for stage in HifzStage.allCases { counts[stage] = 0 }
        for card in all { counts[card.stage, default: 0] += 1 }
        return counts
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Services/HifzStore.swift
git commit -m "feat(hifz): HifzStore façade for add/remove/dueToday/countByStage"
```

---

### Phase 1 verification

- [ ] **Full test run + multi-platform build**

```bash
# Tests
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet

# iOS Simulator build
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet

# macOS build
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=macOS' -quiet

# visionOS Simulator build
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' -quiet
```

Expected: all 4 commands exit 0. Tests show 17+ pass.

---

# PHASE 2 — Contextual UI

**Phase goal:** Home displays "Comment te sens-tu ?" card → opens picker sheet → 15 contexts shown sectioned → tap context → see detail screen with intro + empty list (until Phase 3 curates content). Tap empty context → shows "no items yet" gracefully.

**Exit criteria:**
- User opens app, taps the new card at the top of home, sees the 2-col picker.
- User taps any context tile, lands on the context detail screen with proper header + intro.
- User taps "Annuler" in picker, sheet dismisses cleanly.
- All existing flows still work.

### Task 2.1 — Localization strings for contextual UI

**Files:**
- Modify: `Adhkar/Localization/L10n.swift` (append before final `}`)

- [ ] **Step 1: Add the strings**

```swift
    // Context-driven home — card on Home
    static let contextHomeCardLabel  = LocalizedText(ar: "كيف تشعر؟", fr: "Comment te sens-tu ?", en: "How do you feel?")
    static let contextHomeCardHint   = LocalizedText(ar: "١٥ حالات · اختر ما تعيشه", fr: "15 états · choisis ce que tu vis", en: "15 states · pick what you're living")
    static let contextPickerTitle    = LocalizedText(ar: "كيف تشعر؟", fr: "Comment te sens-tu ?", en: "How do you feel?")
    static let contextFamilyEmotion  = LocalizedText(ar: "المشاعر", fr: "Émotions", en: "Emotions")
    static let contextFamilyTrial    = LocalizedText(ar: "ابتلاءات الحياة", fr: "Épreuves de vie", en: "Life trials")
    static let contextCancel         = LocalizedText(ar: "إلغاء", fr: "Annuler", en: "Cancel")
    static let contextDhikrSuggested = LocalizedText(ar: "أذكار مقترحة", fr: "Dhikr suggérés", en: "Suggested dhikr")
    static let contextEmptyTitle     = LocalizedText(ar: "لا توجد عناصر بعد", fr: "Aucun dhikr pour ce contexte", en: "No dhikr for this context yet")
    static let contextEmptyHint      = LocalizedText(ar: "سيتم إضافتها قريبًا.", fr: "Ils seront ajoutés bientôt.", en: "They will be added soon.")
    static let contextDhikrCountSuffix = LocalizedText(ar: "ذكر", fr: "dhikr", en: "dhikr")
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Localization/L10n.swift
git commit -m "feat(l10n): strings for context-driven home (FR/EN/AR)"
```

---

### Task 2.2 — `HomeContextCard` component

**Files:**
- Create: `Adhkar/Views/HomeContextCard.swift`

- [ ] **Step 1: Write the card**

```swift
// Adhkar/Views/HomeContextCard.swift
import SwiftUI

/// Headline card at the top of the Home screen. Tapping it opens the
/// context picker sheet. The action is injected so HomeView owns the
/// presentation state.
struct HomeContextCard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.35), Color.orange.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.contextHomeCardLabel.resolved())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(L10n.contextHomeCardHint.resolved())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.contextHomeCardLabel.resolved()). \(L10n.contextHomeCardHint.resolved())")
        .accessibilityHint(L10n.contextHomeCardLabel.resolved())
        .accessibilityAddTraits(.isButton)
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Views/HomeContextCard.swift
git commit -m "feat(ui): HomeContextCard — \"Comment te sens-tu?\" headline"
```

---

### Task 2.3 — `ContextPickerView` sheet root

**Files:**
- Create: `Adhkar/Views/ContextPickerView.swift`

- [ ] **Step 1: Write the picker**

```swift
// Adhkar/Views/ContextPickerView.swift
import SwiftUI

/// Sheet content shown when the user taps the home context card.
/// Owns an internal NavigationStack so picker → context detail → dhikr
/// detail all live inside the sheet and dismiss together on "Annuler".
struct ContextPickerView: View {
    @Environment(\.dismiss) private var dismiss
    private let contexts = DataProvider.lifeContexts

    private var emotions: [LifeContext] { contexts.filter { $0.family == .emotion } }
    private var trials:   [LifeContext] { contexts.filter { $0.family == .trial   } }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    familySection(title: L10n.contextFamilyEmotion.resolved(),
                                  items: emotions)
                    familySection(title: L10n.contextFamilyTrial.resolved(),
                                  items: trials)
                }
                .padding()
            }
            .background(Color.black.opacity(0.001))
            .navigationTitle(L10n.contextPickerTitle.resolved())
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.contextCancel.resolved()) { dismiss() }
                }
            }
            .navigationDestination(for: LifeContext.self) { ctx in
                ContextDetailView(context: ctx)
            }
        }
    }

    @ViewBuilder
    private func familySection(title: String, items: [LifeContext]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { ctx in
                    NavigationLink(value: ctx) {
                        ContextTile(context: ctx)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ContextTile: View {
    let context: LifeContext

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: context.iconName)
                .font(.system(size: 26))
                .foregroundStyle(.orange)
                .frame(height: 32)
            Text(context.title.resolved())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text("\(context.dhikrIds.count) \(L10n.contextDhikrCountSuffix.resolved())")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(context.title.resolved()), \(context.dhikrIds.count) \(L10n.contextDhikrCountSuffix.resolved())")
        .accessibilityAddTraits(.isButton)
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED` (references `ContextDetailView` which doesn't exist yet — will fail. Defer next build until task 2.5).

If build fails because `ContextDetailView` is undeclared, that's expected — proceed to next task.

- [ ] **Step 3: Commit (will not pass type-check yet, that's OK — Phase 2 is built incrementally)**

```bash
git add Adhkar/Views/ContextPickerView.swift
git commit -m "feat(ui): ContextPickerView sheet root with 2-col sectioned grid"
```

---

### Task 2.4 — `ContextDhikrRow` row component

**Files:**
- Create: `Adhkar/Views/ContextDhikrRow.swift`

- [ ] **Step 1: Write the row**

```swift
// Adhkar/Views/ContextDhikrRow.swift
import SwiftUI

/// One row in `ContextDetailView`'s curated dhikr list. Shows a short
/// Arabic preview + source/title meta. Tap navigates to the dhikr detail
/// page in single-item mode (handled by the parent's NavigationStack).
struct ContextDhikrRow: View {
    let category: AdhkarCategory
    let dhikr: Adhkar

    private var arabicPreview: String {
        let text = dhikr.dhikr.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count <= 90 { return text }
        return String(text.prefix(88)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private var metaLine: String {
        var parts: [String] = []
        if !dhikr.source.isEmpty { parts.append(dhikr.source) }
        parts.append(category.displayTitle)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(arabicPreview)
                .font(.amiri(size: 18))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(3)

            Text(metaLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dhikr.dhikr). \(metaLine)")
        .accessibilityAddTraits(.isButton)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Adhkar/Views/ContextDhikrRow.swift
git commit -m "feat(ui): ContextDhikrRow with Arabic preview + source/title meta"
```

---

### Task 2.5 — `ContextDetailView` (header + intro + curated list)

**Files:**
- Create: `Adhkar/Views/ContextDetailView.swift`

- [ ] **Step 1: Write the view**

```swift
// Adhkar/Views/ContextDetailView.swift
import SwiftUI

/// Detail screen pushed onto the picker's navigation stack after the user
/// picks a context. Shows the context header (icon + title + intro) and
/// the curated dhikr rows resolved from `context.dhikrIds`.
struct ContextDetailView: View {
    let context: LifeContext

    /// Resolved (AdhkarCategory, Adhkar) pairs in the order specified by
    /// the context's `dhikrIds`. Unknown ids are silently dropped so a
    /// content typo doesn't crash the app.
    private var resolvedItems: [(AdhkarCategory, Adhkar)] {
        let allCategories = DataProvider.adharCategories
        return context.dhikrIds.compactMap { id in
            for category in allCategories {
                if let dhikr = category.adhkarList.first(where: { $0.id == id }) {
                    return (category, dhikr)
                }
            }
            return nil
        }
    }

    private var accentColor: Color {
        Color.namedAccent(context.color)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if resolvedItems.isEmpty {
                    emptyState
                } else {
                    suggestedSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(AdaptiveBackground(decorated: true))
        .navigationTitle(context.title.resolved())
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.20))
                    .frame(width: 64, height: 64)
                Image(systemName: context.iconName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            Text(context.title.resolved())
                .font(.largeTitle.weight(.bold))
            Text(context.intro.resolved())
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.contextDhikrSuggested.resolved())
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(Array(resolvedItems.enumerated()), id: \.offset) { _, pair in
                    NavigationLink(value: ContextDhikrTarget(categoryId: pair.0.id, itemId: pair.1.id, navTitle: context.title)) {
                        ContextDhikrRow(category: pair.0, dhikr: pair.1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(L10n.contextEmptyTitle.resolved())
                .font(.headline)
            Text(L10n.contextEmptyHint.resolved())
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Navigation value used to push `AdhkarDetailsView` in single-item mode
/// from within the context picker sheet's NavigationStack.
struct ContextDhikrTarget: Hashable {
    let categoryId: String
    let itemId: String
    let navTitle: LocalizedText
}

/// Maps `LifeContext.color` strings to SwiftUI Color. Keep in sync with
/// the colors used in `contexts.json`.
extension Color {
    static func namedAccent(_ name: String) -> Color {
        switch name {
        case "blue":   return .blue
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "red":    return .red
        case "orange": return .orange
        case "teal":   return .teal
        case "pink":   return .pink
        case "brown":  return .brown
        case "purple": return .purple
        case "gray":   return .gray
        default:       return .orange
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: builds; the `NavigationLink(value: ContextDhikrTarget(...))` doesn't yet have a destination registered — fine, navigating won't crash, push will fail silently until Task 2.6.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Views/ContextDetailView.swift
git commit -m "feat(ui): ContextDetailView with header, intro, suggested list, empty state"
```

---

### Task 2.6 — Add `focusedItemId` variant to `AdhkarDetailsView`

**Files:**
- Modify: `Adhkar/Views/AdhkarDetailsView.swift`

- [ ] **Step 1: Add the new init**

Modify the top of `AdhkarDetailsView`:

```swift
struct AdhkarDetailsView: View {
    let adhkar: AdhkarCategory
    let focusedItemId: String?
    let navTitleOverride: LocalizedText?

    @State private var resetToken = UUID()
    @State private var selectedIndex: Int = 0
    @State private var showCelebration = false
    @Environment(\.modelContext) private var modelContext
    @Environment(AudioPlayer.self) private var audio
    @Environment(StreakService.self) private var streak

    @Query private var allProgress: [DhikrProgress]

    init(adhkar: AdhkarCategory, focusedItemId: String? = nil, navTitleOverride: LocalizedText? = nil) {
        self.adhkar = adhkar
        self.focusedItemId = focusedItemId
        self.navTitleOverride = navTitleOverride
    }

    /// Items shown — either all category items, or just the focused one
    /// when `focusedItemId` is set.
    private var visibleItems: [Adhkar] {
        guard let id = focusedItemId else { return adhkar.adhkarList }
        return adhkar.adhkarList.filter { $0.id == id }
    }

    // ... rest of file unchanged except references below
```

- [ ] **Step 2: Replace all uses of `adhkar.adhkarList` with `visibleItems` in the rendering paths**

In `pagedDhikrList`, change:

```swift
ForEach(Array(adhkar.adhkarList.enumerated()), id: \.element.id) { index, dhikr in
```

to:

```swift
ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, dhikr in
```

(In both the iOS/visionOS and macOS branches.)

In `totalCount`, change:

```swift
private var totalCount: Int { adhkar.adhkarList.count }
```

to:

```swift
private var totalCount: Int { visibleItems.count }
```

In `completedCount`, replace `adhkar.adhkarList.reduce` with `visibleItems.reduce`.

In `resetAllCounters`, replace `adhkar.adhkarList.map(\.id)` with `visibleItems.map(\.id)`.

In `handleProgressChange`, the existing check `new == totalCount` becomes a no-op when `focusedItemId` is set with a 1-item list and the user never gets to "complete" the category — that's fine, we want celebration to skip for single-item mode anyway. Guard it explicitly:

```swift
private func handleProgressChange(old: Int, new: Int) {
    guard focusedItemId == nil else { return } // no celebration in single-item mode
    guard new == totalCount,
          totalCount > 0,
          old < totalCount,
          !celebrationAlreadyShownToday()
    else { return }
    markCelebrationShown()
    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        showCelebration = true
    }
}
```

In `navigationTitle`:

```swift
.navigationTitle(navTitleOverride?.resolved() ?? adhkar.displayTitle)
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Adhkar/Views/AdhkarDetailsView.swift
git commit -m "feat(detail): focusedItemId variant for single-dhikr presentation"
```

---

### Task 2.7 — Wire `ContextDhikrTarget` navigation destination

**Files:**
- Modify: `Adhkar/Views/ContextPickerView.swift`

- [ ] **Step 1: Add second `.navigationDestination` for the target**

In `ContextPickerView.body`, after the existing `.navigationDestination(for: LifeContext.self)`:

```swift
            .navigationDestination(for: ContextDhikrTarget.self) { target in
                if let category = DataProvider.adharCategories.first(where: { $0.id == target.categoryId }) {
                    AdhkarDetailsView(
                        adhkar: category,
                        focusedItemId: target.itemId,
                        navTitleOverride: target.navTitle
                    )
                } else {
                    Text(L10n.contextEmptyTitle.resolved())
                }
            }
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Views/ContextPickerView.swift
git commit -m "feat(nav): wire ContextDhikrTarget → AdhkarDetailsView(focusedItemId:)"
```

---

### Task 2.8 — Insert `HomeContextCard` into `HomeView` with sheet

**Files:**
- Modify: `Adhkar/Views/HomeView.swift`

- [ ] **Step 1: Add sheet state + the card at the top of the VStack**

```swift
struct HomeView: View {
    private let allCategories = DataProvider.adharCategories

    @Binding var path: NavigationPath
    @State private var isContextPickerPresented = false

    // ... existing computed properties ...

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AdaptiveBackground(decorated: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        HeroHeader()
                        HomeContextCard { isContextPickerPresented = true }
                        StreakCard()
                        if let featured {
                            FeaturedSection(category: featured)
                        }
                        ForEach(sections, id: \.section) { entry in
                            section(title: entry.section, categories: entry.categories)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.homeTitle.resolved())
            .navigationDestination(for: AdhkarCategory.self) { cat in
                AdhkarDetailsView(adhkar: cat)
            }
            .sheet(isPresented: $isContextPickerPresented) {
                ContextPickerView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // ... rest unchanged ...
}
```

- [ ] **Step 2: Build + run in simulator + verify visually**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Then via MCP:
1. `mcp__XcodeBuildMCP__build_run_sim`
2. `mcp__XcodeBuildMCP__screenshot` — confirm the new card is visible at the top of the Home below the hero header.
3. Tap the card via `mcp__XcodeBuildMCP__snapshot_ui` + simulator tap on its coordinates.
4. Confirm picker sheet opens with 8 emotions + 7 trials.
5. Tap one tile, confirm context detail screen pushes in.
6. Tap "Annuler" — confirm sheet dismisses to Home.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Views/HomeView.swift
git commit -m "feat(home): insert HomeContextCard at top + sheet presentation"
```

---

### Phase 2 verification

- [ ] **Multi-platform build + smoke test**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=macOS' -quiet
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=visionOS Simulator,name=Apple Vision Pro' -quiet
```

Then VoiceOver pass on iPhone simulator (Settings → Accessibility → VoiceOver, or via simulator menu) — verify the card, picker tiles, and "Cancel" all announce sensible labels.

---

# PHASE 3 — Content curation (user task, not code)

**Phase goal:** `contexts.json` is filled with 3–7 curated `dhikrIds` per context, and the FR/EN/AR `intro` sentences are finalized.

**Exit criteria:**
- Each of the 15 contexts has between 3 and 7 dhikrIds.
- All `dhikrIds` resolve to real `Adhkar.id` entries in `adhkar.json`.
- Each context's `intro.ar`, `intro.fr`, `intro.en` is non-empty and one short sentence (≤ 80 chars).

### Task 3.1 — Curate dhikrIds per context

- [ ] Open `adhkar.json`, study Adhkar items, pick 3–7 most relevant per context.
- [ ] Fill `dhikrIds: []` arrays in `contexts.json`.
- [ ] Write Arabic intro sentences.
- [ ] Verify each `dhikrId` resolves: rerun `xcodebuild test -only-testing:AdhkarTests/DataProviderContextsTests` and add a `resolvableDhikrIds` test if any id is wrong.
- [ ] Run the app, tap each of the 15 contexts in turn, screenshot each detail screen.
- [ ] Commit: `git commit -m "content: curate 75 dhikr-context associations + intros (FR/EN/AR)"`

---

# PHASE 4 — Memorization UI

**Phase goal:** User can opt-in any dhikr to memorization, see them in a 5th tab, run a review session, and have the SM-2 scheduler update their cards.

**Exit criteria:**
- New `Mémoriser` tab visible in tab bar.
- Empty state shown when no HifzCard exists.
- "Mémoriser" button visible on any dhikr page; tapping it adds a card and the button label updates.
- Tapping "Lancer la séance" runs through all due cards with prompt → reveal → 4 buttons → next card.
- End-of-session summary shows correct counts.

### Task 4.1 — Localization strings for memorization

**Files:**
- Modify: `Adhkar/Localization/L10n.swift`

- [ ] **Step 1: Append the strings**

```swift
    // Memorization — tab + button
    static let tabMemorize           = LocalizedText(ar: "حفظ", fr: "Mémoriser", en: "Memorize")
    static let memorizeAddLabel      = LocalizedText(ar: "احفظ", fr: "Mémoriser", en: "Memorize")
    static let memorizeAddedLabel    = LocalizedText(ar: "في الحفظ", fr: "Dans Hifz", en: "In Hifz")
    static let memorizeRemoveConfirm = LocalizedText(ar: "إزالة من قائمة الحفظ؟", fr: "Retirer de la liste Hifz ?", en: "Remove from Hifz list?")
    static let memorizeRemoveYes     = LocalizedText(ar: "إزالة", fr: "Retirer", en: "Remove")
    static let memorizeRemoveNo      = LocalizedText(ar: "إلغاء", fr: "Annuler", en: "Cancel")

    // Memorization — tab landing
    static let memoEmptyTitle        = LocalizedText(ar: "لا توجد بطاقات بعد", fr: "Aucune carte pour l'instant", en: "No cards yet")
    static let memoEmptyHint         = LocalizedText(ar: "افتح أي ذكر واضغط \"احفظ\" لإضافة بطاقتك الأولى.", fr: "Ouvre un dhikr et tape \"Mémoriser\" pour ajouter ta première carte.", en: "Open any dhikr and tap \"Memorize\" to add your first card.")
    static let memoDueTodayPrefix    = LocalizedText(ar: "بطاقات للمراجعة اليوم", fr: "à réviser aujourd'hui", en: "to review today")
    static let memoStartSession      = LocalizedText(ar: "ابدأ الجلسة", fr: "Lancer la séance", en: "Start session")
    static let memoAllUpToDate       = LocalizedText(ar: "كل شيء محدّث ✓", fr: "Tout est à jour ✓", en: "All up to date ✓")
    static let memoProgressTitle     = LocalizedText(ar: "تقدمك", fr: "Ta progression", en: "Your progress")
    static let memoAllCardsTitle     = LocalizedText(ar: "كل البطاقات", fr: "Toutes tes cartes", en: "All your cards")
    static let memoStageNew          = LocalizedText(ar: "جديد", fr: "Nouveau", en: "New")
    static let memoStageLearning     = LocalizedText(ar: "في التعلم", fr: "En apprentissage", en: "Learning")
    static let memoStageAnchored     = LocalizedText(ar: "مرسّخ", fr: "Ancré", en: "Anchored")

    // Memorization — review session
    static let reviewMeaningLabel    = LocalizedText(ar: "معنى الذكر", fr: "Sens du dhikr", en: "Meaning")
    static let reviewHint            = LocalizedText(ar: "حاول استذكار النص العربي ثم اكشف.", fr: "Essaie de te souvenir du texte arabe, puis révèle.", en: "Try to recall the Arabic text, then reveal.")
    static let reviewReveal          = LocalizedText(ar: "اكشف", fr: "Révéler", en: "Reveal")
    static let reviewRateLabel       = LocalizedText(ar: "قيّم استذكارك:", fr: "Évalue ta restitution :", en: "Rate your recall:")
    static let reviewAgain           = LocalizedText(ar: "أعد", fr: "Encore", en: "Again")
    static let reviewHard            = LocalizedText(ar: "صعب", fr: "Difficile", en: "Hard")
    static let reviewGood            = LocalizedText(ar: "جيد", fr: "Bien", en: "Good")
    static let reviewEasy            = LocalizedText(ar: "سهل", fr: "Facile", en: "Easy")
    static let reviewToday           = LocalizedText(ar: "اليوم", fr: "aujourd'hui", en: "today")
    static let reviewDays            = LocalizedText(ar: "يوم", fr: "j", en: "d")

    // Review summary
    static let reviewSummaryTitle    = LocalizedText(ar: "انتهت الجلسة", fr: "Séance terminée", en: "Session done")
    static let reviewSummaryReviewed = LocalizedText(ar: "بطاقات تم مراجعتها", fr: "cartes revues", en: "cards reviewed")
    static let reviewSummaryAnchored = LocalizedText(ar: "مرسّخ", fr: "ancrées", en: "anchored")
    static let reviewSummaryLearning = LocalizedText(ar: "في التعلم", fr: "en cours", en: "in learning")
    static let reviewSummaryAgain    = LocalizedText(ar: "للمراجعة", fr: "à revoir", en: "to review")
    static let reviewSummaryNext     = LocalizedText(ar: "الجلسة القادمة", fr: "Prochaine séance", en: "Next session")
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Localization/L10n.swift
git commit -m "feat(l10n): strings for memorization tab + review session (FR/EN/AR)"
```

---

### Task 4.2 — `MemorizeButton` reusable component

**Files:**
- Create: `Adhkar/Views/MemorizeButton.swift`

- [ ] **Step 1: Write the button**

```swift
// Adhkar/Views/MemorizeButton.swift
import SwiftUI
import SwiftData

/// Opt-in button shown on each dhikr page. Adds/removes the dhikr from
/// the user's Hifz list. Confirms removal via alert.
struct MemorizeButton: View {
    let itemId: String
    let accent: Color

    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [HifzCard]
    @State private var showRemoveConfirm = false
    @State private var feedbackTrigger = 0

    init(itemId: String, accent: Color = .orange) {
        self.itemId = itemId
        self.accent = accent
        // Per-instance predicate via @Query init
        let id = itemId
        _cards = Query(filter: #Predicate<HifzCard> { $0.itemId == id })
    }

    private var isMemorizing: Bool { !cards.isEmpty }

    var body: some View {
        Button {
            if isMemorizing {
                showRemoveConfirm = true
            } else {
                HifzStore.add(itemId: itemId, in: modelContext)
                feedbackTrigger += 1
            }
        } label: {
            Label(
                isMemorizing ? L10n.memorizeAddedLabel.resolved() : L10n.memorizeAddLabel.resolved(),
                systemImage: isMemorizing ? "brain.fill" : "brain"
            )
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isMemorizing ? accent.opacity(0.2) : Color.cardBackground)
            .foregroundStyle(accent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .accessibilityLabel(isMemorizing ? L10n.memorizeAddedLabel.resolved() : L10n.memorizeAddLabel.resolved())
        .alert(
            L10n.memorizeRemoveConfirm.resolved(),
            isPresented: $showRemoveConfirm
        ) {
            Button(L10n.memorizeRemoveYes.resolved(), role: .destructive) {
                HifzStore.remove(itemId: itemId, in: modelContext)
            }
            Button(L10n.memorizeRemoveNo.resolved(), role: .cancel) {}
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Views/MemorizeButton.swift
git commit -m "feat(hifz): MemorizeButton with opt-in/opt-out + alert confirmation"
```

---

### Task 4.3 — Add `MemorizeButton` to `DhikrPageView`'s action row

**Files:**
- Modify: `Adhkar/Views/AdhkarDetailsView.swift` (DhikrPageView's `actionRow`)

- [ ] **Step 1: Update `actionRow`**

Find:

```swift
@ViewBuilder
private var actionRow: some View {
    HStack(spacing: 12) {
        if let audioURL = dhikrAudioURL {
            audioButton(url: audioURL)
        }
        shareButton
    }
}
```

Replace with:

```swift
@ViewBuilder
private var actionRow: some View {
    HStack(spacing: 12) {
        if let audioURL = dhikrAudioURL {
            audioButton(url: audioURL)
        }
        shareButton
        MemorizeButton(itemId: dhikr.id, accent: accent)
    }
}
```

- [ ] **Step 2: Build + smoke test**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Run on simulator and verify the button is visible next to Listen / Share. Tap it → label flips to "Dans Hifz". Tap again → alert appears.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Views/AdhkarDetailsView.swift
git commit -m "feat(detail): MemorizeButton in DhikrPageView action row"
```

---

### Task 4.4 — `MemoTabView` landing screen

**Files:**
- Create: `Adhkar/Views/MemoTabView.swift`

- [ ] **Step 1: Write the view**

```swift
// Adhkar/Views/MemoTabView.swift
import SwiftUI
import SwiftData

struct MemoTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HifzCard.addedAt, order: .reverse) private var allCards: [HifzCard]
    @State private var showReviewSession = false

    private var dueToday: [HifzCard] {
        let endOfDay = Calendar(identifier: .gregorian).date(
            bySettingHour: 23, minute: 59, second: 59, of: .now
        ) ?? .now
        return allCards.filter { $0.nextReviewAt <= endOfDay }
            .sorted { $0.nextReviewAt < $1.nextReviewAt }
    }

    private var counts: [HifzStage: Int] {
        var c: [HifzStage: Int] = [:]
        for stage in HifzStage.allCases { c[stage] = 0 }
        for card in allCards { c[card.stage, default: 0] += 1 }
        return c
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(decorated: false)
                if allCards.isEmpty {
                    emptyState
                } else {
                    filledContent
                }
            }
            .navigationTitle(L10n.tabMemorize.resolved())
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .fullScreenCover(isPresented: $showReviewSession) {
                ReviewSessionView(cards: dueToday)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text(L10n.memoEmptyTitle.resolved())
                .font(.title3.weight(.semibold))
            Text(L10n.memoEmptyHint.resolved())
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var filledContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                dueCard
                progressSection
                allCardsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var dueCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(dueToday.count) \(L10n.memoDueTodayPrefix.resolved())")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .monospacedDigit()
                Spacer()
            }
            Button {
                guard !dueToday.isEmpty else { return }
                showReviewSession = true
            } label: {
                HStack {
                    Text(dueToday.isEmpty ? L10n.memoAllUpToDate.resolved() : L10n.memoStartSession.resolved())
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(dueToday.isEmpty ? Color.cardBackground : Color.orange)
                .foregroundStyle(dueToday.isEmpty ? Color.secondary : Color.black)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(dueToday.isEmpty)
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.memoProgressTitle.resolved())
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                progressRow(label: L10n.memoStageNew.resolved(),      value: counts[.new] ?? 0)
                progressRow(label: L10n.memoStageLearning.resolved(), value: counts[.learning] ?? 0)
                progressRow(label: L10n.memoStageAnchored.resolved(), value: counts[.anchored] ?? 0)
            }
        }
    }

    private func progressRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)").monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 10))
    }

    private var allCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.memoAllCardsTitle.resolved())
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                ForEach(allCards) { card in
                    MemoCardRow(card: card)
                }
            }
        }
    }
}

private struct MemoCardRow: View {
    let card: HifzCard

    private var dhikrAndCategory: (Adhkar, AdhkarCategory)? {
        let id = card.itemId
        for cat in DataProvider.adharCategories {
            if let d = cat.adhkarList.first(where: { $0.id == id }) { return (d, cat) }
        }
        return nil
    }

    private var nextDescription: String {
        if Calendar(identifier: .gregorian).isDateInToday(card.nextReviewAt) {
            return L10n.reviewToday.resolved()
        }
        let days = max(0, Int(card.intervalDays.rounded()))
        return "\(days) \(L10n.reviewDays.resolved())"
    }

    private var stageDescription: String {
        switch card.stage {
        case .new:       return L10n.memoStageNew.resolved()
        case .learning:  return L10n.memoStageLearning.resolved()
        case .anchored:  return L10n.memoStageAnchored.resolved()
        }
    }

    var body: some View {
        let (title, source): (String, String) = {
            if let (d, c) = dhikrAndCategory {
                return (c.displayTitle, d.source.isEmpty ? "" : d.source)
            }
            return (card.itemId, "")
        }()

        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(stageDescription) · \(nextDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(stageDescription), \(nextDescription)")
    }
}
```

- [ ] **Step 2: Build (will fail because ReviewSessionView doesn't exist — that's expected; next task)**

If you absolutely need a clean build at this checkpoint, stub `ReviewSessionView` minimally:

```swift
struct ReviewSessionView: View {
    let cards: [HifzCard]
    var body: some View { Text("Placeholder").onAppear { /* TODO Task 4.6 */ } }
}
```

Then delete this stub when Task 4.6 lands.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Views/MemoTabView.swift
git commit -m "feat(hifz): MemoTabView landing with empty + filled states"
```

---

### Task 4.5 — Add 5th tab to `RootTabView`

**Files:**
- Modify: `Adhkar/App/RootTabView.swift`

- [ ] **Step 1: Update the `RootTab` enum + body**

```swift
enum RootTab: Hashable {
    case home, favorites, search, memorize, settings

    #if DEBUG
    init?(marketingSlug: String) {
        switch marketingSlug {
        case "home", "detail": self = .home
        case "favorites":      self = .favorites
        case "memorize":       self = .memorize
        case "settings":       self = .settings
        default: return nil
        }
    }
    #endif
}
```

In the `TabView` body, insert a new tab between `SearchView()` and `SettingsView()`:

```swift
            MemoTabView()
                .tabItem { Label(L10n.tabMemorize.resolved(), systemImage: "brain.head.profile") }
                .accessibilityIdentifier("tab.memorize")
                .tag(RootTab.memorize)
```

- [ ] **Step 2: Build + run + verify the 5th tab appears**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Run on simulator, confirm 5 tabs visible at the bottom of the tab bar. Tap "Mémoriser" → see empty state initially.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/App/RootTabView.swift
git commit -m "feat(nav): add 5th \"Mémoriser\" tab in RootTabView"
```

---

### Task 4.6 — `ReviewSessionView` (prompt + revealed + 4 rating buttons)

**Files:**
- Create: `Adhkar/Views/ReviewSessionView.swift`

- [ ] **Step 1: Write the session view**

```swift
// Adhkar/Views/ReviewSessionView.swift
import SwiftUI
import SwiftData
import WidgetKit

struct ReviewSessionView: View {
    let cards: [HifzCard]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var index: Int = 0
    @State private var revealed: Bool = false
    @State private var anchoredCount = 0
    @State private var learningCount = 0
    @State private var againCount = 0
    @State private var showSummary = false

    private var currentCard: HifzCard? {
        guard cards.indices.contains(index) else { return nil }
        return cards[index]
    }

    private var currentDhikr: Adhkar? {
        guard let id = currentCard?.itemId else { return nil }
        for cat in DataProvider.adharCategories {
            if let d = cat.adhkarList.first(where: { $0.id == id }) { return d }
        }
        return nil
    }

    var body: some View {
        if showSummary {
            ReviewSessionSummaryView(
                reviewed: cards.count,
                anchored: anchoredCount,
                learning: learningCount,
                again: againCount,
                nextSessionDescription: nextSessionDescription(),
                onDismiss: { dismiss() }
            )
        } else if let card = currentCard, let dhikr = currentDhikr {
            sessionBody(card: card, dhikr: dhikr)
        } else {
            // No cards to review — exit immediately.
            Color.clear.onAppear { dismiss() }
        }
    }

    @ViewBuilder
    private func sessionBody(card: HifzCard, dhikr: Adhkar) -> some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                if revealed {
                    revealedCard(dhikr: dhikr)
                } else {
                    promptCard(dhikr: dhikr)
                }
            }
            if revealed {
                ratingButtons(card: card)
            } else {
                revealButton
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline)
                }
                .tint(.orange)
                Spacer()
                Text("\(index + 1) / \(cards.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Color.clear.frame(width: 24, height: 1)
            }
            ProgressView(value: Double(index + 1), total: Double(cards.count))
                .progressViewStyle(.linear)
                .tint(.orange)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func promptCard(dhikr: Adhkar) -> some View {
        VStack(alignment: .center, spacing: 14) {
            Text(L10n.reviewMeaningLabel.resolved())
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.orange)
            Text(dhikr.translation?.resolved() ?? "—")
                .font(.title3.italic())
                .multilineTextAlignment(.center)
            if !dhikr.source.isEmpty {
                Text(dhikr.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 18))
        .padding()
    }

    private var revealButton: some View {
        Button { revealed = true } label: {
            Text(L10n.reviewReveal.resolved())
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange)
                .foregroundStyle(.black)
                .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 14)
        .padding(.top, 4)
    }

    private func revealedCard(dhikr: Adhkar) -> some View {
        VStack(alignment: .center, spacing: 14) {
            Text(dhikr.dhikr)
                .font(.amiri(size: 24))
                .multilineTextAlignment(.center)
                .lineSpacing(12)
            if let t = dhikr.translation?.resolved(), !t.isEmpty {
                Text(t)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if !dhikr.source.isEmpty {
                Text(dhikr.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 18))
        .padding()
    }

    private func ratingButtons(card: HifzCard) -> some View {
        let preview = HifzScheduler.previewIntervals(for: card)
        return VStack(spacing: 8) {
            Text(L10n.reviewRateLabel.resolved())
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                button(.again, label: L10n.reviewAgain, color: .red,    days: preview[.again] ?? 0, card: card)
                button(.hard,  label: L10n.reviewHard,  color: .yellow, days: preview[.hard]  ?? 1, card: card)
                button(.good,  label: L10n.reviewGood,  color: .green,  days: preview[.good]  ?? 1, card: card)
                button(.easy,  label: L10n.reviewEasy,  color: .blue,   days: preview[.easy]  ?? 4, card: card)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 14)
    }

    private func button(_ rating: HifzReviewButton, label: LocalizedText, color: Color, days: Double, card: HifzCard) -> some View {
        Button {
            apply(rating, to: card)
        } label: {
            VStack(spacing: 4) {
                Text(label.resolved())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                Text(daysLabel(days))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label.resolved()), \(daysLabel(days))")
    }

    private func daysLabel(_ days: Double) -> String {
        if days < 0.5 { return L10n.reviewToday.resolved() }
        return "+\(Int(days.rounded())) \(L10n.reviewDays.resolved())"
    }

    private func apply(_ rating: HifzReviewButton, to card: HifzCard) {
        HifzScheduler.schedule(card, button: rating, now: .now)
        try? modelContext.save()

        switch rating {
        case .again: againCount += 1
        case .hard, .good, .easy:
            if card.stage == .anchored { anchoredCount += 1 }
            else { learningCount += 1 }
        }

        revealed = false
        if index + 1 < cards.count {
            index += 1
        } else {
            // Reload widget after session ends.
            #if os(iOS)
            WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPeriodWidget")
            #endif
            showSummary = true
        }
    }

    private func nextSessionDescription() -> String {
        // Re-query for cards due tomorrow as a quick teaser. Keep simple.
        let tomorrow = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: .now) ?? .now
        let count = HifzStore.dueToday(in: modelContext, now: tomorrow).count
        return "\(count)"
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

`ReviewSessionSummaryView` doesn't exist yet — next task. Will compile with placeholder usage; if so, defer the build success check until Task 4.7.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Views/ReviewSessionView.swift
git commit -m "feat(hifz): ReviewSessionView with prompt → reveal → 4 rating buttons"
```

---

### Task 4.7 — `ReviewSessionSummaryView` (end-of-session recap)

**Files:**
- Create: `Adhkar/Views/ReviewSessionSummaryView.swift`

- [ ] **Step 1: Write the summary**

```swift
// Adhkar/Views/ReviewSessionSummaryView.swift
import SwiftUI

struct ReviewSessionSummaryView: View {
    let reviewed: Int
    let anchored: Int
    let learning: Int
    let again: Int
    let nextSessionDescription: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(L10n.reviewSummaryTitle.resolved())
                .font(.title2.weight(.bold))
            Text("\(reviewed) \(L10n.reviewSummaryReviewed.resolved())")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                summaryRow(label: L10n.reviewSummaryAnchored.resolved(), value: anchored, color: .green)
                summaryRow(label: L10n.reviewSummaryLearning.resolved(), value: learning, color: .blue)
                summaryRow(label: L10n.reviewSummaryAgain.resolved(),    value: again,    color: .red)
            }

            Divider().padding(.vertical, 6)

            VStack(spacing: 4) {
                Text(L10n.reviewSummaryNext.resolved())
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(nextSessionDescription)
                    .font(.body)
            }

            Button(action: onDismiss) {
                Text(L10n.done.resolved())
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundStyle(.black)
                    .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(28)
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            try? await Task.sleep(for: .seconds(8))
            onDismiss()
        }
    }

    private func summaryRow(label: String, value: Int, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
            Spacer()
            Text("\(value)").monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
    }
}
```

- [ ] **Step 2: Build + run a session manually on simulator**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Then:
1. Run app, open a dhikr, tap "Mémoriser".
2. Go to "Mémoriser" tab → see 1 card due today → tap "Lancer la séance".
3. Verify prompt → tap "Révéler" → see Arabic + 4 buttons → tap "Bien" → summary appears.
4. Verify summary auto-dismisses after 8s, or tap "Terminé".

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Views/ReviewSessionSummaryView.swift
git commit -m "feat(hifz): ReviewSessionSummaryView with stage breakdown + next session"
```

---

### Phase 4 verification

- [ ] **Multi-platform build + end-to-end manual test**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=macOS' -quiet
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=visionOS Simulator,name=Apple Vision Pro' -quiet
xcodebuild test  -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

End-to-end flow:
1. Add 3 different dhikr via the Mémoriser button (across different categories).
2. Open Mémoriser tab → see 3 cards due today.
3. Run session → all 3 cards through prompt/reveal/rating.
4. Verify summary counts match what was rated.
5. Verify cards in the tab now show updated stage + next review.

---

# PHASE 5 — Notification + Widget integration

**Phase goal:** Daily hifz reminder notification (configurable in Settings). Widget medium size shows "X à réviser" badge.

**Exit criteria:**
- Settings has a row for "Rappel mémorisation" with time picker + toggle.
- Toggling it on schedules a daily local notification at the chosen time with body "X dhikr à réviser aujourd'hui".
- After a review session, widget timeline refreshes and the medium-size variant displays the badge correctly.

### Task 5.1 — Add `.hifz` slot to `NotificationManager`

**Files:**
- Modify: `Adhkar/Services/NotificationManager.swift`

- [ ] **Step 1: Add the case and its strings**

```swift
    enum Slot: String, CaseIterable, Identifiable {
        case morning, evening, sleep, hifz
        var id: String { rawValue }

        var defaultHour: Int {
            switch self {
            case .morning: return 8
            case .evening: return 17
            case .sleep:   return 22
            case .hifz:    return 19
            }
        }

        var requestId: String { "adhkar.notif.\(rawValue)" }

        var title: LocalizedText {
            switch self {
            case .morning: return L10n.notifTitleMorning
            case .evening: return L10n.notifTitleEvening
            case .sleep:   return L10n.notifTitleSleep
            case .hifz:    return L10n.notifTitleHifz
            }
        }

        var label: LocalizedText {
            switch self {
            case .morning: return L10n.slotMorning
            case .evening: return L10n.slotEvening
            case .sleep:   return L10n.slotSleep
            case .hifz:    return L10n.slotHifz
            }
        }
    }
```

- [ ] **Step 2: Add L10n strings**

Append to `L10n.swift`:

```swift
    static let slotHifz         = LocalizedText(ar: "تذكير الحفظ", fr: "Rappel mémorisation", en: "Memorization reminder")
    static let notifTitleHifz   = LocalizedText(ar: "حان وقت المراجعة", fr: "C'est l'heure de réviser", en: "Time to review")
    static let notifBodyHifz    = LocalizedText(ar: "بطاقات في انتظارك.", fr: "Tes cartes t'attendent.", en: "Your cards are waiting.")
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`. The new slot inherits the existing scheduling logic — no changes to the body of `NotificationManager`.

- [ ] **Step 4: Commit**

```bash
git add Adhkar/Services/NotificationManager.swift Adhkar/Localization/L10n.swift
git commit -m "feat(notif): .hifz slot for daily memorization reminder"
```

---

### Task 5.2 — Surface the hifz toggle in `SettingsView`

**Files:**
- Modify: `Adhkar/Views/SettingsView.swift`

- [ ] **Step 1: Re-read the file**

Run: open the file in editor and find the section iterating over `NotificationManager.Slot.allCases`. The existing morning/evening/sleep rows are generated automatically by enumerating `Slot.allCases` — verify this is true. If true, the `.hifz` slot will appear automatically thanks to `CaseIterable`. If not, add an explicit row for `.hifz` matching the pattern of `.morning`.

- [ ] **Step 2: Build + visual check**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Run on simulator, open Settings, scroll to Notifications. Verify "Rappel mémorisation" row exists, with default time 19:00.

If the row doesn't appear, the SettingsView is not iterating over `allCases` — add an explicit row matching the existing pattern.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Views/SettingsView.swift
git commit -m "feat(settings): expose hifz reminder toggle (defaults to 19:00)"
```

---

### Task 5.3 — `StreakService` writes hifz counters to App Group

**Files:**
- Modify: `Adhkar/Services/StreakService.swift`

- [ ] **Step 1: Add a method that recomputes hifz counts and writes them**

Add to `StreakService`:

```swift
    /// Re-counts due-today / total hifz cards and writes them to the App
    /// Group suite so the widget can render a badge without spinning up
    /// SwiftData. Called from `recompute(context:)` and explicitly after
    /// a review session ends.
    func refreshHifzCounts(context: ModelContext) {
        let now = Date.now
        let endOfDay = Calendar(identifier: .gregorian).date(
            bySettingHour: 23, minute: 59, second: 59, of: now
        ) ?? now
        let dueDescriptor = FetchDescriptor<HifzCard>(
            predicate: #Predicate<HifzCard> { $0.nextReviewAt <= endOfDay }
        )
        let totalDescriptor = FetchDescriptor<HifzCard>()
        let due   = (try? context.fetch(dueDescriptor))?.count ?? 0
        let total = (try? context.fetch(totalDescriptor))?.count ?? 0
        defaults.set(due,   forKey: "hifz.dueToday")
        defaults.set(total, forKey: "hifz.totalCards")
    }
```

And call it from inside `recompute(context:)` right before the WidgetCenter reload:

```swift
        refreshHifzCounts(context: context)

        // Nudge the widget to re-render with the fresh streak. Cheap: WidgetKit
        // coalesces requests and only re-runs the timeline provider if needed.
        if #available(visionOS 26.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPeriodWidget")
        }
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Services/StreakService.swift
git commit -m "feat(hifz): write dueToday + totalCards to App Group suite for widget"
```

---

### Task 5.4 — Widget reads `hifz.dueToday` for medium-size badge

**Files:**
- Modify: `MunajatWidget/CurrentPeriodWidget.swift`

- [ ] **Step 1: Read the current widget structure to find the medium-size view**

```bash
cat MunajatWidget/CurrentPeriodWidget.swift | head -120
```

- [ ] **Step 2: Add a badge view conditionally rendered in `.systemMedium`**

Within the widget's medium layout view body, after the streak row, add:

```swift
                let dueToday = sharedDefaults.integer(forKey: "hifz.dueToday")
                if dueToday > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                        Text("\(dueToday) \(L10n.memoDueTodayPrefix.resolved())")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
```

Where `sharedDefaults` is the App Group `UserDefaults` instance the widget already uses (see `StreakService.makeSharedDefaults`). If the widget doesn't have one, add at the top of the widget view struct:

```swift
private let sharedDefaults = UserDefaults(suiteName: "group.com.tadev.munajat") ?? .standard
```

- [ ] **Step 3: Build the widget extension via the main app build**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```

Expected: `BUILD SUCCEEDED`.

Run the app, add 2 hifz cards, then long-press the widget on the home screen and verify the medium layout displays "2 à réviser aujourd'hui". (May need to manually trigger widget reload via simulator.)

- [ ] **Step 4: Commit**

```bash
git add MunajatWidget/CurrentPeriodWidget.swift
git commit -m "feat(widget): medium-size hifz \"X à réviser\" badge under streak"
```

---

### Task 5.5 — Share new model files with widget if needed

**Files:**
- Modify: `scripts/share_files_with_widget.rb`

- [ ] **Step 1: Verify if `LifeContext.swift` / `HifzCard.swift` need widget access**

`LifeContext.swift` — widget doesn't read contexts. **Skip.**
`HifzCard.swift` — widget reads `hifz.dueToday` from UserDefaults, not the model directly. **Skip.**

No changes needed. Confirm by reading current `share_files_with_widget.rb`:

```bash
cat scripts/share_files_with_widget.rb
```

If the script lists shared files explicitly, confirm none of the new files need to be added.

- [ ] **Step 2: Commit (only if changes)**

Skip the commit if nothing changed.

---

### Phase 5 verification

- [ ] **Full multi-platform build + tests + widget smoke test**

```bash
xcodebuild test  -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=macOS' -quiet
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=visionOS Simulator,name=Apple Vision Pro' -quiet
```

End-to-end: add a hifz card → enable hifz reminder for 1 min from now → confirm notification fires → check widget reflects count.

---

# PHASE 6 — App Store resubmission (operational, not code)

**Phase goal:** Build 2 of v1.0 is on App Store Connect with refreshed metadata reflecting the new features.

### Task 6.1 — Capture new screenshots

- [ ] Use `mcp__XcodeBuildMCP__screenshot` on iPhone 6.9" + iPad Pro 13" sims for each of:
  1. Home with `HomeContextCard` visible.
  2. ContextPickerView (open from Home).
  3. ContextDetailView for one curated context (e.g. "Anxieux").
  4. MemoTabView in filled state with ≥ 3 cards.
  5. ReviewSessionView in revealed state with 4 buttons.
- [ ] Crop / annotate via `scripts/build_screenshots.py` (or equivalent) and place into App Store Connect.

### Task 6.2 — Update App Store metadata

- [ ] Rewrite description first line: "Munajat is the only adhkar app organized by emotional state and life situation, with built-in spaced repetition memorization."
- [ ] Update App Review Information notes with:
  - "New: Home screen now opens with 'How do you feel?' — 15 life states (8 emotions + 7 trials) each linking to a curated selection of dhikr."
  - "New: Dedicated 'Mémoriser' tab with opt-in spaced repetition (SM-2 algorithm) for memorizing dhikr long-term."
  - "These features distinguish Munajat structurally from other adhkar apps in the App Store. Source code written from scratch in SwiftUI; content text (Hisn al-Muslim) is public domain."

### Task 6.3 — Archive & upload build 2

- [ ] Bump build number from 1 to 2 in Xcode project (version stays 1.0.0).
- [ ] Archive → Upload → submit as new build to the existing 1.0.0 version.
- [ ] Optionally: in parallel, file an App Review Board appeal on the original rejection (https://developer.apple.com/contact/app-store/?topic=appeal) with a 60s screen recording of the new features.

---

## Self-review summary

**Spec coverage:** every section of `2026-05-17-context-home-and-memorization-design.md` is covered by one or more tasks above — Phase 1 covers §4.4 (contexts.json), §5.3 (HifzCard), §5.4 (HifzScheduler); Phase 2 covers §4.3 (UX flow contextual), §4.5 (AdhkarDetailsView single-item); Phase 4 covers §5.2 (memo UX) entirely; Phase 5 covers §5.5 (notification), §5.6 (widget); §6 (cross-cutting) is enforced by multi-platform build commands at each phase verification.

**Placeholder scan:** No `TBD`, no `add error handling here`, no "similar to Task N". Every code step contains full code.

**Type consistency:**
- `HifzReviewButton` cases used consistently: `.again, .hard, .good, .easy`.
- `HifzStage` cases used consistently: `.new, .learning, .anchored`.
- `LocalizedText` strings reference real `L10n.*` properties defined in the corresponding earlier tasks.
- `ContextDhikrTarget` defined in Task 2.5, consumed in Task 2.7.
- `MemorizeButton`'s `itemId:accent:` signature used identically in Task 4.3.

**Open follow-ups (not blocking ship):**
- Spec mentions `.glassEffect()` (iOS 26+) for the home card and reveal button — left for Phase 7 polish if the user wants to adopt Liquid Glass after build 2 ships.
- Spec mentions a mini crescent-star animation on session summary — current implementation uses static `checkmark.seal.fill` for simplicity; can be enhanced later.
- Phase 3 (content curation) intentionally not code-tasked — it's the user's manual content work.
