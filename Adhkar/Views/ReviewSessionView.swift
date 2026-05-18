// Adhkar/Views/ReviewSessionView.swift
import SwiftUI
import SwiftData
import WidgetKit

struct ReviewSessionView: View {
    let cards: [HifzCard]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var index: Int = 0
    @State private var revealed: Bool = false
    @State private var anchoredCount = 0
    @State private var learningCount = 0
    @State private var againCount = 0
    @State private var showSummary = false

    private var currentCard: HifzCard? {
        guard cards.indices.contains(index) else { return nil }
        return cards[index]
    }

    private var currentDhikr: Adhkar? {
        guard let id = currentCard?.itemId else { return nil }
        for cat in DataProvider.adharCategories {
            if let d = cat.adhkarList.first(where: { $0.id == id }) { return d }
        }
        return nil
    }

    var body: some View {
        if showSummary {
            ReviewSessionSummaryView(
                reviewed: cards.count,
                anchored: anchoredCount,
                learning: learningCount,
                again: againCount,
                nextSessionDescription: nextSessionDescription(),
                onDismiss: { dismiss() }
            )
        } else if let card = currentCard, let dhikr = currentDhikr {
            sessionBody(card: card, dhikr: dhikr)
        } else {
            // No cards to review — exit immediately.
            Color.clear.onAppear { dismiss() }
        }
    }

    @ViewBuilder
    private func sessionBody(card: HifzCard, dhikr: Adhkar) -> some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                if revealed {
                    revealedCard(dhikr: dhikr)
                } else {
                    promptCard(dhikr: dhikr)
                }
            }
            if revealed {
                ratingButtons(card: card)
            } else {
                revealButton
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline)
                }
                .tint(.orange)
                Spacer()
                Text("\(index + 1) / \(cards.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Color.clear.frame(width: 24, height: 1)
            }
            ProgressView(value: Double(index + 1), total: Double(cards.count))
                .progressViewStyle(.linear)
                .tint(.orange)
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func promptCard(dhikr: Adhkar) -> some View {
        VStack(alignment: .center, spacing: 14) {
            Text(L10n.reviewMeaningLabel.resolved())
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.orange)
            Text(dhikr.translation?.resolved() ?? "—")
                .font(.title3.italic())
                .multilineTextAlignment(.center)
            if !dhikr.source.isEmpty {
                Text(dhikr.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 18))
        .padding()
    }

    private var revealButton: some View {
        Button { revealed = true } label: {
            Text(L10n.reviewReveal.resolved())
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange)
                .foregroundStyle(.black)
                .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.bottom, 14)
        .padding(.top, 4)
    }

    private func revealedCard(dhikr: Adhkar) -> some View {
        VStack(alignment: .center, spacing: 14) {
            Text(dhikr.dhikr)
                .font(.amiri(size: 24))
                .multilineTextAlignment(.center)
                .lineSpacing(12)
            if let t = dhikr.translation?.resolved(), !t.isEmpty {
                Text(t)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if !dhikr.source.isEmpty {
                Text(dhikr.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 18))
        .padding()
    }

    private func ratingButtons(card: HifzCard) -> some View {
        let preview = HifzScheduler.previewIntervals(for: card)
        return VStack(spacing: 8) {
            Text(L10n.reviewRateLabel.resolved())
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                button(.again, label: L10n.reviewAgain, color: .red,    days: preview[.again] ?? 0, card: card)
                button(.hard,  label: L10n.reviewHard,  color: .yellow, days: preview[.hard]  ?? 1, card: card)
                button(.good,  label: L10n.reviewGood,  color: .green,  days: preview[.good]  ?? 1, card: card)
                button(.easy,  label: L10n.reviewEasy,  color: .blue,   days: preview[.easy]  ?? 4, card: card)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 14)
    }

    private func button(_ rating: HifzReviewButton, label: LocalizedText, color: Color, days: Double, card: HifzCard) -> some View {
        Button {
            apply(rating, to: card)
        } label: {
            VStack(spacing: 4) {
                Text(label.resolved())
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                Text(daysLabel(days))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label.resolved()), \(daysLabel(days))")
    }

    private func daysLabel(_ days: Double) -> String {
        if days < 0.5 { return L10n.reviewToday.resolved() }
        return "+\(Int(days.rounded())) \(L10n.reviewDays.resolved())"
    }

    private func apply(_ rating: HifzReviewButton, to card: HifzCard) {
        HifzScheduler.schedule(card, button: rating, now: .now)
        try? modelContext.save()

        switch rating {
        case .again: againCount += 1
        case .hard, .good, .easy:
            if card.stage == .anchored { anchoredCount += 1 }
            else { learningCount += 1 }
        }

        revealed = false
        if index + 1 < cards.count {
            index += 1
        } else {
            // Reload widget after session ends.
            #if os(iOS)
            WidgetCenter.shared.reloadTimelines(ofKind: "CurrentPeriodWidget")
            #endif
            showSummary = true
        }
    }

    private func nextSessionDescription() -> String {
        let tomorrow = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: .now) ?? .now
        let count = HifzStore.dueToday(in: modelContext, now: tomorrow).count
        return "\(count)"
    }
}
