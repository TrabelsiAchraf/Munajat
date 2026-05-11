//
//  ShareableDhikrCard.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 11/05/2026.
//

import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Transferable wrapper around a rendered `CGImage` so `ShareLink` can offer
/// it as a PNG on every platform without importing UIKit or AppKit.
struct ShareableDhikrImage: Transferable {
    let cgImage: CGImage
    let suggestedName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            let data = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(
                data,
                UTType.png.identifier as CFString,
                1,
                nil
            ) else {
                return Data()
            }
            CGImageDestinationAddImage(dest, item.cgImage, nil)
            CGImageDestinationFinalize(dest)
            return data as Data
        }
        .suggestedFileName { item in "\(item.suggestedName).png" }
    }
}

/// A standalone view designed to be rendered to an image by `ImageRenderer`
/// and shared via `ShareLink`. Fixed 1080×1920 canvas so the output is
/// crisp on social feeds and iMessage previews. Forced dark colour scheme
/// to match the app brand regardless of the host's appearance.
struct ShareableDhikrCard: View {
    let category: AdhkarCategory
    let dhikr: Adhkar

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#1A2B6E"), Color(hex: "#0F1012")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            CrescentStarPattern(intensity: 0.65, spacing: 130)

            VStack(spacing: 36) {
                Spacer(minLength: 60)

                Text(category.displayTitle)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 80)

                Text(dhikr.dhikr)
                    .font(.amiri(size: 64, bold: true))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(20)
                    .padding(.horizontal, 90)

                if let translation = dhikr.translation?.resolved(), !translation.isEmpty {
                    Text(translation)
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .padding(.horizontal, 100)
                }

                if !dhikr.source.isEmpty {
                    Text("— \(dhikr.source)")
                        .font(.system(size: 26, weight: .light).italic())
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 120)
                }

                Spacer()

                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color(hex: "#FFD66B"))
                    Text(L10n.shareCardFooter.resolved())
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.bottom, 80)
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }
}
