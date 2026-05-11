//
//  HeroHeader.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 10/05/2026.
//

import SwiftUI

/// Decorative hero card shown at the top of the home screen. Combines a
/// gradient backdrop, a tiled Islamic geometric pattern, and a Quranic
/// verse (33:41 — "remember Allah often") rendered in the AmiriQuran font
/// which is tuned for Quranic text with full diacritics.
struct HeroHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            IslamicPattern(color: .white, opacity: 0.13, tileSize: 56)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("وَٱذْكُرُوا۟ ٱللَّهَ كَثِيرًا")
                    .font(.amiriQuran(size: 30))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, 12)

                Text(L10n.heroVerseTranslation.resolved())
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 170)
        .clipShape(.rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var gradient: [Color] {
        switch colorScheme {
        case .dark:
            return [Color(hex: "#2A3F8F"), Color(hex: "#0F1740")]
        default:
            return [Color(hex: "#3B5BDB"), Color(hex: "#1E3CA8")]
        }
    }
}
