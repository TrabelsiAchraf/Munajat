//
//  IslamicPattern.swift
//  Adhkar
//
//  Created by Achraf Trabelsi on 10/05/2026.
//

import SwiftUI

/// Tiled 8-pointed star (Khatim) pattern, drawn at any size via SwiftUI
/// Canvas — fully resolution-independent, no asset bundling required.
/// Designed to be used as a decorative overlay; opacity stays low so it
/// reads as background texture, not foreground.
struct IslamicPattern: View {
    var color: Color = .white
    var opacity: Double = 0.10
    var tileSize: CGFloat = 56
    var lineWidth: CGFloat = 1.2

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / tileSize)) + 1
            let rows = Int(ceil(size.height / tileSize)) + 1
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * tileSize
                    let y = CGFloat(row) * tileSize
                    let center = CGPoint(x: x + tileSize/2, y: y + tileSize/2)
                    let star = eightPointedStar(center: center, outer: tileSize * 0.42, inner: tileSize * 0.18)
                    context.stroke(star,
                                   with: .color(color.opacity(opacity)),
                                   lineWidth: lineWidth)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func eightPointedStar(center: CGPoint, outer: CGFloat, inner: CGFloat) -> Path {
        var path = Path()
        let points = 16  // 8 outer + 8 inner alternating
        for i in 0..<points {
            let angle = Double(i) * (.pi / 8) - .pi / 2
            let r = i.isMultiple(of: 2) ? outer : inner
            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}
