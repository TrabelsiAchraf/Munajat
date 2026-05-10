//
//  CrescentStarPattern.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 10/05/2026.
//

import SwiftUI

/// Scattered pattern of small Islamic crescents and 5-point stars in a
/// metallic-gold treatment with a soft halo (mimics manuscript illumination).
/// Positions are deterministic (hash of grid cell) so the layout stays stable
/// across redraws and screen sizes.
struct CrescentStarPattern: View {
    /// Overall intensity of the pattern. The gradient & halo opacities are
    /// derived from this so a single knob controls how loud it reads.
    var intensity: Double = 0.55
    /// Spacing between glyph cells — bigger = sparser pattern.
    var spacing: CGFloat = 90

    private let highlightGold = Color(hex: "#FFE9A6")
    private let primaryGold   = Color(hex: "#D4A857")
    private let deepGold      = Color(hex: "#8C6A2C")
    private let glowGold      = Color(hex: "#FFD66B")

    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            for row in 0..<rows {
                for col in 0..<cols {
                    let h = hash(col, row)
                    let dx = CGFloat((h & 0xFF)) / 255.0 * 40 - 20
                    let dy = CGFloat((h >> 8) & 0xFF) / 255.0 * 40 - 20
                    let center = CGPoint(
                        x: CGFloat(col) * spacing + dx,
                        y: CGFloat(row) * spacing + dy
                    )
                    let isCrescent = (h % 4) == 0
                    let scale = 0.65 + CGFloat((h >> 16) & 0x7F) / 127.0 * 0.55

                    let path = isCrescent
                        ? crescent(at: center, size: 14 * scale)
                        : star(at: center, size: 8 * scale)
                    drawShinyGold(path, in: &context)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Two-layer render: blurred halo behind, gradient gold fill on top.
    private func drawShinyGold(_ path: Path, in context: inout GraphicsContext) {
        // Soft halo behind for the "shine"
        context.drawLayer { ctx in
            ctx.addFilter(.blur(radius: 3))
            ctx.fill(path, with: .color(glowGold.opacity(intensity * 0.55)))
        }

        // Metallic gradient fill on top
        let box = path.boundingRect
        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    highlightGold.opacity(intensity * 1.10),
                    primaryGold.opacity(intensity),
                    deepGold.opacity(intensity * 0.85)
                ]),
                startPoint: CGPoint(x: box.minX, y: box.minY),
                endPoint:   CGPoint(x: box.maxX, y: box.maxY)
            )
        )
    }

    private func hash(_ a: Int, _ b: Int) -> Int {
        var h = (a &* 73856093) ^ (b &* 19349663)
        h ^= h >> 13
        h = h &* 1274126177
        return abs(h)
    }

    /// 5-point star centred on `center` with outer radius `size`.
    private func star(at center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        let outer = Double(size)
        let inner = outer * 0.42
        for i in 0..<10 {
            let angle = Double(i) * (.pi / 5) - .pi / 2
            let r = i.isMultiple(of: 2) ? outer : inner
            let p = CGPoint(
                x: center.x + CGFloat(Foundation.cos(angle) * r),
                y: center.y + CGFloat(Foundation.sin(angle) * r)
            )
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    /// Proper Islamic crescent (waxing moon, opening to the right). Built by
    /// boolean-subtracting an offset inner disk from the outer disk via
    /// SwiftUI Path operations.
    private func crescent(at center: CGPoint, size: CGFloat) -> Path {
        let outerR = size
        let outer = Path(ellipseIn: CGRect(
            x: center.x - outerR, y: center.y - outerR,
            width: outerR * 2, height: outerR * 2
        ))

        let innerR = size * 0.85
        let offset = size * 0.30
        let inner = Path(ellipseIn: CGRect(
            x: center.x + offset - innerR, y: center.y - innerR,
            width: innerR * 2, height: innerR * 2
        ))

        return outer.subtracting(inner)
    }
}
