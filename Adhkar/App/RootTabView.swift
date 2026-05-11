//
//  RootTabView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakService.self) private var streak
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(L10n.tabHome.resolved(), systemImage: "house.fill") }
                .accessibilityIdentifier("tab.home")

            FavoritesView()
                .tabItem { Label(L10n.tabFavorites.resolved(), systemImage: "heart.fill") }
                .accessibilityIdentifier("tab.favorites")

            SearchView()
                .tabItem { Label(L10n.tabSearch.resolved(), systemImage: "magnifyingglass") }
                .accessibilityIdentifier("tab.search")

            SettingsView()
                .tabItem { Label(L10n.tabSettings.resolved(), systemImage: "gearshape.fill") }
                .accessibilityIdentifier("tab.settings")
        }
        .tint(.orange)
        .task { streak.recordOpen(context: modelContext) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { streak.recordOpen(context: modelContext) }
        }
    }
}
