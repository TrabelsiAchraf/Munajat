//
//  Font+Arabic.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 08/05/2026.
//

import SwiftUI
import CoreText

/// Registers the bundled Amiri TTF files with CoreText so SwiftUI's
/// `Font.custom(...)` can find them. Cross-platform (iOS / macOS / visionOS)
/// and avoids touching `Info.plist` / `UIAppFonts`.
enum FontRegistrar {
    private static var didRegister = false

    static func registerBundledFonts() {
        guard !didRegister else { return }
        didRegister = true
        let names = ["Amiri-Regular", "Amiri-Bold", "AmiriQuran"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    /// Amiri — a Naskh-style Arabic font well-suited for body text and titles.
    /// Falls back to system Arabic font automatically if registration ever fails.
    static func amiri(size: CGFloat, bold: Bool = false) -> Font {
        Font.custom(bold ? "Amiri-Bold" : "Amiri", size: size)
    }

    /// AmiriQuran — typographic variant tuned for Quranic verses (full diacritics,
    /// special ligatures). Use specifically for ayāt, not for general body text.
    static func amiriQuran(size: CGFloat) -> Font {
        Font.custom("Amiri Quran", size: size)
    }
}
