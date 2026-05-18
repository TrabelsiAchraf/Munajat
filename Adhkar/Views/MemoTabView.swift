// Adhkar/Views/MemoTabView.swift
import SwiftUI
import SwiftData

struct MemoTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HifzCard.addedAt, order: .reverse) private var allCards: [HifzCard]
    @State private var showReviewSession = false

    private var dueToday: [HifzCard] {
        let endOfDay = Calendar(identifier: .gregorian).date(
            bySettingHour: 23, minute: 59, second: 59, of: .now
        ) ?? .now
        return allCards.filter { $0.nextReviewAt <= endOfDay }
            .sorted { $0.nextReviewAt < $1.nextReviewAt }
    }

    private var counts: [HifzStage: Int] {
        var c: [HifzStage: Int] = [:]
        for stage in HifzStage.allCases { c[stage] = 0 }
        for card in allCards { c[card.stage, default: 0] += 1 }
        return c
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(decorated: false)
                if allCards.isEmpty {
                    emptyState
                } else {
                    filledContent
                }
            }
            .navigationTitle(L10n.tabMemorize.resolved())
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .fullScreenCover(isPresented: $showReviewSession) {
                ReviewSessionView(cards: dueToday)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text(L10n.memoEmptyTitle.resolved())
                .font(.title3.weight(.semibold))
            Text(L10n.memoEmptyHint.resolved())
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var filledContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                dueCard
                progressSection
                allCardsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private var dueCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(dueToday.count) \(L10n.memoDueTodayPrefix.resolved())")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .monospacedDigit()
                Spacer()
            }
            Button {
                guard !dueToday.isEmpty else { return }
                showReviewSession = true
            } label: {
                HStack {
                    Text(dueToday.isEmpty ? L10n.memoAllUpToDate.resolved() : L10n.memoStartSession.resolved())
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(dueToday.isEmpty ? Color.cardBackground : Color.orange)
                .foregroundStyle(dueToday.isEmpty ? Color.secondary : Color.black)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(dueToday.isEmpty)
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.memoProgressTitle.resolved())
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                progressRow(label: L10n.memoStageNew.resolved(),      value: counts[.new] ?? 0)
                progressRow(label: L10n.memoStageLearning.resolved(), value: counts[.learning] ?? 0)
                progressRow(label: L10n.memoStageAnchored.resolved(), value: counts[.anchored] ?? 0)
            }
        }
    }

    private func progressRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)").monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 10))
    }

    private var allCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.memoAllCardsTitle.resolved())
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                ForEach(allCards) { card in
                    MemoCardRow(card: card)
                }
            }
        }
    }
}

private struct MemoCardRow: View {
    let card: HifzCard

    private var dhikrAndCategory: (Adhkar, AdhkarCategory)? {
        let id = card.itemId
        for cat in DataProvider.adharCategories {
            if let d = cat.adhkarList.first(where: { $0.id == id }) { return (d, cat) }
        }
        return nil
    }

    private var nextDescription: String {
        if Calendar(identifier: .gregorian).isDateInToday(card.nextReviewAt) {
            return L10n.reviewToday.resolved()
        }
        let days = max(0, Int(card.intervalDays.rounded()))
        return "\(days) \(L10n.reviewDays.resolved())"
    }

    private var stageDescription: String {
        switch card.stage {
        case .new:       return L10n.memoStageNew.resolved()
        case .learning:  return L10n.memoStageLearning.resolved()
        case .anchored:  return L10n.memoStageAnchored.resolved()
        }
    }

    var body: some View {
        let (title, source): (String, String) = {
            if let (d, c) = dhikrAndCategory {
                return (c.displayTitle, d.source.isEmpty ? "" : d.source)
            }
            return (card.itemId, "")
        }()

        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(stageDescription) · \(nextDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(stageDescription), \(nextDescription)")
    }
}
