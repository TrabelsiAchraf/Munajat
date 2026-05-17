// Adhkar/Views/HomeContextCard.swift
import SwiftUI

/// Headline card at the top of the Home screen. Tapping it opens the
/// context picker sheet. The action is injected so HomeView owns the
/// presentation state.
struct HomeContextCard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.35), Color.orange.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.contextHomeCardLabel.resolved())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(L10n.contextHomeCardHint.resolved())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.contextHomeCardLabel.resolved()). \(L10n.contextHomeCardHint.resolved())")
        .accessibilityHint(L10n.contextHomeCardLabel.resolved())
        .accessibilityAddTraits(.isButton)
    }
}
