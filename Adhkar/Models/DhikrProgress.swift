//
//  DhikrProgress.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import Foundation
import SwiftData

/// Persistent per-dhikr counter. Survives app launches.
/// `lastUpdated` is used by `DhikrPageView` to auto-reset the counter
/// on a new day (so daily Adhkar like Sabah/Massa start fresh each morning).
@Model
final class DhikrProgress {
    @Attribute(.unique) var itemId: String
    var count: Int
    var lastUpdated: Date

    init(itemId: String, count: Int = 0, lastUpdated: Date = .now) {
        self.itemId = itemId
        self.count = count
        self.lastUpdated = lastUpdated
    }
}
