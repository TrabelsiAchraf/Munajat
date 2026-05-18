// Adhkar/Views/ReviewSessionSummaryView.swift
import SwiftUI

struct ReviewSessionSummaryView: View {
    let reviewed: Int
    let anchored: Int
    let learning: Int
    let again: Int
    let nextSessionDescription: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(L10n.reviewSummaryTitle.resolved())
                .font(.title2.weight(.bold))
            Text("\(reviewed) \(L10n.reviewSummaryReviewed.resolved())")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                summaryRow(label: L10n.reviewSummaryAnchored.resolved(), value: anchored, color: .green)
                summaryRow(label: L10n.reviewSummaryLearning.resolved(), value: learning, color: .blue)
                summaryRow(label: L10n.reviewSummaryAgain.resolved(),    value: again,    color: .red)
            }

            Divider().padding(.vertical, 6)

            VStack(spacing: 4) {
                Text(L10n.reviewSummaryNext.resolved())
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(nextSessionDescription)
                    .font(.body)
            }

            Button(action: onDismiss) {
                Text(L10n.done.resolved())
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .foregroundStyle(.black)
                    .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(28)
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            try? await Task.sleep(for: .seconds(8))
            onDismiss()
        }
    }

    private func summaryRow(label: String, value: Int, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
            Spacer()
            Text("\(value)").monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
    }
}
