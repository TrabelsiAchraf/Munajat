// Adhkar/Views/ContextDhikrRow.swift
import SwiftUI

/// One row in `ContextDetailView`'s curated dhikr list. Shows a short
/// Arabic preview + source/title meta. Tap navigates to the dhikr detail
/// page in single-item mode (handled by the parent's NavigationStack).
struct ContextDhikrRow: View {
    let category: AdhkarCategory
    let dhikr: Adhkar

    private var arabicPreview: String {
        let text = dhikr.dhikr.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count <= 90 { return text }
        return String(text.prefix(88)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private var metaLine: String {
        var parts: [String] = []
        if !dhikr.source.isEmpty { parts.append(dhikr.source) }
        parts.append(category.displayTitle)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(arabicPreview)
                .font(.amiri(size: 18))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(3)

            Text(metaLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dhikr.dhikr). \(metaLine)")
        .accessibilityAddTraits(.isButton)
    }
}
