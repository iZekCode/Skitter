import RealityKit
import UIKit

/// Factory for creating cockroach entities
enum RoachEntity {
    static let bodyRadius: Float = 0.35
    static let bodyLength: Float = 0.7

    /// Creates a Chaser roach at the given position
    static func createChaser(at position: SIMD3<Float>) -> ModelEntity {
        // Elongated box for cockroach body shape
        let mesh = MeshResource.generateBox(
            width: bodyRadius * 2,
            height: bodyRadius * 0.6,
            depth: bodyLength,
            cornerRadius: 0.08
        )

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.35, green: 0.20, blue: 0.10, alpha: 1.0))
        material.roughness = .init(floatLiteral: 0.4)
        material.metallic = .init(floatLiteral: 0.2)

        let roach = ModelEntity(mesh: mesh, materials: [material])
        roach.name = "roach_chaser"
        roach.position = SIMD3<Float>(position.x, bodyRadius * 0.3, position.z)

        // Kinematic physics — moved by AI system
        let physics = PhysicsBodyComponent(mode: .kinematic)
        roach.components.set(physics)

        // Collision
        roach.components.set(CollisionComponent(
            shapes: [.generateSphere(radius: bodyRadius)],
            mode: .trigger,
            filter: CollisionFilter(
                group: CollisionGroups.roach,
                mask: [CollisionGroups.ball, CollisionGroups.obstacle]
            )
        ))

        // Motion for AI-driven velocity
        roach.components.set(PhysicsMotionComponent())

        // Roach behavior data
        roach.components.set(RoachComponent.chaser())

        return roach
    }

    /// Generates spawn positions around the arena edges
    static func randomEdgePosition(arenaSize: Float = ArenaBuilder.arenaSize) -> SIMD3<Float> {
        let half = arenaSize / 2.0 - 2.0
        let edge = Int.random(in: 0...3)

        switch edge {
        case 0: // North
            return SIMD3<Float>(Float.random(in: -half...half), 0, -half)
        case 1: // South
            return SIMD3<Float>(Float.random(in: -half...half), 0, half)
        case 2: // West
            return SIMD3<Float>(-half, 0, Float.random(in: -half...half))
        default: // East
            return SIMD3<Float>(half, 0, Float.random(in: -half...half))
        }
    }
}
