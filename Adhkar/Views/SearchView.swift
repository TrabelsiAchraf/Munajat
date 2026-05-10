//
//  SearchView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import SwiftUI

struct SearchView: View {
    @State private var query = ""
    private let allCategories = DataProvider.adharCategories

    private var results: [AdhkarCategory] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        return allCategories.filter { cat in
            if cat.displayTitle.lowercased().contains(lower) { return true }
            if cat.title.ar?.contains(trimmed) == true { return true }
            if cat.title.fr?.lowercased().contains(lower) == true { return true }
            if cat.title.en?.lowercased().contains(lower) == true { return true }
            return cat.adhkarList.contains { $0.dhikr.contains(trimmed) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground()
                if query.isEmpty {
                    placeholder
                } else if results.isEmpty {
                    emptyResults
                } else {
                    List(results) { cat in
                        NavigationLink(value: cat) {
                            HStack(spacing: 12) {
                                cat.type.image
                                    .foregroundStyle((cat.section ?? .other).accentColor)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.displayTitle)
                                        .lineLimit(2)
                                    Text("\(cat.adhkarList.count) ذكر")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color.cardBackground)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(L10n.tabSearch.resolved())
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: L10n.searchPrompt.resolved())
            .navigationDestination(for: AdhkarCategory.self) { cat in
                AdhkarDetailsView(adhkar: cat)
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.searchPlaceholder.resolved())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var emptyResults: some View {
        VStack(spacing: 8) {
            Text("\(L10n.searchEmptyResults.resolved()) « \(query) »")
                .font(.headline)
            Text(L10n.searchTryAnother.resolved())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
