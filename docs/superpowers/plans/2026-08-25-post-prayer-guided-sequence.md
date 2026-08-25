# Guided post-prayer sequence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guide the user through the twelve post-prayer adhkar of Hisn al-Muslim, counting each one, driven by the content already bundled in the app.

**Architecture:** A static step definition splits two JSON items whose Arabic bundles dhikr with different repetition counts, and passes the other six through untouched. A pure `PostPrayerSession` value type holds all progression logic so it is unit-testable without SwiftUI. The screen is a `fullScreenCover` from Home holding the session in `@State` with a `@SceneStorage` snapshot. No SwiftData model, no schema migration, no change to `DhikrProgress`.

**Tech Stack:** SwiftUI, Swift Testing, existing `LocalizedText` / `L10n` localisation, existing `DataProvider`, `AudioPlayer` and `StreakService`.

**Spec:** `docs/superpowers/specs/2026-08-25-post-prayer-guided-sequence-design.md`

## Global Constraints

- **No `import UIKit`.** The `Adhkar` target builds for iOS, macOS and visionOS.
- Haptics via `.sensoryFeedback(.impact, trigger:)`, never `UIImpactFeedbackGenerator`.
- Colours from the asset catalogue: `Color("CardBackground")`, never `Color(.secondarySystemBackground)`.
- iOS-only SwiftUI modifiers need `#if os(iOS) || os(visionOS)`.
- Every user-visible string is a `static let` on `L10n` typed `LocalizedText(ar:fr:en:)`. No `.xcstrings`.
- Single accent colour: `.orange`. Do not reintroduce per-section colours.
- Files dropped anywhere under `Adhkar/` are auto-bundled by the synchronized root group. **Do not hand-edit `project.pbxproj`.**
- New files under `AdhkarTests/` are **not** auto-bundled: run `ruby scripts/sync_test_sources.rb` after creating one.
- Deployment floor is iOS 17.0 / macOS 14.0 / visionOS 1.0 — no API newer than that without an `@available` guard.
- Test command: `xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

---

### Task 1: Step definition and the twelve steps

**Files:**
- Create: `Adhkar/Models/PostPrayerSequence.swift`
- Test: `AdhkarTests/PostPrayerSequenceTests.swift`

**Interfaces:**
- Consumes: `Adhkar`, `AdhkarCategory`, `LocalizedText`, `DataProvider.adharCategories` (all existing).
- Produces: `PrayerScope`, `PostPrayerStep` (`id`, `itemId`, `arabic`, `transliteration`, `translation`, `repetitions`, `advancesAutomatically`, `onlyAfter`, `displayArabic`, `displayTransliteration`, `displayTranslation`, `sourceItem`), `PostPrayerSequence.steps: [PostPrayerStep]`, `PostPrayerSequence.categoryId`, `PostPrayerSequence.item(for:)`.

- [ ] **Step 1: Write the failing test**

Create `AdhkarTests/PostPrayerSequenceTests.swift`:

```swift
// AdhkarTests/PostPrayerSequenceTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("PostPrayerSequence")
struct PostPrayerSequenceTests {

    @Test func hasTwelveStepsInJSONOrder() {
        let steps = PostPrayerSequence.steps
        #expect(steps.count == 12)
        // Split steps keep the ordinal of the item they came from, so the
        // referenced item ids must never go backwards.
        let ordinals = steps.compactMap { Int($0.itemId.replacingOccurrences(
            of: "after_prayer_adhkar_", with: "")) }
        #expect(ordinals.count == 12)
        #expect(ordinals == ordinals.sorted())
    }

    // Guard: build_adhkar.py regenerates adhkar.json. If it ever renumbers
    // the items, this fails loudly instead of showing blank steps.
    @Test func everyReferencedItemExistsInTheBundledJSON() throws {
        let category = try #require(PostPrayerSequence.category)
        for step in PostPrayerSequence.steps {
            #expect(category.adhkarList.contains { $0.id == step.itemId },
                    "missing JSON item \(step.itemId) for step \(step.id)")
        }
    }

    @Test func theTasbihatTotalOneHundred() {
        let hundred = PostPrayerSequence.steps.filter { $0.itemId == "after_prayer_adhkar_4" }
        #expect(hundred.count == 4)
        #expect(hundred.reduce(0) { $0 + $1.repetitions } == 100)
    }

    @Test func everyStepHasArabicToShow() {
        for step in PostPrayerSequence.steps {
            #expect(!step.displayArabic.isEmpty, "step \(step.id) resolves to empty Arabic")
        }
    }

    @Test func onlyTheLastTwoStepsAreConditional() {
        let conditional = PostPrayerSequence.steps.filter { $0.onlyAfter != nil }
        #expect(conditional.count == 2)
        #expect(conditional.map(\.itemId) == ["after_prayer_adhkar_7", "after_prayer_adhkar_8"])
    }

    // Auto-advance keeps the finger on the button inside a group of like
    // recitations, and stops where the nature of the dhikr changes.
    @Test func autoAdvanceCoversExactlyTheGroupedSteps() {
        let auto = PostPrayerSequence.steps.filter(\.advancesAutomatically).map(\.id)
        #expect(auto == ["istighfar", "subhanallah", "alhamdulillah", "allahuakbar"])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
ruby scripts/sync_test_sources.rb
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|✘"
```

Expected: compilation failure — `cannot find 'PostPrayerSequence' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Adhkar/Models/PostPrayerSequence.swift`:

```swift
//
//  PostPrayerSequence.swift
//  Adhkar
//

import Foundation

/// Prayers after which a step is recited. Display-only: the app has no
/// prayer times, so the user decides whether the step applies.
enum PrayerScope: Hashable {
    case fajr
    case fajrAndMaghrib

    var label: LocalizedText {
        switch self {
        case .fajr:
            LocalizedText(ar: "بعد الفجر", fr: "après Fajr", en: "after Fajr")
        case .fajrAndMaghrib:
            LocalizedText(ar: "بعد الفجر والمغرب", fr: "après Fajr et Maghrib", en: "after Fajr and Maghrib")
        }
    }
}

/// One countable step of the guided sequence.
///
/// `arabic`, `transliteration` and `translation` are non-nil only for steps
/// split out of a JSON item that bundled several dhikr; otherwise the values
/// come from the referenced `Adhkar`.
struct PostPrayerStep: Identifiable, Hashable {
    let id: String
    let itemId: String
    let arabic: String?
    let transliteration: LocalizedText?
    let translation: LocalizedText?
    let repetitions: Int
    let advancesAutomatically: Bool
    let onlyAfter: PrayerScope?

    init(id: String,
         itemId: String,
         arabic: String? = nil,
         transliteration: LocalizedText? = nil,
         translation: LocalizedText? = nil,
         repetitions: Int,
         advancesAutomatically: Bool = false,
         onlyAfter: PrayerScope? = nil) {
        self.id = id
        self.itemId = itemId
        self.arabic = arabic
        self.transliteration = transliteration
        self.translation = translation
        self.repetitions = repetitions
        self.advancesAutomatically = advancesAutomatically
        self.onlyAfter = onlyAfter
    }

    var sourceItem: Adhkar? { PostPrayerSequence.item(for: itemId) }
    var displayArabic: String { arabic ?? sourceItem?.dhikr ?? "" }
    var displayTransliteration: String? {
        let text = transliteration ?? sourceItem?.transliteration
        let resolved = text?.resolved()
        return (resolved?.isEmpty ?? true) ? nil : resolved
    }
    var displayTranslation: String? {
        let text = translation ?? sourceItem?.translation
        let resolved = text?.resolved()
        return (resolved?.isEmpty ?? true) ? nil : resolved
    }
}

/// The post-prayer adhkar of Hisn al-Muslim, in the order of
/// `after_prayer_adhkar` in `adhkar.json` — the order is the source's, not a
/// product decision, and must not be changed.
///
/// An item is split **only when the dhikr it bundles carry different
/// repetition counts**: item 1 (istighfār three times, then the salām formula
/// once) and item 4 (three tasbihāt thirty-three times each, then the tahlīl
/// that completes the hundred). Item 5 holds three sūrahs but each is recited
/// once, and the JSON supplies them as one unit — it stays whole.
enum PostPrayerSequence {
    static let categoryId = "after_prayer_adhkar"

    static var category: AdhkarCategory? {
        DataProvider.adharCategories.first { $0.id == categoryId }
    }

    static func item(for id: String) -> Adhkar? {
        category?.adhkarList.first { $0.id == id }
    }

    static let steps: [PostPrayerStep] = [
        PostPrayerStep(
            id: "istighfar",
            itemId: "after_prayer_adhkar_1",
            arabic: "أَسْتَغْفِرُ اللهَ",
            transliteration: LocalizedText(fr: "Astaghfiru-Llāh", en: "Astaghfiru-Llāh"),
            translation: LocalizedText(
                ar: "أستغفر الله",
                fr: "Je demande pardon à Allah.",
                en: "I ask Allah for forgiveness."),
            repetitions: 3,
            advancesAutomatically: true),

        PostPrayerStep(
            id: "salam",
            itemId: "after_prayer_adhkar_1",
            arabic: "اللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ",
            transliteration: LocalizedText(
                fr: "Allāhumma anta-s-salām, wa minka-s-salām, tabārakta yā dhā-l-jalāli wa-l-ikrām",
                en: "Allāhumma anta-s-salām, wa minka-s-salām, tabārakta yā dhā-l-jalāli wa-l-ikrām"),
            translation: LocalizedText(
                fr: "Ô Allah, Tu es la Paix et de Toi vient la paix. Béni sois-Tu, ô Détenteur de la majesté et de la générosité.",
                en: "O Allah, You are As-Salām and from You is all peace, blessed are You, O Possessor of majesty and honour."),
            repetitions: 1),

        PostPrayerStep(id: "tahlil-full", itemId: "after_prayer_adhkar_2", repetitions: 1),
        PostPrayerStep(id: "tahlil-quwwa", itemId: "after_prayer_adhkar_3", repetitions: 1),

        PostPrayerStep(
            id: "subhanallah",
            itemId: "after_prayer_adhkar_4",
            arabic: "سُبْحَانَ اللهِ",
            transliteration: LocalizedText(fr: "Subḥāna-Llāh", en: "Subḥāna-Llāh"),
            translation: LocalizedText(fr: "Gloire à Allah.", en: "How perfect Allah is."),
            repetitions: 33,
            advancesAutomatically: true),

        PostPrayerStep(
            id: "alhamdulillah",
            itemId: "after_prayer_adhkar_4",
            arabic: "الْحَمْدُ لِلَّهِ",
            transliteration: LocalizedText(fr: "Al-ḥamdu li-Llāh", en: "Al-ḥamdu li-Llāh"),
            translation: LocalizedText(fr: "Louange à Allah.", en: "All praise is for Allah."),
            repetitions: 33,
            advancesAutomatically: true),

        PostPrayerStep(
            id: "allahuakbar",
            itemId: "after_prayer_adhkar_4",
            arabic: "اللهُ أَكْبَرُ",
            transliteration: LocalizedText(fr: "Allāhu akbar", en: "Allāhu akbar"),
            translation: LocalizedText(fr: "Allah est le plus grand.", en: "Allah is the greatest."),
            repetitions: 33,
            advancesAutomatically: true),

        PostPrayerStep(
            id: "tahlil-hundred",
            itemId: "after_prayer_adhkar_4",
            arabic: "لَا إِلَهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
            transliteration: LocalizedText(
                fr: "Lā ilāha illa-Llāh waḥdahu lā sharīka lah, lahu-l-mulku wa lahu-l-ḥamd, wa huwa ʿalā kulli shay'in qadīr",
                en: "Lā ilāha illa-Llāh waḥdahu lā sharīka lah, lahu-l-mulku wa lahu-l-ḥamd, wa huwa ʿalā kulli shay'in qadīr"),
            translation: LocalizedText(
                fr: "Il n'y a de divinité qu'Allah, Seul, sans associé. À Lui la royauté, à Lui la louange, et Il est capable de toute chose.",
                en: "None has the right to be worshipped except Allah, alone, without partner; to Him belongs all sovereignty and praise, and He is over all things omnipotent."),
            repetitions: 1),

        PostPrayerStep(id: "suras", itemId: "after_prayer_adhkar_5", repetitions: 1),
        PostPrayerStep(id: "ayat-al-kursi", itemId: "after_prayer_adhkar_6", repetitions: 1),
        PostPrayerStep(id: "tahlil-ten", itemId: "after_prayer_adhkar_7",
                       repetitions: 10, onlyAfter: .fajrAndMaghrib),
        PostPrayerStep(id: "beneficial-knowledge", itemId: "after_prayer_adhkar_8",
                       repetitions: 1, onlyAfter: .fajr),
    ]
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|✘"
```

Expected: `TEST SUCCEEDED`, all six new tests passing.

- [ ] **Step 5: Commit**

```bash
git add Adhkar/Models/PostPrayerSequence.swift AdhkarTests/PostPrayerSequenceTests.swift Adhkar.xcodeproj/project.pbxproj
git commit -m "feat(post-prayer): define the twelve-step guided sequence"
```

---

### Task 2: Session progression logic

**Files:**
- Create: `Adhkar/Models/PostPrayerSession.swift`
- Test: `AdhkarTests/PostPrayerSessionTests.swift`

**Interfaces:**
- Consumes: `PostPrayerStep`, `PostPrayerSequence.steps` from Task 1.
- Produces: `PostPrayerSession` with `init(steps:restoring:)`, `currentStep`, `count`, `index`, `awaitingConfirmation`, `isComplete`, `progress`, `increment()`, `confirmAdvance()`, `skip()`, `snapshot`, and `PostPrayerSession.Snapshot` (`Codable`).

- [ ] **Step 1: Write the failing test**

Create `AdhkarTests/PostPrayerSessionTests.swift`:

```swift
// AdhkarTests/PostPrayerSessionTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("PostPrayerSession")
struct PostPrayerSessionTests {

    /// Two steps, one auto-advancing and one not — enough to exercise every path.
    private func makeSession() -> PostPrayerSession {
        PostPrayerSession(steps: [
            PostPrayerStep(id: "auto", itemId: "x", arabic: "أ",
                           repetitions: 3, advancesAutomatically: true),
            PostPrayerStep(id: "manual", itemId: "y", arabic: "ب", repetitions: 2),
        ])
    }

    @Test func startsOnTheFirstStepAtZero() {
        let session = makeSession()
        #expect(session.index == 0)
        #expect(session.count == 0)
        #expect(session.currentStep?.id == "auto")
        #expect(!session.isComplete)
        #expect(!session.awaitingConfirmation)
    }

    @Test func incrementCountsUpWithoutAdvancingEarly() {
        var session = makeSession()
        session.increment()
        session.increment()
        #expect(session.count == 2)
        #expect(session.index == 0)
    }

    @Test func anAutoAdvancingStepMovesOnAtItsTarget() {
        var session = makeSession()
        for _ in 0..<3 { session.increment() }
        #expect(session.index == 1)
        #expect(session.count == 0)
        #expect(!session.awaitingConfirmation)
    }

    @Test func aManualStepWaitsForConfirmation() {
        var session = makeSession()
        for _ in 0..<3 { session.increment() }   // clears the auto step
        session.increment()
        session.increment()                       // manual step now at target
        #expect(session.awaitingConfirmation)
        #expect(session.index == 1)

        session.confirmAdvance()
        #expect(session.isComplete)
    }

    // Regression: taps past the target used to bleed into the next step.
    @Test func tapsPastTheTargetAreIgnored() {
        var session = makeSession()
        for _ in 0..<3 { session.increment() }
        for _ in 0..<5 { session.increment() }
        #expect(session.index == 1)
        #expect(session.count == 5)   // counted on the manual step, not lost
        #expect(session.awaitingConfirmation)

        session.increment()           // already waiting -> ignored
        #expect(session.count == 5)
    }

    @Test func skipMovesPastAStepWithoutCompletingIt() {
        var session = makeSession()
        session.increment()
        session.skip()
        #expect(session.index == 1)
        #expect(session.count == 0)
        #expect(session.currentStep?.id == "manual")
    }

    @Test func skippingTheLastStepCompletesTheSession() {
        var session = makeSession()
        session.skip()
        session.skip()
        #expect(session.isComplete)
        #expect(session.currentStep == nil)
    }

    @Test func progressRunsFromZeroToOne() {
        var session = makeSession()
        #expect(session.progress == 0)
        session.skip()
        #expect(abs(session.progress - 0.5) < 0.0001)
        session.skip()
        #expect(session.progress == 1)
    }

    @Test func aCompletedSessionIgnoresFurtherInput() {
        var session = makeSession()
        session.skip()
        session.skip()
        session.increment()
        session.confirmAdvance()
        #expect(session.isComplete)
        #expect(session.index == 2)
    }

    @Test func theSnapshotRoundTripsFaithfully() throws {
        var session = makeSession()
        for _ in 0..<3 { session.increment() }
        session.increment()

        let data = try JSONEncoder().encode(session.snapshot)
        let decoded = try JSONDecoder().decode(PostPrayerSession.Snapshot.self, from: data)
        let restored = PostPrayerSession(steps: session.steps, restoring: decoded)

        #expect(restored.index == session.index)
        #expect(restored.count == session.count)
        #expect(restored.awaitingConfirmation == session.awaitingConfirmation)
    }

    // A snapshot written by an older build with a different step list must not
    // resume into the wrong dhikr.
    @Test func aSnapshotFromADifferentStepCountIsDiscarded() {
        let stale = PostPrayerSession.Snapshot(stepCount: 99, index: 40, count: 7,
                                               awaitingConfirmation: true)
        let session = PostPrayerSession(steps: makeSession().steps, restoring: stale)
        #expect(session.index == 0)
        #expect(session.count == 0)
    }

    @Test func theRealSequenceRunsToCompletion() {
        var session = PostPrayerSession(steps: PostPrayerSequence.steps)
        var guardCounter = 0
        while !session.isComplete, guardCounter < 500 {
            guardCounter += 1
            if session.awaitingConfirmation { session.confirmAdvance() } else { session.increment() }
        }
        #expect(session.isComplete)
        #expect(guardCounter < 500, "the session never terminated")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
ruby scripts/sync_test_sources.rb
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|✘"
```

Expected: `cannot find 'PostPrayerSession' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Adhkar/Models/PostPrayerSession.swift`:

```swift
//
//  PostPrayerSession.swift
//  Adhkar
//

import Foundation

/// Progression through a guided sequence. A value type with no SwiftUI and no
/// persistence: the view owns it in `@State` and mirrors `snapshot` to
/// `@SceneStorage`.
///
/// Deliberately **not** backed by `DhikrProgress`: that model is keyed per
/// item and resets on day change, which is right for morning and evening
/// adhkar but wrong here — this sequence is recited after every prayer, so
/// each session must start from zero.
struct PostPrayerSession: Equatable {
    let steps: [PostPrayerStep]
    private(set) var index: Int
    private(set) var count: Int
    private(set) var awaitingConfirmation: Bool

    struct Snapshot: Codable, Equatable {
        var stepCount: Int
        var index: Int
        var count: Int
        var awaitingConfirmation: Bool
    }

    init(steps: [PostPrayerStep], restoring snapshot: Snapshot? = nil) {
        self.steps = steps
        // A snapshot from a build with a different sequence would resume into
        // the wrong dhikr — start over instead.
        if let snapshot,
           snapshot.stepCount == steps.count,
           snapshot.index >= 0, snapshot.index <= steps.count,
           snapshot.count >= 0 {
            self.index = snapshot.index
            self.count = snapshot.count
            self.awaitingConfirmation = snapshot.awaitingConfirmation
        } else {
            self.index = 0
            self.count = 0
            self.awaitingConfirmation = false
        }
    }

    var currentStep: PostPrayerStep? { index < steps.count ? steps[index] : nil }
    var isComplete: Bool { index >= steps.count }
    var progress: Double {
        steps.isEmpty ? 1 : min(Double(index) / Double(steps.count), 1)
    }
    var snapshot: Snapshot {
        Snapshot(stepCount: steps.count, index: index, count: count,
                 awaitingConfirmation: awaitingConfirmation)
    }

    /// One tap. Ignored once the step is waiting for confirmation or the
    /// session is over, so extra taps never bleed into the next dhikr.
    mutating func increment() {
        guard !isComplete, !awaitingConfirmation, let step = currentStep else { return }
        count += 1
        guard count >= step.repetitions else { return }
        if step.advancesAutomatically { advance() } else { awaitingConfirmation = true }
    }

    mutating func confirmAdvance() {
        guard awaitingConfirmation else { return }
        advance()
    }

    /// Move on without finishing — used by the conditional steps.
    mutating func skip() {
        guard !isComplete else { return }
        advance()
    }

    private mutating func advance() {
        index += 1
        count = 0
        awaitingConfirmation = false
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)|✘"
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Adhkar/Models/PostPrayerSession.swift AdhkarTests/PostPrayerSessionTests.swift Adhkar.xcodeproj/project.pbxproj
git commit -m "feat(post-prayer): session progression logic"
```

---

### Task 3: Localised strings

**Files:**
- Modify: `Adhkar/Localization/L10n.swift` (append before the closing brace)

**Interfaces:**
- Produces: `L10n.postPrayerTitle`, `.postPrayerCardLabel`, `.postPrayerCardHint`, `.postPrayerNext`, `.postPrayerSkip`, `.postPrayerStepOf`, `.postPrayerDone`, `.postPrayerRestart`, `.postPrayerClose`.

- [ ] **Step 1: Add the strings**

Append inside the `enum L10n` body, after the review-summary block:

```swift
    // MARK: - Post-prayer sequence
    static let postPrayerTitle      = LocalizedText(ar: "أذكار بعد الصلاة", fr: "Après la prière", en: "After the prayer")
    static let postPrayerCardLabel  = LocalizedText(ar: "أذكار بعد الصلاة", fr: "Après la prière", en: "After the prayer")
    static let postPrayerCardHint   = LocalizedText(ar: "اتبع الأذكار خطوة بخطوة", fr: "Suis les adhkar pas à pas", en: "Follow the adhkar step by step")
    static let postPrayerNext       = LocalizedText(ar: "التالي", fr: "Étape suivante", en: "Next step")
    static let postPrayerSkip       = LocalizedText(ar: "تخطّي", fr: "Passer", en: "Skip")
    static let postPrayerStepOf     = LocalizedText(ar: "من", fr: "sur", en: "of")
    static let postPrayerDone       = LocalizedText(ar: "تمت الأذكار", fr: "Adhkar terminés", en: "Adhkar complete")
    static let postPrayerRestart    = LocalizedText(ar: "إعادة", fr: "Recommencer", en: "Start again")
    static let postPrayerClose      = LocalizedText(ar: "إغلاق", fr: "Fermer", en: "Close")
```

- [ ] **Step 2: Verify it builds**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Adhkar/Localization/L10n.swift
git commit -m "feat(l10n): strings for the post-prayer sequence (AR/FR/EN)"
```

---

### Task 4: The guided screen

**Files:**
- Create: `Adhkar/Views/PostPrayerSessionView.swift`
- Test: manual — build plus a simulator screenshot; SwiftUI views are not unit-tested in this project, the logic they drive is (Tasks 1–2).

**Interfaces:**
- Consumes: `PostPrayerSession`, `PostPrayerSequence`, `L10n.postPrayer*` / `L10n.listen` / `L10n.pause`, `StreakService` and `AudioPlayer` from `@Environment`, `Font.amiri(size:)` from `Adhkar/Design/Font+Arabic.swift`.
- Produces: `PostPrayerSessionView()` — takes no arguments, dismisses itself via `@Environment(\.dismiss)`.

- [ ] **Step 1: Write the view**

Create `Adhkar/Views/PostPrayerSessionView.swift`:

```swift
//
//  PostPrayerSessionView.swift
//  Adhkar
//

import SwiftUI
import SwiftData

/// Guided walk through the post-prayer adhkar. One step at a time, a large
/// tap target, and the full list underneath so the ritual reads as a whole.
struct PostPrayerSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakService.self) private var streak
    @Environment(AudioPlayer.self) private var audio

    @State private var session = PostPrayerSession(steps: PostPrayerSequence.steps)
    @SceneStorage("postPrayer.snapshot") private var storedSnapshot: Data?
    @State private var completionRecorded = false

    private let accent = Color.orange

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(decorated: true)
                ScrollView {
                    VStack(spacing: 24) {
                        progressBar
                        if let step = session.currentStep {
                            stepCard(step)
                            counterButton(step)
                            controls(step)
                        } else {
                            completionCard
                        }
                        stepList
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(L10n.postPrayerTitle.resolved())
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.postPrayerClose.resolved()) { dismiss() }
                }
            }
        }
        .sensoryFeedback(.impact, trigger: session.count)
        .sensoryFeedback(.success, trigger: session.index)
        .onAppear(perform: restore)
        .onDisappear { audio.stop() }
        .onChange(of: session.index) { _, _ in audio.stop() }
        .onChange(of: session.snapshot) { _, _ in persist() }
        .onChange(of: session.isComplete) { _, complete in
            guard complete, !completionRecorded else { return }
            completionRecorded = true
            streak.recordDhikrCompleted(context: modelContext)
            storedSnapshot = nil
        }
    }

    // MARK: - Pieces

    private var progressBar: some View {
        VStack(spacing: 6) {
            ProgressView(value: session.progress)
                .tint(accent)
            Text("\(min(session.index + 1, session.steps.count)) \(L10n.postPrayerStepOf.resolved()) \(session.steps.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func stepCard(_ step: PostPrayerStep) -> some View {
        VStack(spacing: 12) {
            if let scope = step.onlyAfter {
                Text(scope.label.resolved())
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text(step.displayArabic)
                .font(.amiri(size: 26))
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
            if let translit = step.displayTransliteration {
                Text(translit)
                    .font(.subheadline.italic())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let translation = step.displayTranslation {
                Text(translation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let item = step.sourceItem {
                if !item.source.isEmpty {
                    Text(item.source)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                if let audioURL = item.audio.flatMap(URL.init(string:)) {
                    Button {
                        audio.toggle(itemId: item.id, url: audioURL)
                    } label: {
                        Label(audio.isPlaying(itemId: item.id) ? L10n.pause.resolved()
                                                               : L10n.listen.resolved(),
                              systemImage: audio.isPlaying(itemId: item.id) ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func counterButton(_ step: PostPrayerStep) -> some View {
        Button {
            session.increment()
        } label: {
            ZStack {
                Circle().fill(accent.opacity(0.12))
                Circle().stroke(accent.opacity(0.20), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(Double(session.count) / Double(max(step.repetitions, 1)), 1))
                    .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.2), value: session.count)
                VStack(spacing: 2) {
                    Text("\(session.count)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                    Text("/ \(step.repetitions)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)
        }
        .buttonStyle(.plain)
        .disabled(session.awaitingConfirmation)
        .accessibilityLabel(L10n.postPrayerTitle.resolved())
        .accessibilityValue("\(session.count) / \(step.repetitions)")
    }

    @ViewBuilder
    private func controls(_ step: PostPrayerStep) -> some View {
        HStack(spacing: 12) {
            if step.onlyAfter != nil, !session.awaitingConfirmation {
                Button(L10n.postPrayerSkip.resolved()) { session.skip() }
                    .buttonStyle(.bordered)
            }
            if session.awaitingConfirmation {
                Button(L10n.postPrayerNext.resolved()) { session.confirmAdvance() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .tint(accent)
    }

    private var completionCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(accent)
            Text(L10n.postPrayerDone.resolved())
                .font(.title3.weight(.bold))
            Button(L10n.postPrayerRestart.resolved()) {
                session = PostPrayerSession(steps: PostPrayerSequence.steps)
                completionRecorded = false
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(session.steps.enumerated()), id: \.element.id) { offset, step in
                HStack(spacing: 10) {
                    Image(systemName: offset < session.index ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(offset < session.index ? accent : .secondary)
                    Text(step.displayArabic)
                        .font(.amiri(size: 15))
                        .lineLimit(1)
                        .foregroundStyle(offset == session.index ? .primary : .secondary)
                    Spacer()
                    if step.repetitions > 1 {
                        Text("×\(step.repetitions)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color("CardBackground").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Snapshot

    private func restore() {
        guard let storedSnapshot,
              let snapshot = try? JSONDecoder().decode(PostPrayerSession.Snapshot.self, from: storedSnapshot)
        else { return }
        session = PostPrayerSession(steps: PostPrayerSequence.steps, restoring: snapshot)
    }

    private func persist() {
        storedSnapshot = try? JSONEncoder().encode(session.snapshot)
    }
}
```

- [ ] **Step 2: Verify it builds on iOS and macOS**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED` for both. A macOS failure here almost always means a `UIKit`-only modifier slipped in — wrap it in `#if os(iOS) || os(visionOS)`.

- [ ] **Step 3: Run the whole suite**

```bash
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)"
```

Expected: `TEST SUCCEEDED` — the view must not have broken Tasks 1–2.

- [ ] **Step 4: Commit**

```bash
git add Adhkar/Views/PostPrayerSessionView.swift
git commit -m "feat(post-prayer): guided session screen"
```

---

### Task 5: Home entry point

**Files:**
- Create: `Adhkar/Views/PostPrayerCard.swift`
- Modify: `Adhkar/Views/HomeView.swift` (add state, card, and `fullScreenCover`)

**Interfaces:**
- Consumes: `PostPrayerSessionView` from Task 4, `L10n.postPrayerCardLabel` / `.postPrayerCardHint` from Task 3.
- Produces: `PostPrayerCard(action:)`; `HomeView` gains `@State private var isPostPrayerPresented`.

- [ ] **Step 1: Write the card**

Create `Adhkar/Views/PostPrayerCard.swift`, mirroring `HomeContextCard`:

```swift
//
//  PostPrayerCard.swift
//  Adhkar
//

import SwiftUI

/// Home entry point into the guided post-prayer sequence. Built on the same
/// shape as `HomeContextCard`; the action is injected so `HomeView` owns the
/// presentation state.
struct PostPrayerCard: View {
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
                    Image(systemName: "hands.and.sparkles.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.postPrayerCardLabel.resolved())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(L10n.postPrayerCardHint.resolved())
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
            .padding()
            .background(Color("CardBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Wire it into HomeView**

In `Adhkar/Views/HomeView.swift`, add the state next to `isContextPickerPresented`:

```swift
    @State private var isPostPrayerPresented = false
```

Insert the card into the `VStack`, immediately after `HomeContextCard`:

```swift
                        HomeContextCard { isContextPickerPresented = true }
                        PostPrayerCard { isPostPrayerPresented = true }
                        StreakCard()
```

Add the cover right after the existing `.sheet(isPresented: $isContextPickerPresented)` modifier:

```swift
            .fullScreenCover(isPresented: $isPostPrayerPresented) {
                PostPrayerSessionView()
            }
```

- [ ] **Step 3: Build and check it on the simulator**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Then install, launch, and confirm by eye: the card sits under the contextual card on Home, tapping it opens the sequence full-screen, the counter advances, the three tasbihāt chain without a confirmation tap, and Āyat al-Kursī waits for one.

- [ ] **Step 4: Run the whole suite**

```bash
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)"
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Adhkar/Views/PostPrayerCard.swift Adhkar/Views/HomeView.swift
git commit -m "feat(post-prayer): home card opening the guided sequence"
```

---

### Task 6: `munajat://tasbih` deep link

**Files:**
- Modify: `Adhkar/App/AdhkarApp.swift` (state + `onOpenURL`)
- Modify: `Adhkar/App/RootTabView.swift` (binding through to Home)
- Modify: `Adhkar/Views/HomeView.swift` (accept the binding)

**Interfaces:**
- Consumes: `isPostPrayerPresented` from Task 5.
- Produces: `AdhkarApp.pendingPostPrayerDeepLink: Bool` bound down to `HomeView.isPostPrayerPresented`. No widget change — this only opens the door for one.

- [ ] **Step 1: Add the state and parse the URL**

In `Adhkar/App/AdhkarApp.swift`, next to `pendingDeepLinkCategoryId`:

```swift
    /// Set by a `munajat://tasbih` URL; `RootTabView` routes it to Home,
    /// which presents the guided sequence.
    @State private var pendingPostPrayerDeepLink = false
```

Pass it down:

```swift
            RootTabView(initialTab: initialTab,
                        pendingDeepLinkCategoryId: $pendingDeepLinkCategoryId,
                        pendingPostPrayerDeepLink: $pendingPostPrayerDeepLink)
```

Replace the body of `.onOpenURL` so it handles both hosts:

```swift
                .onOpenURL { url in
                    guard url.scheme == "munajat" else { return }
                    switch url.host {
                    case "category":
                        let id = url.pathComponents.dropFirst().joined(separator: "/")
                        guard !id.isEmpty else { return }
                        pendingDeepLinkCategoryId = id
                    case "tasbih":
                        pendingPostPrayerDeepLink = true
                    default:
                        return
                    }
                }
```

- [ ] **Step 2: Thread the binding through RootTabView**

In `Adhkar/App/RootTabView.swift`, add the property beside the existing `pendingDeepLinkCategoryId` binding:

```swift
    @Binding var pendingPostPrayerDeepLink: Bool
```

Route it to Home — when it flips true, select the home tab and hand the flag to `HomeView`:

```swift
        .onChange(of: pendingPostPrayerDeepLink) { _, pending in
            guard pending else { return }
            selection = .home
        }
```

Pass the binding into `HomeView` where it is constructed, alongside `path`:

```swift
            HomeView(path: $homePath, presentPostPrayer: $pendingPostPrayerDeepLink)
```

- [ ] **Step 3: Accept the binding in HomeView**

In `Adhkar/Views/HomeView.swift`, replace the local state added in Task 5 with a binding driven from outside, keeping a default so previews still compile:

```swift
    /// Driven by `munajat://tasbih`; also flipped locally by the home card.
    @Binding var presentPostPrayer: Bool
```

Update the card action and the cover to use it:

```swift
                        PostPrayerCard { presentPostPrayer = true }
```

```swift
            .fullScreenCover(isPresented: $presentPostPrayer) {
                PostPrayerSessionView()
            }
```

- [ ] **Step 4: Build and verify the link**

```bash
xcodebuild build -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

With the app installed and running on the booted simulator:

```bash
xcrun simctl openurl booted "munajat://tasbih"
```

Expected: the app comes to the front on the Home tab with the guided sequence presented. Then re-check the existing link still works:

```bash
xcrun simctl openurl booted "munajat://category/morning_adhkar"
```

Expected: the morning adhkar category is pushed, as before.

- [ ] **Step 5: Run the whole suite**

```bash
xcodebuild test -project Adhkar.xcodeproj -scheme Adhkar \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)"
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add Adhkar/App/AdhkarApp.swift Adhkar/App/RootTabView.swift Adhkar/Views/HomeView.swift
git commit -m "feat(post-prayer): munajat://tasbih deep link"
```

---

## Out of scope for this plan

Called out so nobody adds them mid-flight — each is a separate decision:

- A free-form tasbih counter. Excluded on purpose: see §3 of the spec and the 4.3(a) history.
- Prayer times, geolocation, a prayer selector.
- Session history or statistics (`TasbihSession` SwiftData model).
- French translations of the Quranic steps — those need a sourced translation.
- Widget changes. The deep link is registered; pointing a widget at it is a later version.
- The `1.0.0 → 1.1.0` version bump and the App Store submission.
