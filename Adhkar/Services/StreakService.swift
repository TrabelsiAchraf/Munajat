//
//  StreakService.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 11/05/2026.
//

import Foundation
import Observation
import SwiftData
import WidgetKit

/// Tracks a daily-open streak. The streak increments by one each day the user
/// opens the app at least once; it resets to 1 if a calendar day was skipped.
/// Storage layout:
///   - SwiftData `DailyActivity`: one row per day, durable history.
///   - `UserDefaults` mirror of `currentStreak` / `bestStreak` for the widget
///     to read without spinning up SwiftData in the extension process.
@Observable
@MainActor
final class StreakService {
    private(set) var currentStreak: Int = 0
    private(set) var bestStreak: Int = 0
    private(set) var todayItemsRead: Int = 0

    private let defaults: UserDefaults
    private let bestKey = "streak.best"
    private let currentKey = "streak.current"

    /// `Calendar(identifier: .gregorian)` because device-set Islamic locales
    /// otherwise return Hijri components that don't align with absolute days.
    private static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = gregorian
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// App Group suite shared with `MunajatWidget` so the widget can read
    /// the streak without spinning up SwiftData. Falls back to `.standard`
    /// only if the suite somehow can't be opened (shouldn't happen in
    /// release builds since the entitlement is part of the bundle).
    nonisolated static func makeSharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "group.com.tadevv.Munajat") ?? .standard
    }

    init(defaults: UserDefaults = StreakService.makeSharedDefaults()) {
        self.defaults = defaults
        bestStreak = defaults.integer(forKey: bestKey)
        currentStreak = defaults.integer(forKey: currentKey)
    }

    /// Call once at app start (and on each `scenePhase == .active`) to record
    /// today's open and refresh the in-memory streak.
    func recordOpen(context: ModelContext) {
        let today = Self.dayKey(for: .now)
        ensureActivity(dayKey: today, context: context)
        try? context.save()
        recompute(context: context)
    }

    /// Bumps today's `itemsRead` counter. Called when a user finishes a dhikr
    /// (counter reaches the target). Does NOT change the streak — opening the
    /// app is enough to maintain it; this is just for history/insights.
    func recordDhikrCompleted(context: ModelContext) {
        let today = Self.dayKey(for: .now)
        let activity = ensureActivity(dayKey: today, context: context)
        activity.itemsRead += 1
        try? context.save()
        todayItemsRead = activity.itemsRead
    }

    // MARK: - Private

    @discardableResult
    private func ensureActivity(dayKey: String, context: ModelContext) -> DailyActivity {
        let descriptor = FetchDescriptor<DailyActivity>(
            predicate: #Predicate<DailyActivity> { $0.dayKey == dayKey }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let new = DailyActivity(dayKey: dayKey)
        context.insert(new)
        return new
    }

    private func recompute(context: ModelContext) {
        let descriptor = FetchDescriptor<DailyActivity>(
            sortBy: [SortDescriptor(\.firstOpen, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let daysSet = Set(all.map(\.dayKey))

        var streak = 0
        var cursor = Date.now
        while daysSet.contains(Self.dayKey(for: cursor)) {
            streak += 1
            guard let prev = Self.gregorian.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        currentStreak = streak
        bestStreak = max(bestStreak, streak)
        todayItemsRead = all.first(where: { $0.dayKey == Self.dayKey(for: .now) })?.itemsRead ?? 0

        defaults.set(currentStreak, forKey: currentKey)
        defaults.set(bestStreak, forKey: bestKey)

        // Nudge the widget to re-render with the fresh streak. Cheap: WidgetKit
        // coalesces requests and only re-runs the timeline provider if needed.
        if #available(visionOS 26.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPeriodWidget")
        } else {
            // Fallback on earlier versions
        }
    }

    private static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
