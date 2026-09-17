import Foundation
import Testing
@testable import Adhkar

@Suite("Contact rate limiter")
struct ContactRateLimiterTests {
    @Test func allowsThreeReservationsThenBlocks() {
        let suite = "test.contact.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(ContactRateLimiter.remaining(now: now, defaults: defaults) == 3)
        #expect(ContactRateLimiter.reserveSend(now: now, defaults: defaults))
        #expect(ContactRateLimiter.reserveSend(now: now, defaults: defaults))
        #expect(ContactRateLimiter.reserveSend(now: now, defaults: defaults))
        #expect(!ContactRateLimiter.reserveSend(now: now, defaults: defaults))
        #expect(ContactRateLimiter.remaining(now: now, defaults: defaults) == 0)
    }

    @Test func resetsOnTheNextCalendarDay() {
        let suite = "test.contact.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        for _ in 0..<3 { #expect(ContactRateLimiter.reserveSend(now: day, defaults: defaults)) }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        #expect(ContactRateLimiter.reserveSend(now: tomorrow, defaults: defaults))
    }
}
