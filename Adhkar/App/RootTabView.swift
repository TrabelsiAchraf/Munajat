//
//  RootTabView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import SwiftUI
import SwiftData

enum RootTab: Hashable {
    case home, favorites, search, settings
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakService.self) private var streak
    @Environment(\.scenePhase) private var scenePhase

    /// Bound to `AdhkarApp.pendingDeepLinkCategoryId`. When set, we switch
    /// to the home tab and push the matching `AdhkarCategory` onto its
    /// navigation path, then clear the binding.
    @Binding var pendingDeepLinkCategoryId: String?

    @State private var selection: RootTab = .home
    @State private var homePath = NavigationPath()

    var body: some View {
        TabView(selection: $selection) {
            HomeView(path: $homePath)
                .tabItem { Label(L10n.tabHome.resolved(), systemImage: "house.fill") }
                .accessibilityIdentifier("tab.home")
                .tag(RootTab.home)

            FavoritesView()
                .tabItem { Label(L10n.tabFavorites.resolved(), systemImage: "heart.fill") }
                .accessibilityIdentifier("tab.favorites")
                .tag(RootTab.favorites)

            SearchView()
                .tabItem { Label(L10n.tabSearch.resolved(), systemImage: "magnifyingglass") }
                .accessibilityIdentifier("tab.search")
                .tag(RootTab.search)

            SettingsView()
                .tabItem { Label(L10n.tabSettings.resolved(), systemImage: "gearshape.fill") }
                .accessibilityIdentifier("tab.settings")
                .tag(RootTab.settings)
        }
        .tint(.orange)
        .task { streak.recordOpen(context: modelContext) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { streak.recordOpen(context: modelContext) }
        }
        .onChange(of: pendingDeepLinkCategoryId) { _, newValue in
            guard let id = newValue,
                  let category = DataProvider.adharCategories.first(where: { $0.id == id })
            else { return }
            selection = .home
            // Reset any in-flight navigation so we don't stack duplicates
            // when the widget is tapped twice in a row.
            homePath = NavigationPath()
            homePath.append(category)
            pendingDeepLinkCategoryId = nil
        }
    }
}
