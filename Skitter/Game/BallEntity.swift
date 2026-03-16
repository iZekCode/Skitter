import RealityKit
import UIKit

/// Factory for creating the player ball entity
enum BallEntity {
    static let radius: Float = 0.5
    static let mass: Float = 1.0

    /// Creates the player ball with physics and collision
    static func create() -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: radius)

        // Semi-transparent yellowish material
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.9, green: 0.85, blue: 0.6, alpha: 0.35))
        material.roughness = .init(floatLiteral: 0.1)
        material.metallic = .init(floatLiteral: 0.3)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.5))
        material.faceCulling = .none  // Double-sided for transparent sphere

        let ball = ModelEntity(mesh: mesh, materials: [material])
        ball.name = "ball"
        ball.position = SIMD3<Float>(0, radius, 0)

        // Dynamic physics body
        var physics = PhysicsBodyComponent(mode: .dynamic)
        physics.massProperties = .init(mass: mass)
        physics.material = .generate(staticFriction: 0.3, dynamicFriction: 0.2, restitution: 0.3)
        physics.isAffectedByGravity = true
        physics.linearDamping = 0.8
        physics.angularDamping = 2.0
        ball.components.set(physics)

        // Collision shape
        ball.components.set(CollisionComponent(
            shapes: [.generateSphere(radius: radius)],
            mode: .default,
            filter: CollisionFilter(
                group: CollisionGroups.ball,
                mask: [CollisionGroups.obstacle, CollisionGroups.roach, CollisionGroups.boundary]
            )
        ))

        // Motion component for velocity control
        ball.components.set(PhysicsMotionComponent())

        return ball
    }
}
