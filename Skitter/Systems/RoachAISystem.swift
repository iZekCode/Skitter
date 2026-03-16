import RealityKit
import Foundation

/// ECS System that makes roaches chase the ball every frame
/// Includes separation steering so roaches don't stack on each other
class RoachAISystem: System {
    static let query = EntityQuery(where: .has(RoachComponent.self))

    /// Minimum distance before roaches push apart
    private static let separationRadius: Float = 1.2
    /// How strongly roaches repel each other (higher = stronger push)
    private static let separationStrength: Float = 3.0

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        // Find the ball
        guard let ball = context.scene.findEntity(named: "ball") else { return }
        let ballPos = ball.position(relativeTo: nil)

        // Collect all roach positions first for separation calculation
        var roachData: [(entity: Entity, position: SIMD3<Float>, component: RoachComponent)] = []
        for roach in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let comp = roach.components[RoachComponent.self] else { continue }
            roachData.append((roach, roach.position(relativeTo: nil), comp))
        }

        for (i, data) in roachData.enumerated() {
            let roach = data.entity
            let roachPos = data.position
            let roachComp = data.component

            // 1. Chase direction toward ball
            let toBall = ballPos - roachPos
            let distToBall = length(toBall)
            guard distToBall > 0.01 else { continue }
            let chaseDir = toBall / distToBall

            // 2. Separation force — push away from nearby roaches
            var separation = SIMD3<Float>.zero
            for (j, other) in roachData.enumerated() {
                guard i != j else { continue }
                let diff = roachPos - other.position  // vector AWAY from neighbor
                let dist = length(diff)
                if dist < Self.separationRadius && dist > 0.001 {
                    // Stronger push the closer they are
                    let pushStrength = (Self.separationRadius - dist) / Self.separationRadius
                    separation += (diff / dist) * pushStrength * Self.separationStrength
                }
            }

            // 3. Combine chase + separation
            let combined = SIMD3<Float>(
                (chaseDir.x * roachComp.speed) + separation.x,
                0,
                (chaseDir.z * roachComp.speed) + separation.z
            )

            // Update velocity
            if var motion = roach.components[PhysicsMotionComponent.self] {
                motion.linearVelocity = combined
                roach.components[PhysicsMotionComponent.self] = motion
            }

            // Face toward movement direction
            let moveDir = SIMD2<Float>(combined.x, combined.z)
            if length(moveDir) > 0.01 {
                let angle = atan2(combined.x, combined.z)
                roach.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            }
        }
    }
}
