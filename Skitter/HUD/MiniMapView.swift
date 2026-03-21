import SwiftUI
import RealityKit

/// Top-down 2D mini map.
///
/// Shows:
///   - Arena boundary (white outline)
///   - Obstacles (dark grey rectangles)
///   - Player position (white dot)
///   - Radar FOV cone: 75° triangle in the camera direction, range shrinks with fog
///
/// Intentionally does NOT show:
///   - Mystery bag positions (player must hunt manually)
///   - Roach positions (no radar — only spatial audio warns you)
struct MiniMapView: View {
    let playerPosition: SIMD3<Float>

    /// Camera yaw in radians (from MotionController.cameraYaw).
    /// At yaw = π the player faces -Z which is "up" on the minimap.
    let cameraYaw: Float

    /// Number of bait bags triggered — shrinks the radar range.
    let baitCount: Int

    // MARK: - Geometry

    /// Size of the map widget in points
    private let mapSize: CGFloat = 90
    /// How many RealityKit meters one map point represents
    private let scale: CGFloat = CGFloat(ArenaBuilder.arenaSize) / 90

    // MARK: - Radar tuning

    /// Camera FOV — must match the PerspectiveCamera.fieldOfViewInDegrees in GameView.
    private static let fovDegrees: Float = 75.0
    private static let fovHalfRad: Float = fovDegrees * .pi / 180.0 / 2.0

    /// Maximum radar sight distance in RealityKit meters (matches FogSphere.outerRadius).
    private static let maxRadarRange: Float = FogSphere.outerRadius    // 28 m

    /// Visibility fraction at each bait level (index 0 = 0 bait, … index 4 = 4 bait).
    private static let fogFactors: [Float] = [1.0, 0.72, 0.50, 0.33, 0.20]

    // MARK: - Body

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

            // ── Radar FOV cone ────────────────────────────────────────────────
            drawRadarCone(context: context, mapSize: size, center: center)

            // ── Obstacles ────────────────────────────────────────────────────
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

            // ── Direction tick (short line from player dot toward yaw) ────────
            drawDirectionTick(context: context, playerPos: playerMapPos)
        }
        .frame(width: mapSize, height: mapSize)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Radar cone

    private func drawRadarCone(
        context: GraphicsContext,
        mapSize: CGSize,
        center: CGPoint
    ) {
        let playerMapPos = worldToMap(
            x: playerPosition.x,
            z: playerPosition.z,
            center: center
        )

        // Compute fog-scaled radar range in map points
        let fogIdx     = min(baitCount, Self.fogFactors.count - 1)
        let fogFactor  = CGFloat(Self.fogFactors[fogIdx])
        let radarMeters = CGFloat(Self.maxRadarRange) * fogFactor
        let rangeInPts  = radarMeters / scale

        let halfFov = CGFloat(Self.fovHalfRad)
        let leftYaw  = CGFloat(cameraYaw) - halfFov
        let rightYaw = CGFloat(cameraYaw) + halfFov

        // Map-space direction: world +X → map right, world +Z → map down.
        // A unit vector in direction θ is (sin(θ), cos(θ)) in world/map space.
        func mapDir(_ θ: CGFloat) -> CGPoint {
            CGPoint(x: sin(θ), y: cos(θ))
        }

        let leftDir  = mapDir(CGFloat(cameraYaw) + .pi - halfFov)
        let rightDir = mapDir(CGFloat(cameraYaw) + .pi + halfFov)

        let leftPt  = CGPoint(
            x: playerMapPos.x + leftDir.x  * rangeInPts,
            y: playerMapPos.y + leftDir.y  * rangeInPts
        )
        let rightPt = CGPoint(
            x: playerMapPos.x + rightDir.x * rangeInPts,
            y: playerMapPos.y + rightDir.y * rangeInPts
        )

        // Arc angles in CGContext space: atan2(dy, dx) for each edge direction.
        let startAngle = Angle(radians: Double(atan2(leftDir.y,  leftDir.x)))
        let endAngle   = Angle(radians: Double(atan2(rightDir.y, rightDir.x)))

        // Build pie-slice path: player → left edge → arc → player
        var cone = Path()
        cone.move(to: playerMapPos)
        cone.addLine(to: leftPt)
        // clockwise: false = counterclockwise in screen space (Y-down),
        // which sweeps the short 75° arc from left edge through center to right edge.
        cone.addArc(
            center:     playerMapPos,
            radius:     rangeInPts,
            startAngle: startAngle,
            endAngle:   endAngle,
            clockwise:  true
        )
        cone.closeSubpath()

        // Filled cone — opacity drops as fog thickens
        let fillOpacity = 0.08 + 0.10 * (1.0 - Double(baitCount) / 4.0)
        context.fill(cone, with: .color(Color.green.opacity(fillOpacity)))

        // Cone outline — edges and arc
        context.stroke(
            cone,
            with: .color(Color.green.opacity(0.35 * Double(fogFactor) + 0.10)),
            lineWidth: 0.8
        )
    }

    // MARK: - Direction tick

    private func drawDirectionTick(context: GraphicsContext, playerPos: CGPoint) {
        let tickLen: CGFloat = 6
        let θ = CGFloat(cameraYaw) + .pi
        let tip = CGPoint(
            x: playerPos.x + sin(θ) * tickLen,
            y: playerPos.y + cos(θ) * tickLen
        )
        var tick = Path()
        tick.move(to: playerPos)
        tick.addLine(to: tip)
        context.stroke(tick, with: .color(.white.opacity(0.7)), lineWidth: 1.2)
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
