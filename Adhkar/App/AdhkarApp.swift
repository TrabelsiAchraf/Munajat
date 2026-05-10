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

    init() {
        FontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(favorites)
                .environment(audio)
                .environment(notifications)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: DhikrProgress.self)
    }
}
