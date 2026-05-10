//
//  BackgroundView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 19/04/2025.
//

import SwiftUI

/// Adaptive gradient background. Optional decorative scatter of golden
/// crescents and stars on top — used on the home screen and dhikr detail
/// pages to evoke an illuminated-manuscript feel.
struct AdaptiveBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var decorated: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if decorated {
                CrescentStarPattern(intensity: patternIntensity, spacing: 95)
            }
        }
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        switch colorScheme {
        case .dark:    return [Color(hex: "#1A2B6E"), Color(hex: "#0F1012")]
        default:       return [Color(hex: "#E8EDFB"), Color(hex: "#F7F5F0")]
        }
    }

    /// Gold reads stronger on a dark gradient than on the light pastel one,
    /// so we crank intensity up a bit in dark mode.
    private var patternIntensity: Double {
        switch colorScheme {
        case .dark:    return 0.65
        default:       return 0.40
        }
    }
}

/// Backwards-compatible free-standing helper used by existing detail views.
@ViewBuilder var backgroundGradient: some View {
    AdaptiveBackground(decorated: true)
}
