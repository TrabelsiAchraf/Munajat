//
//  AdhkarButtonCardStyle.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 18/04/2025.
//

import SwiftUI

struct AdhkarButtonCardStyle: ButtonStyle {
    let adhkarType: AdhkarType
    let categoryId: String
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                FavoriteButton(categoryId: categoryId)
            }

            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 58, height: 58)
                adhkarType.image
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(accent)
            }

            configuration.label
                .font(.amiri(size: 17))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 185)
        .foregroundStyle(.primary)
        .padding(14)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(accent.opacity(0.22), lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 20))
        .shadow(color: accent.opacity(0.10), radius: 10, x: 0, y: 4)
        .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
        .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    @ViewBuilder
    private var cardBackground: some View {
        ZStack {
            Color.cardBackground
            LinearGradient(
                colors: [accent.opacity(0.10), accent.opacity(0.0)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }
}

private struct FavoriteButton: View {
    let categoryId: String
    @Environment(FavoritesStore.self) private var favorites

    var body: some View {
        Button {
            favorites.toggle(categoryId)
        } label: {
            Image(systemName: favorites.contains(categoryId) ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(favorites.contains(categoryId) ? .red : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: favorites.contains(categoryId))
    }
}

extension ButtonStyle where Self == AdhkarButtonCardStyle {
    static func adhkarCardStyle(
        adhkarType: AdhkarType,
        categoryId: String,
        accent: Color
    ) -> AdhkarButtonCardStyle {
        .init(adhkarType: adhkarType, categoryId: categoryId, accent: accent)
    }
}
