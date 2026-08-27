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
    var isComplete: Bool { index >= steps.count }
    var progress: Double {
        steps.isEmpty ? 1 : min(Double(index) / Double(steps.count), 1)
    }
    var snapshot: Snapshot {
        Snapshot(stepCount: steps.count, index: index, count: count)
    }

    /// One tap. A finished step always chains into the next one: a
    /// confirmation button that appeared on some steps and not others read as
    /// a bug rather than as a pause, and the last step had nothing to confirm
    /// into at all. Finishing the last step ends the session, which is what
    /// shows the completion screen.
    mutating func increment() {
        guard !isComplete, let step = currentStep else { return }
        count += 1
        guard count >= step.repetitions else { return }
        advance()
    }

    /// Move on without finishing — used by the conditional steps.
    mutating func skip() {
        guard !isComplete else { return }
        advance()
    }

    private mutating func advance() {
        index += 1
        count = 0
    }
}
