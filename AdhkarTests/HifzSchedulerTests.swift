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
