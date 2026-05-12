//
//  PrivacyPolicyView.swift
//  Adhkar
//
//  In-app privacy policy. Content is bundled (no hosted page) so the screen
//  works offline and survives App Store review without an external dependency.
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ZStack {
            AdaptiveBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Block(title: L10n.privacyIntroTitle.resolved(),
                          text: L10n.privacyIntroBody.resolved())
                    Block(title: L10n.privacyDataStoredTitle.resolved(),
                          text: L10n.privacyDataStoredBody.resolved())
                    Block(title: L10n.privacyNetworkTitle.resolved(),
                          text: L10n.privacyNetworkBody.resolved())
                    Block(title: L10n.privacyNotifsTitle.resolved(),
                          text: L10n.privacyNotifsBody.resolved())
                    Block(title: L10n.privacyContactTitle.resolved(),
                          text: L10n.privacyContactBody.resolved())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(L10n.privacyPolicy.resolved())
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private struct Block: View {
        let title: String
        let text: String

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
