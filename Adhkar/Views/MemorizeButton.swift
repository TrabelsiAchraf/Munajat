// Adhkar/Views/MemorizeButton.swift
import SwiftUI
import SwiftData

/// Opt-in button shown on each dhikr page. Adds/removes the dhikr from
/// the user's Hifz list. Confirms removal via alert.
struct MemorizeButton: View {
    let itemId: String
    let accent: Color

    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [HifzCard]
    @State private var showRemoveConfirm = false
    @State private var feedbackTrigger = 0

    init(itemId: String, accent: Color = .orange) {
        self.itemId = itemId
        self.accent = accent
        // Per-instance predicate via @Query init
        let id = itemId
        _cards = Query(filter: #Predicate<HifzCard> { $0.itemId == id })
    }

    private var isMemorizing: Bool { !cards.isEmpty }

    var body: some View {
        Button {
            if isMemorizing {
                showRemoveConfirm = true
            } else {
                HifzStore.add(itemId: itemId, in: modelContext)
                feedbackTrigger += 1
            }
        } label: {
            Label(
                isMemorizing ? L10n.memorizeAddedLabel.resolved() : L10n.memorizeAddLabel.resolved(),
                systemImage: isMemorizing ? "brain.fill" : "brain"
            )
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isMemorizing ? accent.opacity(0.2) : Color.cardBackground)
            .foregroundStyle(accent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .accessibilityLabel(isMemorizing ? L10n.memorizeAddedLabel.resolved() : L10n.memorizeAddLabel.resolved())
        .alert(
            L10n.memorizeRemoveConfirm.resolved(),
            isPresented: $showRemoveConfirm
        ) {
            Button(L10n.memorizeRemoveYes.resolved(), role: .destructive) {
                HifzStore.remove(itemId: itemId, in: modelContext)
            }
            Button(L10n.memorizeRemoveNo.resolved(), role: .cancel) {}
        }
    }
}
