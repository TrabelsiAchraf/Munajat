//
//  FavoritesView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(FavoritesStore.self) private var favorites
    private let allCategories = DataProvider.adharCategories

    private var favoriteCategories: [AdhkarCategory] {
        allCategories.filter { favorites.contains($0.id) }
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground()
                if favoriteCategories.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(favoriteCategories) { cat in
                                AdhkarCardView(category: cat)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(L10n.tabFavorites.resolved())
            .navigationDestination(for: AdhkarCategory.self) { cat in
                AdhkarDetailsView(adhkar: cat)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(L10n.favoritesEmptyTitle.resolved())
                .font(.headline)
            Text(L10n.favoritesEmptyHint.resolved())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
