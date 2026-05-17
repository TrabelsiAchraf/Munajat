// Adhkar/Models/HifzCard.swift
import Foundation
import SwiftData

/// Spaced-repetition card for a dhikr the user opted to memorize.
/// `itemId` references `Adhkar.id` (globally unique).
@Model
final class HifzCard {
    @Attribute(.unique) var itemId: String
    var addedAt: Date
    var lastReviewedAt: Date?
    var nextReviewAt: Date
    var intervalDays: Double
    var easeFactor: Double
    var reps: Int
    var lapses: Int
    var stageRaw: String

    var stage: HifzStage {
        get { HifzStage(rawValue: stageRaw) ?? .new }
        set { stageRaw = newValue.rawValue }
    }

    init(itemId: String, now: Date = .now) {
        self.itemId = itemId
        self.addedAt = now
        self.lastReviewedAt = nil
        self.nextReviewAt = now  // new cards are due immediately
        self.intervalDays = 0
        self.easeFactor = 2.5
        self.reps = 0
        self.lapses = 0
        self.stageRaw = HifzStage.new.rawValue
    }
}

enum HifzStage: String, Codable, CaseIterable {
    case new        // never reviewed
    case learning   // reps < 3
    case anchored   // reps >= 3 AND intervalDays >= 14
}
