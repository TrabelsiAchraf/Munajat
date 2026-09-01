// AdhkarTests/ReviewPromptGateTests.swift
import Testing
import Foundation
@testable import Adhkar

@Suite("ReviewPromptGate")
struct ReviewPromptGateTests {
    @Test func neverBeforeSecondCelebration() {
        #expect(!ReviewPromptGate.shouldRequest(celebrationCount: 0, lastRequest: nil))
        #expect(!ReviewPromptGate.shouldRequest(celebrationCount: 1, lastRequest: nil))
    }

    @Test func firesFromSecondCelebrationWhenNeverAsked() {
        #expect(ReviewPromptGate.shouldRequest(celebrationCount: 2, lastRequest: nil))
        #expect(ReviewPromptGate.shouldRequest(celebrationCount: 40, lastRequest: nil))
    }

    @Test func respectsSixtyDayCooldown() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let fiftyNineDaysAgo = now.addingTimeInterval(-59 * 86_400)
        let sixtyOneDaysAgo = now.addingTimeInterval(-61 * 86_400)
        #expect(!ReviewPromptGate.shouldRequest(celebrationCount: 5, lastRequest: fiftyNineDaysAgo, now: now))
        #expect(ReviewPromptGate.shouldRequest(celebrationCount: 5, lastRequest: sixtyOneDaysAgo, now: now))
    }

    @Test func userDefaultsRoundTrip() {
        let suite = "test.reviewPromptGate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(!ReviewPromptGate.shouldRequestNow(in: defaults))
        ReviewPromptGate.recordCelebration(in: defaults)
        #expect(!ReviewPromptGate.shouldRequestNow(in: defaults))
        ReviewPromptGate.recordCelebration(in: defaults)
        #expect(ReviewPromptGate.shouldRequestNow(in: defaults))
        ReviewPromptGate.recordRequest(in: defaults)
        #expect(!ReviewPromptGate.shouldRequestNow(in: defaults))
    }
}
