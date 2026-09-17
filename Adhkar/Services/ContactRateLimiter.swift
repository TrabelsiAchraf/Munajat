import Foundation

/// Keeps the same local, daily three-send limit as Salt Scan. The counter is
/// incremented when the composer opens, matching its existing user-facing
/// behaviour and preventing repeated compose/cancel loops.
struct ContactRateLimiter {
    static let maxSendsPerDay = 3
    private static let countKey = "contact.sentMailsToday"
    private static let dateKey = "contact.lastSentDate"

    static func canSend(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        resetIfNeeded(now: now, defaults: defaults)
        return defaults.integer(forKey: countKey) < maxSendsPerDay
    }

    @discardableResult
    static func reserveSend(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        guard canSend(now: now, defaults: defaults) else { return false }
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
        defaults.set(now, forKey: dateKey)
        return true
    }

    static func remaining(now: Date = .now, defaults: UserDefaults = .standard) -> Int {
        resetIfNeeded(now: now, defaults: defaults)
        return max(0, maxSendsPerDay - defaults.integer(forKey: countKey))
    }

    private static func resetIfNeeded(now: Date, defaults: UserDefaults) {
        let last = defaults.object(forKey: dateKey) as? Date ?? .distantPast
        if !Calendar.current.isDate(last, inSameDayAs: now) {
            defaults.set(0, forKey: countKey)
        }
    }
}
