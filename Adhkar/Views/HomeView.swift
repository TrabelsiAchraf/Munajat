//
//  HomeView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import SwiftUI

struct HomeView: View {
    private let allCategories = DataProvider.adharCategories

    /// Navigation path lifted up to `RootTabView` so widget deep links can
    /// push a category from outside this view.
    @Binding var path: NavigationPath

    @State private var isContextPickerPresented = false

    private var sections: [(section: AdhkarSection, categories: [AdhkarCategory])] {
        AdhkarSection.displayOrder.compactMap { sec in
            let cats = allCategories.filter { $0.section == sec }
            return cats.isEmpty ? nil : (sec, cats)
        }
    }

    private var featured: AdhkarCategory? {
        let target = AdhkarType.forCurrentHour()
        return allCategories.first { $0.type == target }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AdaptiveBackground(decorated: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        HeroHeader()
                        HomeContextCard { isContextPickerPresented = true }
                        StreakCard()
                        if let featured {
                            FeaturedSection(category: featured)
                        }
                        ForEach(sections, id: \.section) { entry in
                            section(title: entry.section, categories: entry.categories)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.homeTitle.resolved())
            .navigationDestination(for: AdhkarCategory.self) { cat in
                AdhkarDetailsView(adhkar: cat)
            }
            .sheet(isPresented: $isContextPickerPresented) {
                ContextPickerView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            #if DEBUG
            .task {
                if UserDefaults.standard.bool(forKey: "marketing.openContextPicker") {
                    try? await Task.sleep(for: .milliseconds(300))
                    isContextPickerPresented = true
                    UserDefaults.standard.set(false, forKey: "marketing.openContextPicker")
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func section(title: AdhkarSection, categories: [AdhkarCategory]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: title.iconName)
                    .foregroundStyle(title.accentColor)
                Text(title.displayName.resolved())
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(categories.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(categories) { cat in
                    AdhkarCardView(category: cat)
                }
            }
        }
    }

}

private struct FeaturedSection: View {
    let category: AdhkarCategory

    var body: some View {
        NavigationLink(value: category) {
            HStack(spacing: 14) {
                category.type.image
                    .font(.system(size: 40))
                    .foregroundStyle((category.section ?? .other).accentColor)
                    .frame(width: 60, height: 60)
                    .background(Color.cardBackground)
                    .clipShape(.rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(featuredCaption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle((category.section ?? .other).accentColor)
                    Text(category.displayTitle)
                        .font(.amiri(size: 19, bold: true))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("\(category.adhkarList.count) \(itemsWord)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(featuredCaption). \(category.displayTitle). \(category.adhkarList.count) \(itemsWord)")
        .accessibilityHint(L10n.a11yCategoryCardHint.resolved())
        .accessibilityAddTraits(.isButton)
    }

    private var featuredCaption: String { L10n.suggestedForNow.resolved() }
    private var itemsWord: String { L10n.itemsCountSuffix.resolved() }
}
