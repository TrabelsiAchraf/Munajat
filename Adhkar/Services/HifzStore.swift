// Adhkar/Services/HifzStore.swift
import Foundation
import SwiftData

/// Read/write façade for `HifzCard`. UI views use this instead of inline
/// FetchDescriptors so the query logic lives in one place.
enum HifzStore {
    static func find(itemId: String, in context: ModelContext) -> HifzCard? {
        let descriptor = FetchDescriptor<HifzCard>(
            predicate: #Predicate<HifzCard> { $0.itemId == itemId }
        )
        return (try? context.fetch(descriptor))?.first
    }

    static func isMemorizing(itemId: String, in context: ModelContext) -> Bool {
        find(itemId: itemId, in: context) != nil
    }

    @discardableResult
    static func add(itemId: String, in context: ModelContext, now: Date = .now) -> HifzCard {
        if let existing = find(itemId: itemId, in: context) { return existing }
        let card = HifzCard(itemId: itemId, now: now)
        context.insert(card)
        try? context.save()
        return card
    }

    static func remove(itemId: String, in context: ModelContext) {
        if let existing = find(itemId: itemId, in: context) {
            context.delete(existing)
            try? context.save()
        }
    }

    static func dueToday(in context: ModelContext, now: Date = .now) -> [HifzCard] {
        let endOfDay = Calendar(identifier: .gregorian).date(
            bySettingHour: 23, minute: 59, second: 59, of: now
        ) ?? now
        let descriptor = FetchDescriptor<HifzCard>(
            predicate: #Predicate<HifzCard> { $0.nextReviewAt <= endOfDay },
            sortBy: [SortDescriptor(\.nextReviewAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func all(in context: ModelContext) -> [HifzCard] {
        let descriptor = FetchDescriptor<HifzCard>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func countByStage(in context: ModelContext) -> [HifzStage: Int] {
        let all = self.all(in: context)
        var counts: [HifzStage: Int] = [:]
        for stage in HifzStage.allCases { counts[stage] = 0 }
        for card in all { counts[card.stage, default: 0] += 1 }
        return counts
    }
}
