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

    // Every step chains, not just some: a button that appeared on a few steps
    // and not others read as a bug.
    @Test func everyFinishedStepChainsIntoTheNext() {
        var session = makeSession()
        for _ in 0..<3 { session.increment() }
        #expect(session.index == 1)
        #expect(session.count == 0)
        #expect(session.currentStep?.id == "second")
    }

    @Test func finishingTheLastStepCompletesTheSession() {
        var session = makeSession()
        for _ in 0..<3 { session.increment() }
        session.increment()
        #expect(!session.isComplete)
        session.increment()
        #expect(session.isComplete)
        #expect(session.currentStep == nil)
    }

    @Test func aCompletedSessionIgnoresFurtherInput() {
        var session = makeSession()
        for _ in 0..<5 { session.increment() }
        #expect(session.isComplete)
        session.increment()
        #expect(session.index == 2)
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

    @Test func theRealSequenceRunsToCompletionOnTapsAlone() {
        var session = PostPrayerSession(steps: PostPrayerSequence.steps)
        var guardCounter = 0
        while !session.isComplete, guardCounter < 500 {
            guardCounter += 1
            session.increment()
        }
        #expect(session.isComplete)
        // 12 steps whose repetitions sum to 121, and nothing needs a second
        // kind of input to advance.
        #expect(guardCounter == PostPrayerSequence.steps.reduce(0) { $0 + $1.repetitions })
    }
}
