import SwiftUI
import RealityKit

/// Top-down 2D mini map.
///
/// Shows:
///   - Arena boundary (white outline)
///   - Obstacles (dark grey rectangles)
///   - Player position (white dot)
///
/// Intentionally does NOT show:
///   - Mystery bag positions (player must hunt manually)
///   - Roach positions (no radar — only spatial audio warns you)
struct MiniMapView: View {
    let playerPosition: SIMD3<Float>

    /// Size of the map widget in points
    private let mapSize: CGFloat = 90
    /// How many RealityKit meters one map point represents
    private let scale: CGFloat = CGFloat(ArenaBuilder.arenaSize) / 90

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // ── Arena border ─────────────────────────────────────────────────
            let borderRect = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            context.stroke(
                Path(borderRect),
                with: .color(.white.opacity(0.3)),
                lineWidth: 1
            )

            // ── Obstacles ────────────────────────────────────────────────────
            // Read directly from ArenaBuilder so there's only one source of truth
            for config in ArenaBuilder.obstacleConfigs {
                let rect = worldRectToMap(
                    x: config.position.x,
                    z: config.position.z,
                    w: config.size.x,
                    d: config.size.z,
                    center: center
                )
                context.fill(Path(rect), with: .color(.white.opacity(0.18)))
            }

            // ── Player dot ───────────────────────────────────────────────────
            let playerMapPos = worldToMap(
                x: playerPosition.x,
                z: playerPosition.z,
                center: center
            )
            let dotRadius: CGFloat = 3.0
            let dotRect = CGRect(
                x: playerMapPos.x - dotRadius,
                y: playerMapPos.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(.white))
        }
        .frame(width: mapSize, height: mapSize)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Coordinate helpers

    private func worldToMap(x: Float, z: Float, center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(x) / scale,
            y: center.y + CGFloat(z) / scale
        )
    }

    private func worldRectToMap(
        x: Float, z: Float,
        w: Float, d: Float,
        center: CGPoint
    ) -> CGRect {
        let origin = worldToMap(x: x - w / 2, z: z - d / 2, center: center)
        return CGRect(
            x: origin.x,
            y: origin.y,
            width:  CGFloat(w) / scale,
            height: CGFloat(d) / scale
        )
    }
}
