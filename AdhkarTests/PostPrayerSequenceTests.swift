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
