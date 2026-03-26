import SwiftUI
import RealityKit

struct MiniMapView: View {
    let playerPosition: SIMD3<Float>
    let roachPositions: [SIMD3<Float>]
    let cameraYaw: Float

    // MARK: - Geometry

    private let mapSize: CGFloat = 90
    private let scale: CGFloat = CGFloat(ArenaBuilder.arenaSize) / 90

    // MARK: - Radar tuning

    private static let fovDegrees: Float = 75.0
    private static let fovHalfRad: Float = fovDegrees * .pi / 180.0 / 2.0
    private static let radarRange: Float = FogSphere.outerRadius - FogSphere.bandWidth

    // MARK: - Body

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Arena border
            let borderRect = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            context.stroke(
                Path(borderRect),
                with: .color(.white.opacity(0.3)),
                lineWidth: 1
            )

            // Radar FOV cone
            drawRadarCone(context: context, mapSize: size, center: center)

            // Obstacles
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
            
            // Roach dots
            for roachPos in roachPositions {
                let pt = worldToMap(x: roachPos.x, z: roachPos.z, center: center)
                let r: CGFloat = 2.5
                let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color(red: 0.9, green: 0.2, blue: 0.2).opacity(0.85))
                )
            }

            // Player dot
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

            // Direction tick
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

        let rangeInPts = CGFloat(Self.radarRange) / scale

        let halfFov  = CGFloat(Self.fovHalfRad)
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

        let startAngle = Angle(radians: Double(atan2(leftDir.y,  leftDir.x)))
        let endAngle   = Angle(radians: Double(atan2(rightDir.y, rightDir.x)))

        var cone = Path()
        cone.move(to: playerMapPos)
        cone.addLine(to: leftPt)
        cone.addArc(
            center:     playerMapPos,
            radius:     rangeInPts,
            startAngle: startAngle,
            endAngle:   endAngle,
            clockwise:  true
        )
        cone.closeSubpath()

        context.fill(cone, with: .color(Color.green.opacity(0.12)))
        context.stroke(cone, with: .color(Color.green.opacity(0.40)), lineWidth: 0.8)
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

    private func mapDir(_ θ: CGFloat) -> CGPoint {
        CGPoint(x: sin(θ), y: cos(θ))
    }

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
