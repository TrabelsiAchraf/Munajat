// Adhkar/Services/ReviewPromptGate.swift
import Foundation

/// Decides when to ask for an App Store rating: from the second category
/// completion celebration onwards, at most once every 60 days. Apple's own
/// 3-prompts-per-year cap still applies on top of this gate.
struct ReviewPromptGate {
    static let celebrationCountKey = "review.celebrationCount"
    static let lastRequestKey = "review.lastRequestDate"
    static let minimumCelebrations = 2
    static let minimumDaysBetweenRequests = 60.0

    static func shouldRequest(celebrationCount: Int, lastRequest: Date?, now: Date = .now) -> Bool {
        guard celebrationCount >= minimumCelebrations else { return false }
        guard let lastRequest else { return true }
        return now.timeIntervalSince(lastRequest) >= minimumDaysBetweenRequests * 86_400
    }

    static func recordCelebration(in defaults: UserDefaults = .standard) {
        defaults.set(defaults.integer(forKey: celebrationCountKey) + 1, forKey: celebrationCountKey)
    }

    static func recordRequest(in defaults: UserDefaults = .standard, now: Date = .now) {
        defaults.set(now.timeIntervalSince1970, forKey: lastRequestKey)
    }

    static func shouldRequestNow(in defaults: UserDefaults = .standard, now: Date = .now) -> Bool {
        let ts = defaults.double(forKey: lastRequestKey)
        return shouldRequest(
            celebrationCount: defaults.integer(forKey: celebrationCountKey),
            lastRequest: ts > 0 ? Date(timeIntervalSince1970: ts) : nil,
            now: now
        )
    }
}
