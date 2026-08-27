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
        #if DEBUG
        // Marketing capture: `-MarketingScreen <slug>` launch arg pre-routes
        // the UI so screenshots can be scripted without UI automation.
        let slug = UserDefaults.standard.string(forKey: "MarketingScreen")
        _initialTab = State(initialValue: slug.flatMap(RootTab.init(marketingSlug:)) ?? .home)
        _pendingDeepLinkCategoryId = State(initialValue: slug == "detail" ? "morning_adhkar" : nil)

        // Marketing flags consumed by views in their .task modifier.
        let ud = UserDefaults.standard
        ud.set(slug == "context_picker" || slug == "context_detail",
               forKey: "marketing.openContextPicker")
        ud.set(slug == "post_prayer", forKey: "marketing.openPostPrayer")
        if slug == "context_detail" {
            ud.set("anxious", forKey: "marketing.contextDetailId")
        } else {
            ud.removeObject(forKey: "marketing.contextDetailId")
        }
        ud.set(slug == "memorize_filled" || slug == "review_session",
               forKey: "marketing.preSeedHifz")
        ud.set(slug == "review_session", forKey: "marketing.launchReviewSession")
        ud.set(slug == "review_session", forKey: "marketing.autoRevealReview")
        #else
        _initialTab = State(initialValue: .home)
        _pendingDeepLinkCategoryId = State(initialValue: nil)
        #endif
    }

    @State private var initialTab: RootTab

    /// Pending category id parsed from a `munajat://category/<id>` URL.
    /// `RootTabView` observes this and pushes onto the home navigation
    /// path when set.
    @State private var pendingDeepLinkCategoryId: String?

    /// Set by a `munajat://tasbih` URL; `RootTabView` routes it to Home,
    /// which presents the guided sequence.
    @State private var pendingPostPrayerDeepLink = false

    var body: some Scene {
        WindowGroup {
            RootTabView(initialTab: initialTab,
                        pendingDeepLinkCategoryId: $pendingDeepLinkCategoryId,
                        pendingPostPrayerDeepLink: $pendingPostPrayerDeepLink)
                .environment(favorites)
                .environment(audio)
                .environment(notifications)
                .environment(streak)
                .environment(\.layoutDirection, LocalizedText.preferredLayoutDirection)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    guard url.scheme == "munajat" else { return }
                    switch url.host {
                    case "category":
                        let id = url.pathComponents.dropFirst().joined(separator: "/")
                        guard !id.isEmpty else { return }
                        pendingDeepLinkCategoryId = id
                    case "tasbih":
                        pendingPostPrayerDeepLink = true
                    default:
                        return
                    }
                }
        }
        .modelContainer(for: [DhikrProgress.self, DailyActivity.self, HifzCard.self])
    }
}
