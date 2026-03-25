import RealityKit
import Foundation

class RoachAISystem: System {
    static let query = EntityQuery(where: .has(RoachComponent.self))
    
    static var isGameOver: Bool = false

    // MARK: - Separation tuning

    private static let chaserSeparationRadius:   Float = 3.0
    private static let chaserSeparationStrength: Float = 5.0

    private static let giantSeparationRadius:    Float = 8.0
    private static let giantSeparationStrength:  Float = 10.0

    private static let flyingSeparationRadius:   Float = 5.0
    private static let flyingSeparationStrength: Float = 6.0

    // MARK: - Potential field tuning

    private static let chaserRepelRadius:  Float = 1.0
    private static let giantRepelRadius:   Float = 1.0
    private static let flyingRepelRadius:  Float = 1.0

    private static let repelStrength:      Float = 12.0

    private static let wallRepelRadius:    Float = 1.0

    // MARK: - Precomputed obstacle data

    private struct ObstacleData {
        let position: SIMD3<Float>
        let halfX:    Float
        let halfZ:    Float
    }

    private var obstacleData: [ObstacleData] = []
    private var obstacleDataReady = false

    required init(scene: RealityKit.Scene) {}

    // MARK: - Update

    func update(context: SceneUpdateContext) {
        guard !Self.isGameOver else { return }
        guard let ball = context.scene.findEntity(named: "player") else { return }
        let ballPos = ball.position(relativeTo: nil)

        if !obstacleDataReady { buildObstacleCache() }

        var roachData: [(entity: Entity, position: SIMD3<Float>, component: RoachComponent)] = []
        for roach in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let comp = roach.components[RoachComponent.self] else { continue }
            roachData.append((roach, roach.position(relativeTo: nil), comp))
        }

        for (i, data) in roachData.enumerated() {
            let roach     = data.entity
            let roachPos  = data.position
            let roachComp = data.component

            // 1. Chase direction
            let toBall = ballPos - roachPos
            let distXZ = length(SIMD2<Float>(toBall.x, toBall.z))
            guard distXZ > 0.01 else { continue }
            let chaseDir = SIMD3<Float>(toBall.x / distXZ, 0, toBall.z / distXZ)

            // 2. Separation force
            let (sepRadius, sepStrength) = separationParams(for: roachComp.roachType)
            var separation = SIMD3<Float>.zero
            for (j, other) in roachData.enumerated() {
                guard i != j else { continue }
                let diff = roachPos - other.position
                let dist = length(diff)
                if dist < sepRadius && dist > 0.001 {
                    let push = (sepRadius - dist) / sepRadius
                    separation += (diff / dist) * push * sepStrength
                }
            }

            // 3. Potential-field repulsion from obstacles + walls
            let repulsion = roachComp.roachType == .flying
                ? wallRepulsion(from: roachPos)
                : obstacleRepulsion(from: roachPos, type: roachComp.roachType)
                  + wallRepulsion(from: roachPos)

            // 4. Combine — normalise chase, then add separation + repulsion
            let steeringXZ = chaseDir * roachComp.speed + separation + repulsion
            let steeringLen = length(SIMD2<Float>(steeringXZ.x, steeringXZ.z))
            let finalDir: SIMD3<Float>
            if steeringLen > 0.001 {
                let norm = SIMD3<Float>(steeringXZ.x / steeringLen,
                                        0,
                                        steeringXZ.z / steeringLen)
                finalDir = norm * roachComp.speed + SIMD3<Float>(0, 0, 0)
            } else {
                finalDir = chaseDir * roachComp.speed
            }

            // 5. Flying roach dive-bomb toward player
            var vy: Float = 0
            if roachComp.roachType == .flying {
                let diveStart: Float = 12.0
                let diveEnd:   Float = 3.0
                let t = 1.0 - simd_clamp((distXZ - diveEnd) / (diveStart - diveEnd), 0, 1)
                let targetY = simd_mix(RoachEntity.flyingHoverHeight, ballPos.y, t)
                vy = (targetY - roachPos.y) * 8.0
            }

            let combined = SIMD3<Float>(finalDir.x, vy, finalDir.z)

            if var motion = roach.components[PhysicsMotionComponent.self] {
                motion.linearVelocity = combined
                roach.components[PhysicsMotionComponent.self] = motion
            }

            // Face movement direction
            let moveDir = SIMD2<Float>(finalDir.x, finalDir.z)
            if length(moveDir) > 0.01 {
                let angle = atan2(finalDir.x, finalDir.z)
                roach.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            }
        }
    }

    // MARK: - Potential field: obstacles

    private func obstacleRepulsion(from pos: SIMD3<Float>, type: RoachComponent.RoachType) -> SIMD3<Float> {
        let repelRadius = type == .giant ? Self.giantRepelRadius : Self.chaserRepelRadius
        var force = SIMD3<Float>.zero

        for obs in obstacleData {
            let closestX = simd_clamp(pos.x, obs.position.x - obs.halfX, obs.position.x + obs.halfX)
            let closestZ = simd_clamp(pos.z, obs.position.z - obs.halfZ, obs.position.z + obs.halfZ)

            let diff = SIMD2<Float>(pos.x - closestX, pos.z - closestZ)
            let dist = length(diff)

            guard dist < repelRadius && dist > 0.001 else { continue }

            // Strength rises as roach gets closer
            let t = 1.0 - (dist / repelRadius)
            let strength = t * t * Self.repelStrength

            force += SIMD3<Float>(diff.x / dist, 0, diff.y / dist) * strength
        }
        return force
    }

    // MARK: - Potential field: arena walls

    private func wallRepulsion(from pos: SIMD3<Float>) -> SIMD3<Float> {
        let half   = ArenaBuilder.arenaSize / 2.0
        let radius = Self.wallRepelRadius
        var force  = SIMD3<Float>.zero

        let dPX = half - pos.x
        if dPX < radius && dPX > 0.001 {
            force.x -= ((radius - dPX) / radius) * Self.repelStrength
        }

        let dNX = pos.x + half
        if dNX < radius && dNX > 0.001 {
            force.x += ((radius - dNX) / radius) * Self.repelStrength
        }

        let dPZ = half - pos.z
        if dPZ < radius && dPZ > 0.001 {
            force.z -= ((radius - dPZ) / radius) * Self.repelStrength
        }
 
        let dNZ = pos.z + half
        if dNZ < radius && dNZ > 0.001 {
            force.z += ((radius - dNZ) / radius) * Self.repelStrength
        }

        return force
    }

    // MARK: - Obstacle cache

    private func buildObstacleCache() {
        obstacleData = ArenaBuilder.obstacleConfigs.enumerated().compactMap { idx, cfg in
            guard cfg.size.y > 0.15 else { return nil }
            return ObstacleData(
                position: cfg.position,
                halfX:    cfg.size.x / 2.0,
                halfZ:    cfg.size.z / 2.0
            )
        }
        obstacleDataReady = true
        print("[RoachAISystem] Built obstacle cache: \(obstacleData.count) repellers")
    }

    // MARK: - Helpers

    private func separationParams(for type: RoachComponent.RoachType) -> (Float, Float) {
        switch type {
        case .chaser:  return (Self.chaserSeparationRadius,  Self.chaserSeparationStrength)
        case .giant:   return (Self.giantSeparationRadius,   Self.giantSeparationStrength)
        case .flying:  return (Self.flyingSeparationRadius,  Self.flyingSeparationStrength)
        }
    }
}
