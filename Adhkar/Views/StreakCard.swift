//
//  StreakCard.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 11/05/2026.
//

import SwiftUI

/// Compact streak card displayed at the top of the home screen below the
/// hero verse. Shows the running streak with a flame, and the best record
/// as a secondary line. When no streak is active, gently invites the user
/// to start one today.
struct StreakCard: View {
    @Environment(StreakService.self) private var streak

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(flameGradient)
                    .frame(width: 52, height: 52)
                Image(systemName: streak.currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                if streak.currentStreak > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(streak.currentStreak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                        Text(L10n.streakDays.resolved())
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    if streak.bestStreak > streak.currentStreak {
                        Text("\(L10n.streakBest.resolved()) · \(streak.bestStreak)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(L10n.streakTitle.resolved())
                        .font(.subheadline.weight(.semibold))
                    Text(L10n.streakStartToday.resolved())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var flameGradient: LinearGradient {
        LinearGradient(
            colors: streak.currentStreak > 0
                ? [Color(hex: "#FF7A00"), Color(hex: "#FFB347")]
                : [Color.secondary.opacity(0.35), Color.secondary.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accessibilityLabel: String {
        if streak.currentStreak > 0 {
            let days = streak.currentStreak
            let best = streak.bestStreak
            return "\(L10n.streakTitle.resolved()), \(days) \(L10n.streakDays.resolved()). \(L10n.streakBest.resolved()) \(best)."
        }
        return "\(L10n.streakTitle.resolved()). \(L10n.streakStartToday.resolved())"
    }
}
