//
//  DailyActivity.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 11/05/2026.
//

import Foundation
import SwiftData

/// One row per day the user opened the app at least once. `dayKey` is a
/// `yyyy-MM-dd` string built from a Gregorian calendar in the local time zone
/// — this sidesteps Hijri-calendar misbehaviour on devices set to an Islamic
/// locale, and survives time-zone changes without losing past entries.
@Model
final class DailyActivity {
    @Attribute(.unique) var dayKey: String
    var itemsRead: Int
    var firstOpen: Date

    init(dayKey: String, itemsRead: Int = 0, firstOpen: Date = .now) {
        self.dayKey = dayKey
        self.itemsRead = itemsRead
        self.firstOpen = firstOpen
    }
}
