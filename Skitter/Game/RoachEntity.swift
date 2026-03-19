import RealityKit
import UIKit

/// Factory for creating cockroach entities
enum RoachEntity {
    static let floorOffset: Float = 0.1
    static let chaserScale: Float = 10
    
    // Capsule dimensions — should roughly match the roach visual body at scale 10.
    // Height = total capsule length (head to tail).
    // Radius = half the body width.
    // Tweak these if the hitbox still feels off.
    static let collisionCapsuleRadius: Float = 0.25 * chaserScale
    static let collisionCapsuleHeight: Float = 0.5 * chaserScale

    // -------------------------------------------------------------------------
    // MARK: - Template cache

    private static var chaserTemplate: Entity? = nil

    /// Call once in GameView.beginGame() before any roaches spawn.
    /// Loads the USDZ a single time — all spawns after this just clone it.
    static func preload() {
        guard chaserTemplate == nil else { return }
        if let scene = try? Entity.load(named: "roachType1_raw") {
            scene.scale = SIMD3<Float>(repeating: chaserScale)
            let flatten = simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0))
            let facing  = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))
            scene.orientation = facing * flatten
            chaserTemplate = scene
            print("[RoachEntity] ✅ Preloaded roachType1_raw.usdz")
        } else {
            print("[RoachEntity] ⚠️ Could not preload roachType1_raw.usdz — will use fallback")
        }
    }

    // -------------------------------------------------------------------------
    // MARK: - Chaser

    static func createChaser(at position: SIMD3<Float>) -> ModelEntity {
        let container = ModelEntity()
        container.name = "roach_chaser"
        container.position = SIMD3<Float>(position.x, floorOffset, position.z)

        // Clone the cached template — memory copy only, no disk/GPU work
        if let template = chaserTemplate {
            container.addChild(template.clone(recursive: true))
        } else {
            // preload() wasn't called or failed — fall back to procedural mesh
            let fallback = makeFallbackMesh()
            container.model = fallback.model
        }

        container.components.set(PhysicsBodyComponent(mode: .kinematic))
        
        // Capsule aligned along Z (the roach's forward/back axis).
        // This covers the full body length — head AND tail trigger the hit,
        // not just the center like a single small sphere.
        container.components.set(CollisionComponent(
            shapes: [
                .generateCapsule(height: collisionCapsuleHeight, radius: collisionCapsuleRadius)
            ],
            mode: .trigger,
            filter: CollisionFilter(
                group: CollisionGroups.roach,
                mask: [CollisionGroups.ball]
            )
        ))
        container.components.set(PhysicsMotionComponent())
        container.components.set(RoachComponent.chaser())

        return container
    }

    // -------------------------------------------------------------------------
    // MARK: - Fallback mesh

    private static func makeFallbackMesh() -> ModelEntity {
        let bodyRadius: Float = 0.35
        let bodyLength: Float = 0.70

        let mesh = MeshResource.generateBox(
            width: bodyRadius * 2,
            height: bodyRadius * 0.6,
            depth: bodyLength,
            cornerRadius: 0.08
        )

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.35, green: 0.20, blue: 0.10, alpha: 1.0))
        material.roughness = .init(floatLiteral: 0.4)
        material.metallic  = .init(floatLiteral: 0.2)

        return ModelEntity(mesh: mesh, materials: [material])
    }

    // -------------------------------------------------------------------------
    // MARK: - Spawn positions

    static func randomEdgePosition(arenaSize: Float = ArenaBuilder.arenaSize) -> SIMD3<Float> {
        let half = arenaSize / 2.0 - 2.0
        switch Int.random(in: 0...3) {
        case 0:  return SIMD3<Float>(Float.random(in: -half...half), 0, -half)
        case 1:  return SIMD3<Float>(Float.random(in: -half...half), 0,  half)
        case 2:  return SIMD3<Float>(-half, 0, Float.random(in: -half...half))
        default: return SIMD3<Float>( half, 0, Float.random(in: -half...half))
        }
    }
}
