// Adhkar/Views/ContextPickerView.swift
import SwiftUI

/// Sheet content shown when the user taps the home context card.
/// Owns an internal NavigationStack so picker → context detail → dhikr
/// detail all live inside the sheet and dismiss together on "Annuler".
struct ContextPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()
    private let contexts = DataProvider.lifeContexts

    private var emotions: [LifeContext] { contexts.filter { $0.family == .emotion } }
    private var trials:   [LifeContext] { contexts.filter { $0.family == .trial   } }

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    familySection(title: L10n.contextFamilyEmotion.resolved(),
                                  items: emotions)
                    familySection(title: L10n.contextFamilyTrial.resolved(),
                                  items: trials)
                }
                .padding()
            }
            .background(Color.black.opacity(0.001))
            .navigationTitle(L10n.contextPickerTitle.resolved())
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.contextCancel.resolved()) { dismiss() }
                }
            }
            .navigationDestination(for: LifeContext.self) { ctx in
                ContextDetailView(context: ctx)
            }
            .navigationDestination(for: ContextDhikrTarget.self) { target in
                if let category = DataProvider.adharCategories.first(where: { $0.id == target.categoryId }) {
                    AdhkarDetailsView(
                        adhkar: category,
                        focusedItemId: target.itemId,
                        navTitleOverride: target.navTitle
                    )
                } else {
                    Text(L10n.contextEmptyTitle.resolved())
                }
            }
            #if DEBUG
            .task {
                if let detailId = UserDefaults.standard.string(forKey: "marketing.contextDetailId"),
                   let ctx = DataProvider.lifeContexts.first(where: { $0.id == detailId }) {
                    try? await Task.sleep(for: .milliseconds(200))
                    path.append(ctx)
                    UserDefaults.standard.removeObject(forKey: "marketing.contextDetailId")
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func familySection(title: String, items: [LifeContext]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { ctx in
                    NavigationLink(value: ctx) {
                        ContextTile(context: ctx)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ContextTile: View {
    let context: LifeContext

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: context.iconName)
                .font(.system(size: 26))
                .foregroundStyle(.orange)
                .frame(height: 32)
            Text(context.title.resolved())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text("\(context.dhikrIds.count) \(L10n.contextDhikrCountSuffix.resolved())")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(context.title.resolved()), \(context.dhikrIds.count) \(L10n.contextDhikrCountSuffix.resolved())")
        .accessibilityAddTraits(.isButton)
    }
}
