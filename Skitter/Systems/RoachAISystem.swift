import RealityKit
import Foundation

/// ECS System that makes roaches chase the ball every frame
class RoachAISystem: System {
    static let query = EntityQuery(where: .has(RoachComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        // Find the ball
        guard let ball = context.scene.findEntity(named: "ball") else { return }
        let ballPos = ball.position(relativeTo: nil)

        for roach in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let roachComp = roach.components[RoachComponent.self] else { continue }

            let roachPos = roach.position(relativeTo: nil)
            let direction = ballPos - roachPos
            let distance = length(direction)

            guard distance > 0.01 else { continue }

            let normalizedDir = direction / distance
            let velocity = SIMD3<Float>(
                normalizedDir.x * roachComp.speed,
                0, // Keep on ground plane
                normalizedDir.z * roachComp.speed
            )

            // Update velocity
            if var motion = roach.components[PhysicsMotionComponent.self] {
                motion.linearVelocity = velocity
                roach.components[PhysicsMotionComponent.self] = motion
            }

            // Face toward ball
            let angle = atan2(normalizedDir.x, normalizedDir.z)
            roach.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
        }
    }
}
