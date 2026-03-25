import RealityKit
import UIKit

enum PlayerEntity {

    // MARK: - Constants

    static let halfHeight: Float = 0.2
    static let radius: Float = 0.1
    static let standingHeight: Float = halfHeight * 2 + radius * 2
    static let eyeHeight: Float = standingHeight * 0.85
    static let mass: Float = 70.0

    // MARK: - Factory

    static func create() -> ModelEntity {
        let player = ModelEntity()
        player.name = "player"

        let totalHalfExtent = halfHeight + radius
        player.position = SIMD3<Float>(0, totalHalfExtent, 0)

        // Physics
        var physics = PhysicsBodyComponent(mode: .dynamic)
        physics.massProperties = .init(mass: mass)
        physics.material = .generate(
            staticFriction: 0.5,
            dynamicFriction: 0.4,
            restitution: 0.0
        )
        physics.isAffectedByGravity = true

        physics.linearDamping = 4.0
        physics.angularDamping = 100.0

        player.components.set(physics)

        // Collision
        player.components.set(CollisionComponent(
            shapes: [.generateCapsule(height: halfHeight * 2, radius: radius)],
            mode: .default,
            filter: CollisionFilter(
                group: CollisionGroups.ball,
                mask: [
                    CollisionGroups.obstacle,
                    CollisionGroups.roach,
                    CollisionGroups.boundary
                ]
            )
        ))

        // Motion component
        player.components.set(PhysicsMotionComponent())

        // Eye anchor
        let eye = Entity()
        eye.name = "playerEye"
        eye.position = SIMD3<Float>(0, eyeHeight - totalHalfExtent, 0)
        player.addChild(eye)

        return player
    }
}
