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

/// Render only when the share sheet requests the export. Rendering inside a
/// view's body recreated a 3240×5760 bitmap on every counter tap.
struct ShareableDhikrImage: Transferable {
    let category: AdhkarCategory
    let dhikr: Adhkar

    var suggestedName: String { "munajat_\(dhikr.id)" }

    enum ExportError: Error { case renderingFailed }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            try await item.pngData()
        }
        .suggestedFileName { item in "\(item.suggestedName).png" }
    }

    @MainActor
    func pngData() throws -> Data {
        let renderer = ImageRenderer(content: ShareableDhikrCard(category: category, dhikr: dhikr))
        renderer.scale = 1 // The card already specifies its 1080×1920 pixel canvas.
        guard let cgImage = renderer.cgImage else { throw ExportError.renderingFailed }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw ExportError.renderingFailed }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { throw ExportError.renderingFailed }
        return data as Data
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
