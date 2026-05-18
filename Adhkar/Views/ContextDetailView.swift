// Adhkar/Views/ContextDetailView.swift
import SwiftUI

/// Detail screen pushed onto the picker's navigation stack after the user
/// picks a context. Shows the context header (icon + title + intro) and
/// the curated dhikr rows resolved from `context.dhikrIds`.
struct ContextDetailView: View {
    let context: LifeContext

    /// Resolved (AdhkarCategory, Adhkar) pairs in the order specified by
    /// the context's `dhikrIds`. Unknown ids are silently dropped so a
    /// content typo doesn't crash the app.
    private var resolvedItems: [(AdhkarCategory, Adhkar)] {
        let allCategories = DataProvider.adharCategories
        return context.dhikrIds.compactMap { id in
            for category in allCategories {
                if let dhikr = category.adhkarList.first(where: { $0.id == id }) {
                    return (category, dhikr)
                }
            }
            return nil
        }
    }

    private var accentColor: Color {
        Color.namedAccent(context.color)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if resolvedItems.isEmpty {
                    emptyState
                } else {
                    suggestedSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(AdaptiveBackground(decorated: true))
        .navigationTitle(context.title.resolved())
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.20))
                    .frame(width: 64, height: 64)
                Image(systemName: context.iconName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            Text(context.title.resolved())
                .font(.largeTitle.weight(.bold))
            Text(context.intro.resolved())
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.contextDhikrSuggested.resolved())
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(Array(resolvedItems.enumerated()), id: \.offset) { _, pair in
                    NavigationLink(value: ContextDhikrTarget(categoryId: pair.0.id, itemId: pair.1.id, navTitle: context.title)) {
                        ContextDhikrRow(category: pair.0, dhikr: pair.1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(L10n.contextEmptyTitle.resolved())
                .font(.headline)
            Text(L10n.contextEmptyHint.resolved())
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Navigation value used to push `AdhkarDetailsView` in single-item mode
/// from within the context picker sheet's NavigationStack.
struct ContextDhikrTarget: Hashable {
    let categoryId: String
    let itemId: String
    let navTitle: LocalizedText
}

/// Maps `LifeContext.color` strings to SwiftUI Color. Keep in sync with
/// the colors used in `contexts.json`.
extension Color {
    static func namedAccent(_ name: String) -> Color {
        switch name {
        case "blue":   return .blue
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "red":    return .red
        case "orange": return .orange
        case "teal":   return .teal
        case "pink":   return .pink
        case "brown":  return .brown
        case "purple": return .purple
        case "gray":   return .gray
        default:       return .orange
        }
    }
}
