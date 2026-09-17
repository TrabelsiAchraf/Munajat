// Adhkar/Services/ReviewPromptGate.swift
import Foundation

/// Local eligibility only: StoreKit decides whether a request displays a prompt.
/// Count completed activities across the app, on at least two different days.
/// Keep the 1.2 keys so updating never resets a previous request's cooldown.
struct ReviewPromptGate {
    static let celebrationCountKey = "review.celebrationCount"
    static let lastRequestKey = "review.lastRequestDate"
    static let minimumCelebrations = 2
    static let minimumDaysBetweenRequests = 60.0
    static let activityDaysKey = "review.activityDays"
    static let activitiesTodayKey = "review.activitiesToday"
    static let activityDayKey = "review.activityDay"
    static let lastVersionKey = "review.lastRequestVersion"

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    static func shouldRequest(celebrationCount: Int, lastRequest: Date?, now: Date = .now) -> Bool {
        guard celebrationCount >= minimumCelebrations else { return false }
        guard let lastRequest else { return true }
        return now.timeIntervalSince(lastRequest) >= minimumDaysBetweenRequests * 86_400
    }

    /// Deduplicate each activity per day (including reset/re-complete). Store
    /// only two day keys and today's IDs; nothing leaves the device.
    static func recordCompletion(activityID: String, in defaults: UserDefaults = .standard, now: Date = .now) {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let day = "\(components.year!)-\(components.month!)-\(components.day!)"
        if defaults.string(forKey: activityDayKey) != day {
            defaults.set(day, forKey: activityDayKey)
            defaults.set([String](), forKey: activitiesTodayKey)
        }
        var activities = defaults.stringArray(forKey: activitiesTodayKey) ?? []
        guard !activities.contains(activityID) else { return }
        activities.append(activityID)
        defaults.set(activities, forKey: activitiesTodayKey)
        var days = defaults.stringArray(forKey: activityDaysKey) ?? []
        if !days.contains(day) {
            days.append(day)
            defaults.set(Array(days.suffix(2)), forKey: activityDaysKey)
        }
        defaults.set(defaults.integer(forKey: celebrationCountKey) + 1, forKey: celebrationCountKey)
    }

    static func recordRequest(in defaults: UserDefaults = .standard, now: Date = .now, version: String = appVersion) {
        defaults.set(now.timeIntervalSince1970, forKey: lastRequestKey)
        defaults.set(version, forKey: lastVersionKey)
    }

    static func shouldRequestNow(in defaults: UserDefaults = .standard, now: Date = .now, version: String = appVersion) -> Bool {
        guard (defaults.stringArray(forKey: activityDaysKey) ?? []).count >= 2,
              defaults.string(forKey: lastVersionKey) != version else { return false }
        let ts = defaults.double(forKey: lastRequestKey)
        return shouldRequest(
            celebrationCount: defaults.integer(forKey: celebrationCountKey),
            lastRequest: ts > 0 ? Date(timeIntervalSince1970: ts) : nil,
            now: now
        )
    }
}
