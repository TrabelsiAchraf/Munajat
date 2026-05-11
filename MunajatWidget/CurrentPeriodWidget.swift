//
//  CurrentPeriodWidget.swift
//  MunajatWidget
//
//  Created by Achraf Trabelsi on 12/05/2026.
//

import WidgetKit
import SwiftUI

/// Glanceable widget showing the adhkar category suggested for the current
/// time of day (morning / evening / sleep), with a snippet of the first
/// dhikr and the user's current streak. Tapping the widget deep-links into
/// the app on that category via `munajat://category/<id>`.
struct CurrentPeriodWidget: Widget {
    let kind: String = "CurrentPeriodWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentPeriodProvider()) { entry in
            CurrentPeriodEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: "#1A2B6E"), Color(hex: "#0F1012")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    CrescentStarPattern(intensity: 0.55, spacing: 80)
                }
                .widgetURL(URL(string: "munajat://category/\(entry.category.id)"))
        }
        .configurationDisplayName(L10n.widgetDisplayName.resolved())
        .description(L10n.widgetDescription.resolved())
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

struct CurrentPeriodEntry: TimelineEntry {
    let date: Date
    let category: AdhkarCategory
    let dhikr: Adhkar
    let streak: Int
}

struct CurrentPeriodProvider: TimelineProvider {
    /// Hours of day at which the suggested adhkar period changes — must
    /// match the boundaries in `AdhkarType.forCurrentHour()`.
    private static let periodBoundaries: [Int] = [4, 12, 19]

    /// Read by the host app's `StreakService`; the widget only reads.
    private static let appGroupDefaults = UserDefaults(suiteName: "group.com.tadevv.Munajat")
    private static let currentStreakKey = "streak.current"

    func placeholder(in context: Context) -> CurrentPeriodEntry {
        Self.entry(at: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentPeriodEntry) -> Void) {
        completion(Self.entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrentPeriodEntry>) -> Void) {
        let now = Date.now
        let entries = [Self.entry(at: now)]
        let next = Self.nextPeriodTransition(after: now) ?? now.addingTimeInterval(60 * 60)
        completion(Timeline(entries: entries, policy: .after(next)))
    }

    private static func entry(at date: Date) -> CurrentPeriodEntry {
        let type = AdhkarType.forCurrentHour(now: date)
        let category = DataProvider.adharCategories.first(where: { $0.type == type })
            ?? DataProvider.adharCategories.first!
        let dhikr = category.adhkarList.first
            ?? Adhkar(id: "fallback",
                      dhikr: "سُبْحَانَ اللَّهِ",
                      transliteration: nil,
                      translation: LocalizedText(ar: nil, fr: "Gloire à Allah", en: "Glory be to Allah"),
                      source: "",
                      count: 1,
                      audio: nil,
                      virtue: nil)
        let streak = appGroupDefaults?.integer(forKey: currentStreakKey) ?? 0
        return CurrentPeriodEntry(date: date, category: category, dhikr: dhikr, streak: streak)
    }

    private static func nextPeriodTransition(after date: Date) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let today = cal.startOfDay(for: date)
        let candidates: [Date] = periodBoundaries.compactMap { hour in
            cal.date(byAdding: .hour, value: hour, to: today)
        }
        if let next = candidates.first(where: { $0 > date }) {
            return next
        }
        // No remaining transition today — wrap to tomorrow at 04:00.
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: today),
              let firstSlot = periodBoundaries.first
        else { return nil }
        return cal.date(byAdding: .hour, value: firstSlot, to: tomorrow)
    }
}

// MARK: - View

struct CurrentPeriodEntryView: View {
    let entry: CurrentPeriodEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        default:            smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            periodPill
            Text(entry.dhikr.dhikr)
                .font(.amiri(size: 16, bold: true))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            streakFooter
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                periodPill
                Text(entry.category.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                streakFooter
            }
            Divider()
                .overlay(Color.white.opacity(0.25))
            VStack(alignment: .trailing, spacing: 6) {
                Text(entry.dhikr.dhikr)
                    .font(.amiri(size: 18, bold: true))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                if let translation = entry.dhikr.translation?.resolved(), !translation.isEmpty {
                    Text(translation)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var periodPill: some View {
        HStack(spacing: 4) {
            Image(systemName: periodIcon)
                .font(.caption2.weight(.semibold))
            Text(periodTitle)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.15))
        .clipShape(Capsule())
    }

    private var streakFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.streak > 0 ? "flame.fill" : "flame")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(hex: "#FFB347"))
            Text("\(entry.streak)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var periodTitle: String {
        switch entry.category.type {
        case .morningAdhkar: return L10n.slotMorning.resolved()
        case .eveningAdhkar: return L10n.slotEvening.resolved()
        case .sleepAdhkar:   return L10n.slotSleep.resolved()
        default:             return entry.category.displayTitle
        }
    }

    private var periodIcon: String {
        switch entry.category.type {
        case .morningAdhkar: return "sun.and.horizon.fill"
        case .eveningAdhkar: return "sun.haze.fill"
        case .sleepAdhkar:   return "moon.stars.fill"
        default:             return "sparkles"
        }
    }
}
