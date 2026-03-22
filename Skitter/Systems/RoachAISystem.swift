import RealityKit
import Foundation

/// ECS System — chases the player every frame with separation steering
/// + potential-field obstacle avoidance.
///
/// Avoidance strategy (Option C — Potential Fields):
///   Each obstacle and arena wall acts as a repulsion source.
///   Every frame we sum repulsion vectors from nearby sources and blend
///   them into the chase direction. No raycasts needed — O(roaches × obstacles).
///
/// Flying roaches skip floor-level obstacle avoidance (they hover over them)
/// but still respect boundary walls.
class RoachAISystem: System {
    static let query = EntityQuery(where: .has(RoachComponent.self))

    // MARK: - Separation tuning

    private static let chaserSeparationRadius:   Float = 3.0
    private static let chaserSeparationStrength: Float = 5.0

    private static let giantSeparationRadius:    Float = 8.0
    private static let giantSeparationStrength:  Float = 10.0

    private static let flyingSeparationRadius:   Float = 5.0
    private static let flyingSeparationStrength: Float = 6.0

    // MARK: - Potential field tuning

    /// How far (meters) an obstacle starts repelling a roach.
    /// Giant roaches use a larger radius to account for their bigger body.
    private static let chaserRepelRadius:  Float = 5.0
    private static let giantRepelRadius:   Float = 7.0
    private static let flyingRepelRadius:  Float = 5.0  // only walls, not floor obstacles

    /// Scalar multiplier on the repulsion vector before blending.
    private static let repelStrength:      Float = 12.0

    /// Arena wall repulsion starts this many meters from each wall.
    private static let wallRepelRadius:    Float = 4.0

    // MARK: - Precomputed obstacle data

    /// XZ positions + half-extents of every solid obstacle, built once.
    /// We use a struct instead of raw tuples for clarity.
    private struct ObstacleData {
        let position: SIMD3<Float>   // world XZ centre (Y = 0 for comparison)
        let halfX:    Float          // half-width
        let halfZ:    Float          // half-depth
    }

    /// Lazily populated on first update — avoids init-time ordering issues.
    private var obstacleData: [ObstacleData] = []
    private var obstacleDataReady = false

    required init(scene: RealityKit.Scene) {}

    // MARK: - Update

    func update(context: SceneUpdateContext) {
        guard let ball = context.scene.findEntity(named: "player") else { return }
        let ballPos = ball.position(relativeTo: nil)

        // Build obstacle cache once
        if !obstacleDataReady { buildObstacleCache() }

        // Snapshot roach positions for separation
        var roachData: [(entity: Entity, position: SIMD3<Float>, component: RoachComponent)] = []
        for roach in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let comp = roach.components[RoachComponent.self] else { continue }
            roachData.append((roach, roach.position(relativeTo: nil), comp))
        }

        for (i, data) in roachData.enumerated() {
            let roach     = data.entity
            let roachPos  = data.position
            let roachComp = data.component

            // 1. Chase direction (XZ only)
            let toBall = ballPos - roachPos
            let distXZ = length(SIMD2<Float>(toBall.x, toBall.z))
            guard distXZ > 0.01 else { continue }
            let chaseDir = SIMD3<Float>(toBall.x / distXZ, 0, toBall.z / distXZ)

            // 2. Separation force (XZ)
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
            //    Flying roaches only repel from walls — they hover over floor obstacles.
            let repulsion = roachComp.roachType == .flying
                ? wallRepulsion(from: roachPos)
                : obstacleRepulsion(from: roachPos, type: roachComp.roachType)
                  + wallRepulsion(from: roachPos)

            // 4. Combine — normalise chase, then add separation + repulsion
            //    We keep the speed scalar from roachComp.speed separate so
            //    avoidance doesn't accidentally slow the roach down.
            let steeringXZ = chaseDir * roachComp.speed + separation + repulsion
            let steeringLen = length(SIMD2<Float>(steeringXZ.x, steeringXZ.z))
            let finalDir: SIMD3<Float>
            if steeringLen > 0.001 {
                // Re-normalise then re-scale to roach speed so we don't speed-boost
                let norm = SIMD3<Float>(steeringXZ.x / steeringLen,
                                        0,
                                        steeringXZ.z / steeringLen)
                finalDir = norm * roachComp.speed + SIMD3<Float>(0, 0, 0)
            } else {
                finalDir = chaseDir * roachComp.speed
            }

            // 5. Flying Y — hover / dive-bomb toward player
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
            // Closest point on obstacle AABB to the roach (XZ plane)
            let closestX = simd_clamp(pos.x, obs.position.x - obs.halfX, obs.position.x + obs.halfX)
            let closestZ = simd_clamp(pos.z, obs.position.z - obs.halfZ, obs.position.z + obs.halfZ)

            let diff = SIMD2<Float>(pos.x - closestX, pos.z - closestZ)
            let dist = length(diff)

            guard dist < repelRadius && dist > 0.001 else { continue }

            // Strength rises as roach gets closer (inverse-square-ish feel)
            let t = 1.0 - (dist / repelRadius)          // 0 at edge, 1 at surface
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

        // +X wall
        let dPX = half - pos.x
        if dPX < radius && dPX > 0.001 {
            force.x -= ((radius - dPX) / radius) * Self.repelStrength
        }
        // -X wall
        let dNX = pos.x + half
        if dNX < radius && dNX > 0.001 {
            force.x += ((radius - dNX) / radius) * Self.repelStrength
        }
        // +Z wall
        let dPZ = half - pos.z
        if dPZ < radius && dPZ > 0.001 {
            force.z -= ((radius - dPZ) / radius) * Self.repelStrength
        }
        // -Z wall
        let dNZ = pos.z + half
        if dNZ < radius && dNZ > 0.001 {
            force.z += ((radius - dNZ) / radius) * Self.repelStrength
        }

        return force
    }

    // MARK: - Obstacle cache

    /// Build from ArenaBuilder.obstacleConfigs once — only solid obstacles.
    private func buildObstacleCache() {
        obstacleData = ArenaBuilder.obstacleConfigs.enumerated().compactMap { idx, cfg in
            // Skip oil puddle (index 6) — it's a trigger, not a blocker
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
