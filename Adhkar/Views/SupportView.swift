//
//  SupportView.swift
//  Adhkar
//
//  In-app support / FAQ. Bundled content so the link in Settings works offline
//  and without depending on a hosted page.
//

import SwiftUI

struct SupportView: View {
    var body: some View {
        ZStack {
            AdaptiveBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    faq
                    contentNote
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(L10n.support.resolved())
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var intro: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.supportHeaderTitle.resolved())
                    .font(.headline)
                Text(L10n.supportHeaderBody.resolved())
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var faq: some View {
        VStack(alignment: .leading, spacing: 12) {
            FAQRow(question: L10n.supportFaqAudioQ.resolved(),
                   answer: L10n.supportFaqAudioA.resolved())
            FAQRow(question: L10n.supportFaqNotifsQ.resolved(),
                   answer: L10n.supportFaqNotifsA.resolved())
            FAQRow(question: L10n.supportFaqCountersQ.resolved(),
                   answer: L10n.supportFaqCountersA.resolved())
            FAQRow(question: L10n.supportFaqStreakQ.resolved(),
                   answer: L10n.supportFaqStreakA.resolved())
        }
    }

    private var contentNote: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(L10n.supportContentTitle.resolved())
                        .font(.headline)
                } icon: {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(.orange)
                }
                Text(L10n.supportContentBody.resolved())
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private struct Card<Content: View>: View {
        @ViewBuilder var content: Content

        var body: some View {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private struct FAQRow: View {
        let question: String
        let answer: String
        @State private var expanded = false

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(question)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    Text(answer)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
