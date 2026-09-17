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
        ReviewPromptGate.recordCompletion(activityID: "postPrayer", in: defaults, now: .now.addingTimeInterval(-86_400))
        #expect(!ReviewPromptGate.shouldRequestNow(in: defaults))
        ReviewPromptGate.recordCompletion(activityID: "memorization", in: defaults)
        #expect(ReviewPromptGate.shouldRequestNow(in: defaults))
        ReviewPromptGate.recordRequest(in: defaults)
        #expect(!ReviewPromptGate.shouldRequestNow(in: defaults))
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "test.reviewPromptGate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    @Test func repeatedActivitiesAndResetsCannotQualifyOnFirstDay() {
        withDefaults { defaults in
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            for _ in 0..<10 {
                ReviewPromptGate.recordCompletion(activityID: "item.sleep_1", in: defaults, now: now)
            }
            #expect(defaults.integer(forKey: ReviewPromptGate.celebrationCountKey) == 1)
            ReviewPromptGate.recordCompletion(activityID: "postPrayer", in: defaults, now: now)
            #expect(!ReviewPromptGate.shouldRequestNow(in: defaults, now: now, version: "1.3.0"))
            ReviewPromptGate.recordCompletion(activityID: "item.sleep_1", in: defaults, now: now.addingTimeInterval(86_400))
            #expect(ReviewPromptGate.shouldRequestNow(in: defaults, now: now.addingTimeInterval(86_400), version: "1.3.0"))
        }
    }

    @Test func noRepeatForSameVersionEvenAfterCooldown() {
        withDefaults { defaults in
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            ReviewPromptGate.recordCompletion(activityID: "category.sleep", in: defaults, now: now.addingTimeInterval(-86_400))
            ReviewPromptGate.recordCompletion(activityID: "postPrayer", in: defaults, now: now)
            ReviewPromptGate.recordRequest(in: defaults, now: now, version: "1.3.0")
            let later = now.addingTimeInterval(60 * 86_400)
            #expect(!ReviewPromptGate.shouldRequestNow(in: defaults, now: later, version: "1.3.0"))
            #expect(ReviewPromptGate.shouldRequestNow(in: defaults, now: later, version: "1.3.1"))
            #expect(!ReviewPromptGate.shouldRequestNow(in: defaults, now: later.addingTimeInterval(-1), version: "1.3.1"))
        }
    }

    @Test func version120RequestSurvivesUpgrade() {
        withDefaults { defaults in
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            defaults.set(12, forKey: "review.celebrationCount")
            defaults.set(now.timeIntervalSince1970, forKey: "review.lastRequestDate")
            ReviewPromptGate.recordCompletion(activityID: "postPrayer", in: defaults, now: now)
            ReviewPromptGate.recordCompletion(activityID: "memorization", in: defaults, now: now.addingTimeInterval(86_400))
            #expect(defaults.integer(forKey: ReviewPromptGate.celebrationCountKey) == 14)
            #expect(!ReviewPromptGate.shouldRequestNow(in: defaults, now: now.addingTimeInterval(86_400), version: "1.3.0"))
            #expect(ReviewPromptGate.shouldRequestNow(in: defaults, now: now.addingTimeInterval(60 * 86_400), version: "1.3.0"))
        }
    }

    @Test func retainedActivityHistoryIsBounded() {
        withDefaults { defaults in
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            for day in 0..<90 {
                ReviewPromptGate.recordCompletion(activityID: "item.\(day)", in: defaults,
                                                  now: now.addingTimeInterval(Double(day) * 86_400))
            }
            #expect(defaults.stringArray(forKey: ReviewPromptGate.activityDaysKey)?.count == 2)
            #expect(defaults.stringArray(forKey: ReviewPromptGate.activitiesTodayKey) == ["item.89"])
        }
    }
}
