import RealityKit
import Foundation

/// ECS System — chases the player every frame with separation steering.
/// Flying roaches also maintain their hover height via Y velocity correction.
class RoachAISystem: System {
    static let query = EntityQuery(where: .has(RoachComponent.self))

    // MARK: - Tunable separation per roach type

    /// Chaser — small, swarm-like, packs tightly
    private static let chaserSeparationRadius:   Float = 3.0
    private static let chaserSeparationStrength: Float = 5.0

    /// Giant — large body, needs more personal space
    private static let giantSeparationRadius:    Float = 8.0
    private static let giantSeparationStrength:  Float = 10.0

    /// Flying — airborne, moderate separation to avoid stacking
    private static let flyingSeparationRadius:   Float = 5.0
    private static let flyingSeparationStrength: Float = 6.0

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        guard let ball = context.scene.findEntity(named: "player") else { return }
        let ballPos = ball.position(relativeTo: nil)

        // Snapshot all roach positions first for separation calculation
        var roachData: [(entity: Entity, position: SIMD3<Float>, component: RoachComponent)] = []

        for roach in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let comp = roach.components[RoachComponent.self] else { continue }
            roachData.append((roach, roach.position(relativeTo: nil), comp))
        }

        for (i, data) in roachData.enumerated() {
            let roach     = data.entity
            let roachPos  = data.position
            let roachComp = data.component

            // 1. Chase direction (XZ only — Y handled separately)
            let toBall = ballPos - roachPos
            let distXZ = length(SIMD2<Float>(toBall.x, toBall.z))
            guard distXZ > 0.01 else { continue }
            let chaseDir = SIMD3<Float>(toBall.x / distXZ, 0, toBall.z / distXZ)

            // 2. Separation force (XZ only) — radius/strength vary by roach type
            let sepRadius: Float
            let sepStrength: Float
            switch roachComp.roachType {
            case .chaser:  sepRadius = Self.chaserSeparationRadius;  sepStrength = Self.chaserSeparationStrength
            case .giant:   sepRadius = Self.giantSeparationRadius;   sepStrength = Self.giantSeparationStrength
            case .flying:  sepRadius = Self.flyingSeparationRadius;  sepStrength = Self.flyingSeparationStrength
            }

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

            // 3. Combine XZ velocity
            var vx = chaseDir.x * roachComp.speed + separation.x
            var vz = chaseDir.z * roachComp.speed + separation.z
            var vy: Float = 0

            // 4. Flying roaches: hover at flyingHoverHeight when far,
            // dive toward player Y when close — creating a dive-bomb effect.
            // diveStart = XZ distance at which diving begins
            // diveEnd   = XZ distance at which fully at player level
            if roachComp.roachType == .flying {
                let diveStart: Float = 12.0
                let diveEnd:   Float = 3.0
                let t         = 1.0 - simd_clamp((distXZ - diveEnd) / (diveStart - diveEnd), 0, 1)
                let targetY   = simd_mix(RoachEntity.flyingHoverHeight, ballPos.y, t)
                let yError    = targetY - roachPos.y
                vy = yError * 8.0
            }

            let combined = SIMD3<Float>(vx, vy, vz)

            if var motion = roach.components[PhysicsMotionComponent.self] {
                motion.linearVelocity = combined
                roach.components[PhysicsMotionComponent.self] = motion
            }

            // Face movement direction
            let moveDir = SIMD2<Float>(vx, vz)
            if length(moveDir) > 0.01 {
                let angle = atan2(vx, vz)
                roach.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            }
        }
    }
}
