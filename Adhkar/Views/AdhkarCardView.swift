//
//  AdhkarCardView.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 07/05/2026.
//

import SwiftUI

struct AdhkarCardView: View {
    let category: AdhkarCategory

    var body: some View {
        NavigationLink(value: category) {
            Text(category.displayTitle)
        }
        .buttonStyle(
            .adhkarCardStyle(
                adhkarType: category.type,
                categoryId: category.id,
                accent: (category.section ?? .other).accentColor
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(category.displayTitle)
        .accessibilityHint(L10n.a11yCategoryCardHint.resolved())
        .accessibilityAddTraits(.isButton)
    }
}
