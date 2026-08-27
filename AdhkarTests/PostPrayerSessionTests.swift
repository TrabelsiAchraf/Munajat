// AdhkarTests/PostPrayerSessionTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("PostPrayerSession")
struct PostPrayerSessionTests {

    /// Two steps with different targets — a finished step always chains into
    /// the next, so there is no confirmation path left to exercise.
    private func makeSession() -> PostPrayerSession {
        PostPrayerSession(steps: [
            PostPrayerStep(id: "first", itemId: "x", arabic: "أ", repetitions: 3),
            PostPrayerStep(id: "second", itemId: "y", arabic: "ب", repetitions: 2),
        ])
    }

    @Test func startsOnTheFirstStepAtZero() {
        let session = makeSession()
        #expect(session.index == 0)
        #expect(session.count == 0)
        #expect(session.currentStep?.id == "first")
        #expect(!session.isComplete)
    }

    @Test func incrementCountsUpWithoutAdvancingEarly() {
        var session = makeSession()
        session.increment()
        session.increment()
        #expect(session.count == 2)
        #expect(session.index == 0)
        #expect(session.currentStep?.id == "first")
    }

    // increment() only counts. Advancing is a separate call so the view can
    // hold the filled ring on screen before moving on — on a single-repetition
    // step the two happened in the same gesture and the ring never drew.
    @Test func reachingTheTargetFinishesTheStepWithoutAdvancing() {
        var session = makeSession()
        for _ in 0..<3 { session.increment() }
        #expect(session.isStepFinished)
        #expect(session.index == 0)
        #expect(session.count == 3)
    }

    @Test func advanceMovesToTheNextStepAndResetsTheCount() {
        var session = makeSession()
        for _ in 0..<3 { session.increment() }
        session.advance()
        #expect(session.index == 1)
        #expect(session.count == 0)
        #expect(!session.isStepFinished)
        #expect(session.currentStep?.id == "second")
    }

    // A single-repetition step must still report a finished step, so the view
    // has something to react to.
    @Test func aSingleRepetitionStepFinishesOnOneTap() {
        var session = PostPrayerSession(steps: [
            PostPrayerStep(id: "once", itemId: "x", arabic: "أ", repetitions: 1),
        ])
        session.increment()
        #expect(session.isStepFinished)
        #expect(session.count == 1)
        #expect(!session.isComplete)
        session.advance()
        #expect(session.isComplete)
    }

    @Test func tapsPastTheTargetAreIgnored() {
        var session = makeSession()
        for _ in 0..<10 { session.increment() }
        #expect(session.count == 3)
        #expect(session.index == 0)
    }

    @Test func advancingPastTheLastStepCompletesTheSession() {
        var session = makeSession()
        for _ in 0..<3 { session.increment() }
        session.advance()
        session.increment()
        session.increment()
        #expect(session.isStepFinished)
        #expect(!session.isComplete)
        session.advance()
        #expect(session.isComplete)
        #expect(session.currentStep == nil)
    }

    @Test func aCompletedSessionIgnoresFurtherInput() {
        var session = makeSession()
        session.advance()
        session.advance()
        #expect(session.isComplete)
        session.increment()
        session.advance()
        #expect(session.index == 2)
        #expect(session.count == 0)
    }

    @Test func skipMovesPastAStepWithoutCompletingIt() {
        var session = makeSession()
        session.increment()
        session.skip()
        #expect(session.index == 1)
        #expect(session.count == 0)
        #expect(session.currentStep?.id == "second")
    }

    @Test func skippingEveryStepCompletesTheSession() {
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

    @Test func theSnapshotRoundTripsFaithfully() throws {
        var session = makeSession()
        for _ in 0..<3 { session.increment() }
        session.increment()

        let data = try JSONEncoder().encode(session.snapshot)
        let decoded = try JSONDecoder().decode(PostPrayerSession.Snapshot.self, from: data)
        let restored = PostPrayerSession(steps: session.steps, restoring: decoded)

        #expect(restored.index == session.index)
        #expect(restored.count == session.count)
    }

    // A snapshot written by an older build with a different step list must not
    // resume into the wrong dhikr.
    @Test func aSnapshotFromADifferentStepCountIsDiscarded() {
        let stale = PostPrayerSession.Snapshot(stepCount: 99, index: 40, count: 7)
        let session = PostPrayerSession(steps: makeSession().steps, restoring: stale)
        #expect(session.index == 0)
        #expect(session.count == 0)
    }

    @Test func theRealSequenceRunsToCompletion() {
        var session = PostPrayerSession(steps: PostPrayerSequence.steps)
        var taps = 0
        var guardCounter = 0
        while !session.isComplete, guardCounter < 500 {
            guardCounter += 1
            if session.isStepFinished { session.advance() } else { session.increment(); taps += 1 }
        }
        #expect(session.isComplete)
        // Every step is reached by tapping exactly its repetitions.
        #expect(taps == PostPrayerSequence.steps.reduce(0) { $0 + $1.repetitions })
    }

    @Test func advanceIfFinishedMovesOnlyWhenTheStepIsDone() {
        var session = makeSession()
        #expect(session.advanceIfFinished() == false)
        #expect(session.index == 0)

        session.increment()
        #expect(session.advanceIfFinished() == false)   // 1 of 3
        #expect(session.index == 0)

        session.increment()
        session.increment()
        #expect(session.advanceIfFinished() == true)
        #expect(session.index == 1)
        #expect(session.count == 0)
    }

    @Test func advanceIfFinishedIsSafeOnACompletedSession() {
        var session = makeSession()
        session.advance()
        session.advance()
        #expect(session.isComplete)
        #expect(session.advanceIfFinished() == false)
        #expect(session.index == 2)
    }
}
