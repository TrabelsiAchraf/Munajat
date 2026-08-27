//
//  RootTabView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import SwiftUI
import SwiftData

enum RootTab: Hashable {
    case home, favorites, search, memorize, settings

    #if DEBUG
    init?(marketingSlug: String) {
        switch marketingSlug {
        case "home", "detail", "context_picker", "context_detail": self = .home
        case "favorites":                                            self = .favorites
        case "memorize", "memorize_filled", "review_session":        self = .memorize
        case "settings":                                             self = .settings
        default: return nil
        }
    }
    #endif
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakService.self) private var streak
    @Environment(\.scenePhase) private var scenePhase

    /// Initial selected tab. Defaults to `.home`; overridden via debug
    /// launch args during marketing screenshot capture.
    let initialTab: RootTab

    /// Bound to `AdhkarApp.pendingDeepLinkCategoryId`. When set, we switch
    /// to the home tab and push the matching `AdhkarCategory` onto its
    /// navigation path, then clear the binding.
    @Binding var pendingDeepLinkCategoryId: String?

    /// Bound to `AdhkarApp.pendingPostPrayerDeepLink`. Handed straight to
    /// `HomeView`, which presents the guided sequence; SwiftUI clears it when
    /// the cover is dismissed.
    @Binding var pendingPostPrayerDeepLink: Bool

    @State private var selection: RootTab
    @State private var homePath = NavigationPath()

    init(initialTab: RootTab = .home,
         pendingDeepLinkCategoryId: Binding<String?>,
         pendingPostPrayerDeepLink: Binding<Bool>) {
        self.initialTab = initialTab
        self._pendingDeepLinkCategoryId = pendingDeepLinkCategoryId
        self._pendingPostPrayerDeepLink = pendingPostPrayerDeepLink
        self._selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(path: $homePath, presentPostPrayer: $pendingPostPrayerDeepLink)
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

            MemoTabView()
                .tabItem { Label(L10n.tabMemorize.resolved(), systemImage: "brain.head.profile") }
                .accessibilityIdentifier("tab.memorize")
                .tag(RootTab.memorize)

            SettingsView()
                .tabItem { Label(L10n.tabSettings.resolved(), systemImage: "gearshape.fill") }
                .accessibilityIdentifier("tab.settings")
                .tag(RootTab.settings)
        }
        .tint(.orange)
        .task {
            streak.recordOpen(context: modelContext)
            // Handle an initial pending category id (set by AdhkarApp.init via
            // the marketing launch arg). onChange only fires on transitions, so
            // we also route once on first appearance.
            routePendingDeepLink()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { streak.recordOpen(context: modelContext) }
        }
        .onChange(of: pendingDeepLinkCategoryId) { _, _ in routePendingDeepLink() }
        .onChange(of: pendingPostPrayerDeepLink) { _, pending in
            guard pending else { return }
            selection = .home
        }
    }

    private func routePendingDeepLink() {
        guard let id = pendingDeepLinkCategoryId,
              let category = DataProvider.adharCategories.first(where: { $0.id == id })
        else { return }
        selection = .home
        // Reset any in-flight navigation so we don't stack duplicates when the
        // widget is tapped twice in a row.
        homePath = NavigationPath()
        homePath.append(category)
        pendingDeepLinkCategoryId = nil
    }
}
