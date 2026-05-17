// Adhkar/Services/HifzScheduler.swift
import Foundation

enum HifzReviewButton: String, CaseIterable {
    case again, hard, good, easy
}

/// Pure simplified SM-2 scheduler. No I/O, no SwiftData dependency.
/// Mutates the passed-in `HifzCard` in place (SwiftData @Model classes are
/// reference types, so changes are picked up by the model context).
enum HifzScheduler {
    static let initialEase: Double = 2.5
    static let minEase: Double = 1.3

    /// Apply the user's rating to a card. Updates intervalDays, easeFactor,
    /// reps, lapses, nextReviewAt, lastReviewedAt, and stage.
    static func schedule(_ card: HifzCard, button: HifzReviewButton, now: Date = .now) {
        card.lastReviewedAt = now

        if card.reps == 0 {
            switch button {
            case .again:
                card.intervalDays = 0
                card.nextReviewAt = now
                card.lapses += 1
            case .hard, .good:
                card.intervalDays = 1
                card.nextReviewAt = addDays(1, to: now)
                card.reps = 1
            case .easy:
                card.intervalDays = 4
                card.nextReviewAt = addDays(4, to: now)
                card.reps = 1
            }
        } else {
            switch button {
            case .again:
                card.intervalDays = 0
                card.nextReviewAt = now
                card.easeFactor = max(minEase, card.easeFactor - 0.20)
                card.lapses += 1
                card.reps = 0
            case .hard:
                card.intervalDays *= 1.2
                card.easeFactor = max(minEase, card.easeFactor - 0.15)
                card.nextReviewAt = addDays(card.intervalDays, to: now)
                card.reps += 1
            case .good:
                card.intervalDays *= card.easeFactor
                card.nextReviewAt = addDays(card.intervalDays, to: now)
                card.reps += 1
            case .easy:
                card.intervalDays *= card.easeFactor * 1.3
                card.easeFactor += 0.15
                card.nextReviewAt = addDays(card.intervalDays, to: now)
                card.reps += 1
            }
        }

        card.stage = computeStage(reps: card.reps, intervalDays: card.intervalDays)
    }

    /// What each button would set `intervalDays` to if pressed now. Used by
    /// `ReviewSessionView` to show dynamic delay hints under the 4 buttons
    /// without mutating the card.
    static func previewIntervals(for card: HifzCard) -> [HifzReviewButton: Double] {
        var result: [HifzReviewButton: Double] = [:]
        for button in HifzReviewButton.allCases {
            if card.reps == 0 {
                switch button {
                case .again:       result[button] = 0
                case .hard, .good: result[button] = 1
                case .easy:        result[button] = 4
                }
            } else {
                switch button {
                case .again: result[button] = 0
                case .hard:  result[button] = card.intervalDays * 1.2
                case .good:  result[button] = card.intervalDays * card.easeFactor
                case .easy:  result[button] = card.intervalDays * card.easeFactor * 1.3
                }
            }
        }
        return result
    }

    static func computeStage(reps: Int, intervalDays: Double) -> HifzStage {
        if reps == 0 { return .new }
        if reps >= 3 && intervalDays >= 14 { return .anchored }
        return .learning
    }

    private static func addDays(_ days: Double, to date: Date) -> Date {
        date.addingTimeInterval(days * 86_400)
    }
}
