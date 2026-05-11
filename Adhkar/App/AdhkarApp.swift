//
//  AdhkarApp.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 17/04/2025.
//

import SwiftUI
import SwiftData

@main
struct AdhkarApp: App {
    @State private var favorites = FavoritesStore()
    @State private var audio = AudioPlayer()
    @State private var notifications = NotificationManager()
    @State private var streak = StreakService()

    init() {
        FontRegistrar.registerBundledFonts()
    }

    /// Pending category id parsed from a `munajat://category/<id>` URL.
    /// `RootTabView` observes this and pushes onto the home navigation
    /// path when set.
    @State private var pendingDeepLinkCategoryId: String?

    var body: some Scene {
        WindowGroup {
            RootTabView(pendingDeepLinkCategoryId: $pendingDeepLinkCategoryId)
                .environment(favorites)
                .environment(audio)
                .environment(notifications)
                .environment(streak)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    guard url.scheme == "munajat", url.host == "category" else { return }
                    let id = url.pathComponents.dropFirst().joined(separator: "/")
                    guard !id.isEmpty else { return }
                    pendingDeepLinkCategoryId = id
                }
        }
        .modelContainer(for: [DhikrProgress.self, DailyActivity.self])
    }
}
