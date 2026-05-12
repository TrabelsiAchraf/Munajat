//
//  LocalizedText.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import Foundation
import SwiftUI

/// A piece of text available in one or more languages (Arabic, French, English).
/// Falls back gracefully when the requested language is missing.
struct LocalizedText: Codable, Hashable, Equatable {
    var ar: String?
    var fr: String?
    var en: String?

    init(ar: String? = nil, fr: String? = nil, en: String? = nil) {
        self.ar = ar
        self.fr = fr
        self.en = en
    }

    func resolved(for locale: Locale = .current) -> String {
        let lang = Self.preferredLanguageCode(fallback: locale)
        switch lang {
        case "fr": return fr ?? en ?? ar ?? ""
        case "en": return en ?? fr ?? ar ?? ""
        default:   return ar ?? en ?? fr ?? ""
        }
    }

    /// Reads the user's chosen language for this app (`AppleLanguages` user
    /// default — set by iOS Settings → App language, or by launch arg). Falls
    /// back to the device locale if no per-app preference is set.
    static func preferredLanguageCode(fallback: Locale = .current) -> String {
        if let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           let first = langs.first {
            return String(first.split(separator: "-").first ?? Substring(first))
        }
        return fallback.language.languageCode?.identifier ?? "ar"
    }

    /// Layout direction implied by the currently selected app language.
    /// Arabic flips the whole UI to right-to-left; everything else stays LTR.
    static var preferredLayoutDirection: LayoutDirection {
        preferredLanguageCode() == "ar" ? .rightToLeft : .leftToRight
    }
}
