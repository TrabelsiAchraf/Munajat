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
        #expect(session.count == 2)   // stops at the manual step's target
        #expect(session.awaitingConfirmation)

        session.increment()           // already waiting -> ignored
        #expect(session.count == 2)
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
