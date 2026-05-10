//
//  RootTabView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(L10n.tabHome.resolved(), systemImage: "house.fill") }

            FavoritesView()
                .tabItem { Label(L10n.tabFavorites.resolved(), systemImage: "heart.fill") }

            SearchView()
                .tabItem { Label(L10n.tabSearch.resolved(), systemImage: "magnifyingglass") }

            SettingsView()
                .tabItem { Label(L10n.tabSettings.resolved(), systemImage: "gearshape.fill") }
        }
        .tint(.orange)
    }
}
