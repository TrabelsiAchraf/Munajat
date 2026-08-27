//
//  PostPrayerSessionView.swift
//  Adhkar
//

import SwiftUI
import SwiftData

/// Guided walk through the post-prayer adhkar. One step at a time, a large
/// tap target, and the full list underneath so the ritual reads as a whole.
struct PostPrayerSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakService.self) private var streak
    @Environment(AudioPlayer.self) private var audio

    @State private var session = PostPrayerSession(steps: PostPrayerSequence.steps)
    @SceneStorage("postPrayer.snapshot") private var storedSnapshot: Data?
    @State private var completionRecorded = false

    private let accent = Color.orange

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(decorated: true)
                ScrollView {
                    VStack(spacing: 24) {
                        progressBar
                        if let step = session.currentStep {
                            stepCard(step)
                            counterButton(step)
                            controls(step)
                        } else {
                            completionCard
                        }
                        stepList
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(L10n.postPrayerTitle.resolved())
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.postPrayerClose.resolved()) { dismiss() }
                }
            }
        }
        .sensoryFeedback(.impact, trigger: session.count)
        .sensoryFeedback(.success, trigger: session.index)
        .onAppear(perform: restore)
        .onDisappear { audio.stop() }
        .onChange(of: session.index) { _, _ in audio.stop() }
        .onChange(of: session.snapshot) { _, _ in persist() }
        .onChange(of: session.isComplete) { _, complete in
            guard complete, !completionRecorded else { return }
            completionRecorded = true
            streak.recordDhikrCompleted(context: modelContext)
            storedSnapshot = nil
        }
    }

    // MARK: - Pieces

    private var progressBar: some View {
        VStack(spacing: 6) {
            ProgressView(value: session.progress)
                .tint(accent)
            Text("\(min(session.index + 1, session.steps.count)) \(L10n.postPrayerStepOf.resolved()) \(session.steps.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func stepCard(_ step: PostPrayerStep) -> some View {
        VStack(spacing: 12) {
            if let scope = step.onlyAfter {
                Text(scope.label.resolved())
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.15))
                    .clipShape(Capsule())
            }
            Text(step.displayArabic)
                .font(.amiri(size: 26))
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
            if let translit = step.displayTransliteration {
                Text(translit)
                    .font(.subheadline.italic())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let translation = step.displayTranslation {
                Text(translation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let item = step.sourceItem {
                if !item.source.isEmpty {
                    Text(item.source)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                if let audioURL = item.audio.flatMap(URL.init(string:)) {
                    Button {
                        audio.toggle(itemId: item.id, url: audioURL)
                    } label: {
                        Label(audio.isPlaying(itemId: item.id) ? L10n.pause.resolved()
                                                               : L10n.listen.resolved(),
                              systemImage: audio.isPlaying(itemId: item.id) ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func counterButton(_ step: PostPrayerStep) -> some View {
        Button {
            session.increment()
        } label: {
            ZStack {
                Circle().fill(accent.opacity(0.12))
                Circle().stroke(accent.opacity(0.20), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(Double(session.count) / Double(max(step.repetitions, 1)), 1))
                    .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.2), value: session.count)
                VStack(spacing: 2) {
                    Text("\(session.count)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                    Text("/ \(step.repetitions)")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)
        }
        .buttonStyle(.plain)
        .disabled(session.awaitingConfirmation)
        .accessibilityLabel(L10n.postPrayerTitle.resolved())
        .accessibilityValue("\(session.count) / \(step.repetitions)")
    }

    @ViewBuilder
    private func controls(_ step: PostPrayerStep) -> some View {
        HStack(spacing: 12) {
            if step.onlyAfter != nil, !session.awaitingConfirmation {
                Button(L10n.postPrayerSkip.resolved()) { session.skip() }
                    .buttonStyle(.bordered)
            }
            if session.awaitingConfirmation {
                Button(L10n.postPrayerNext.resolved()) { session.confirmAdvance() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .tint(accent)
    }

    private var completionCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(accent)
            Text(L10n.postPrayerDone.resolved())
                .font(.title3.weight(.bold))
            Button(L10n.postPrayerRestart.resolved()) {
                session = PostPrayerSession(steps: PostPrayerSequence.steps)
                completionRecorded = false
            }
            .buttonStyle(.bordered)
            .tint(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(session.steps.enumerated()), id: \.element.id) { offset, step in
                HStack(spacing: 10) {
                    Image(systemName: offset < session.index ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(offset < session.index ? accent : .secondary)
                    Text(step.displayArabic)
                        .font(.amiri(size: 15))
                        .lineLimit(1)
                        .foregroundStyle(offset == session.index ? .primary : .secondary)
                    Spacer()
                    if step.repetitions > 1 {
                        Text("×\(step.repetitions)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color("CardBackground").opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Snapshot

    private func restore() {
        guard let storedSnapshot,
              let snapshot = try? JSONDecoder().decode(PostPrayerSession.Snapshot.self, from: storedSnapshot)
        else { return }
        session = PostPrayerSession(steps: PostPrayerSequence.steps, restoring: snapshot)
    }

    private func persist() {
        storedSnapshot = try? JSONEncoder().encode(session.snapshot)
    }
}
