//
//  PostPrayerSession.swift
//  Adhkar
//

import Foundation

/// Progression through a guided sequence. A value type with no SwiftUI and no
/// persistence: the view owns it in `@State` and mirrors `snapshot` to
/// `@SceneStorage`.
///
/// Deliberately **not** backed by `DhikrProgress`: that model is keyed per
/// item and resets on day change, which is right for morning and evening
/// adhkar but wrong here — this sequence is recited after every prayer, so
/// each session must start from zero.
struct PostPrayerSession: Equatable {
    let steps: [PostPrayerStep]
    private(set) var index: Int
    private(set) var count: Int

    struct Snapshot: Codable, Equatable {
        var stepCount: Int
        var index: Int
        var count: Int
    }

    init(steps: [PostPrayerStep], restoring snapshot: Snapshot? = nil) {
        self.steps = steps
        // A snapshot from a build with a different sequence would resume into
        // the wrong dhikr — start over instead.
        if let snapshot,
           snapshot.stepCount == steps.count,
           snapshot.index >= 0, snapshot.index <= steps.count,
           snapshot.count >= 0 {
            self.index = snapshot.index
            self.count = snapshot.count
        } else {
            self.index = 0
            self.count = 0
        }
    }

    var currentStep: PostPrayerStep? { index < steps.count ? steps[index] : nil }
    /// The current step has been recited its full count. Advancing is left to
    /// the caller so the filled ring can stay on screen for a beat.
    var isStepFinished: Bool {
        guard let step = currentStep else { return false }
        return count >= step.repetitions
    }
    var isComplete: Bool { index >= steps.count }
    var progress: Double {
        steps.isEmpty ? 1 : min(Double(index) / Double(steps.count), 1)
    }
    var snapshot: Snapshot {
        Snapshot(stepCount: steps.count, index: index, count: count)
    }

    /// One tap. Counting and advancing are deliberately separate: when the
    /// same gesture did both, a single-repetition step swapped itself out
    /// before the progress ring could draw, so the tap had no visible effect.
    /// The view watches `isStepFinished`, holds the filled ring, then calls
    /// `advance()`. Taps past the target are ignored.
    mutating func increment() {
        guard !isComplete, let step = currentStep, count < step.repetitions else { return }
        count += 1
    }

    /// Move to the next step, or complete the session if this was the last one.
    mutating func advance() {
        guard !isComplete else { return }
        index += 1
        count = 0
    }

    /// Advance only if the current step is done. Keeps the decision in tested
    /// code: the view is left with nothing but the delay that lets the filled
    /// ring be seen. Returns whether it moved.
    @discardableResult
    mutating func advanceIfFinished() -> Bool {
        guard isStepFinished else { return false }
        advance()
        return true
    }

    /// Move on without finishing — used by the conditional steps.
    mutating func skip() { advance() }
}
