//
//  FavoritesStore.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import Foundation
import Observation

/// Persistent store of favorite category ids. Backed by UserDefaults.
/// Replaces the per-key `@AppStorage("favorite_<id>")` pattern from Phase 1
/// so the favorites tab can reactively reflect changes.
@Observable
final class FavoritesStore {
    private static let storageKey = "favoriteCategoryIds"

    private(set) var ids: Set<String>

    init(defaults: UserDefaults = .standard) {
        let stored = defaults.stringArray(forKey: Self.storageKey) ?? []
        ids = Set(stored)
        self.defaults = defaults
        migrateLegacyKeys()
    }

    private let defaults: UserDefaults

    func contains(_ id: String) -> Bool { ids.contains(id) }

    func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        persist()
    }

    private func persist() {
        defaults.set(Array(ids), forKey: Self.storageKey)
    }

    /// Migrate any leftover `favorite_<id>` Bool keys from Phase 1 into the new Set.
    private func migrateLegacyKeys() {
        let dict = defaults.dictionaryRepresentation()
        var migrated = false
        for (key, value) in dict where key.hasPrefix("favorite_") {
            if let isFav = value as? Bool, isFav {
                let id = String(key.dropFirst("favorite_".count))
                if !ids.contains(id) {
                    ids.insert(id)
                    migrated = true
                }
            }
            defaults.removeObject(forKey: key)
        }
        if migrated { persist() }
    }
}
