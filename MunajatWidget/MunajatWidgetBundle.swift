//
//  MunajatWidgetBundle.swift
//  MunajatWidget
//
//  Created by Achraf Trabelsi on 12/05/2026.
//

import WidgetKit
import SwiftUI

@main
struct MunajatWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
    }
}

/// Stub widget so the target compiles. Phase 4 replaces this with
/// `CurrentPeriodWidget` (timeline based on morning/evening/sleep slots).
struct PlaceholderWidget: Widget {
    let kind: String = "MunajatPlaceholderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { entry in
            VStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Munajat")
                    .font(.headline)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Munajat")
        .description("Today's dhikr.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .after(next)))
    }
}
