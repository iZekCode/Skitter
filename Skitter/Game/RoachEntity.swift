import RealityKit
import UIKit

/// Factory for creating cockroach entities
enum RoachEntity {

    // MARK: - Shared constants

    static let floorOffset: Float = 0.1

    // MARK: - Chaser (roach_1)

    static let chaserScale:             Float = 4.0
    static let chaserCapsuleRadius:     Float = 0.25 * chaserScale
    static let chaserCapsuleHeight:     Float = 0.60 * chaserScale
    /// Yaw offset in radians to correct roach_1 model facing direction.
    /// 0 = faces +Z, .pi/2 = faces +X, .pi = faces -Z, -.pi/2 = faces -X
    static let chaserFacingYaw:         Float = .pi / 2

    // MARK: - Giant (roach_2)

    static let giantScale:              Float = 8.0
    static let giantCapsuleRadius:      Float = 0.25 * giantScale
    static let giantCapsuleHeight:      Float = 0.60 * giantScale
    /// Yaw offset in radians to correct roach_2 model facing direction.
    static let giantFacingYaw:          Float = 0.0

    // MARK: - Flying (roach_3)

    static let flyingScale:             Float = 4.0
    static let flyingCapsuleRadius:     Float = 0.25 * flyingScale
    static let flyingCapsuleHeight:     Float = 0.60 * flyingScale
    /// Yaw offset in radians to correct roach_3 model facing direction.
    static let flyingFacingYaw:         Float = .pi / 2
    /// How high flying roaches hover above the floor (meters)
    static let flyingHoverHeight:       Float = 2.5

    // MARK: - Template cache

    private static var chaserTemplate:  Entity? = nil
    private static var giantTemplate:   Entity? = nil
    private static var flyingTemplate:  Entity? = nil

    /// Preload all roach USDZ models. Call once before any spawning.
    static func preload() {
        if chaserTemplate == nil {
            chaserTemplate = loadTemplate(named: "roach_1", scale: chaserScale, facingYaw: chaserFacingYaw)
        }
        if giantTemplate == nil {
            giantTemplate = loadTemplate(named: "roach_2", scale: giantScale, facingYaw: giantFacingYaw)
        }
        if flyingTemplate == nil {
            flyingTemplate = loadTemplate(named: "roach_3", scale: flyingScale, facingYaw: flyingFacingYaw)
        }
    }

    private static func loadTemplate(named name: String, scale: Float, facingYaw: Float) -> Entity? {
        guard let scene = try? Entity.load(named: name) else {
            print("[RoachEntity] ⚠️  Could not load \(name).usdz — fallback mesh will be used")
            return nil
        }
        scene.scale       = SIMD3<Float>(repeating: scale)
        scene.orientation = simd_quatf(angle: facingYaw, axis: SIMD3<Float>(0, 1, 0))
        print("[RoachEntity] ✅ Preloaded \(name).usdz")
        return scene
    }

    // MARK: - Chaser

    static func createChaser(at position: SIMD3<Float>) -> ModelEntity {
        let container = makeContainer(
            name:          "roach_chaser",
            position:      SIMD3<Float>(position.x, floorOffset, position.z),
            template:      chaserTemplate,
            capsuleRadius: chaserCapsuleRadius,
            capsuleHeight: chaserCapsuleHeight,
            component:     .chaser()
        )
        return container
    }

    // MARK: - Giant

    static func createGiant(at position: SIMD3<Float>) -> ModelEntity {
        let container = makeContainer(
            name:          "roach_giant",
            position:      SIMD3<Float>(position.x, floorOffset, position.z),
            template:      giantTemplate,
            capsuleRadius: giantCapsuleRadius,
            capsuleHeight: giantCapsuleHeight,
            component:     .giant()
        )
        return container
    }

    // MARK: - Flying

    static func createFlying(at position: SIMD3<Float>) -> ModelEntity {
        let container = makeContainer(
            name:          "roach_flying",
            position:      SIMD3<Float>(position.x, flyingHoverHeight, position.z),
            template:      flyingTemplate,
            capsuleRadius: flyingCapsuleRadius,
            capsuleHeight: flyingCapsuleHeight,
            component:     .flying()
        )
        return container
    }

    // MARK: - Shared builder

    private static func makeContainer(
        name:          String,
        position:      SIMD3<Float>,
        template:      Entity?,
        capsuleRadius: Float,
        capsuleHeight: Float,
        component:     RoachComponent
    ) -> ModelEntity {
        let container      = ModelEntity()
        container.name     = name
        container.position = position

        if let tmpl = template {
            container.addChild(tmpl.clone(recursive: true))
        } else {
            let fallback = makeFallbackMesh(component: component)
            container.model = fallback.model
        }

        container.components.set(PhysicsBodyComponent(mode: .kinematic))
        container.components.set(CollisionComponent(
            shapes: [.generateCapsule(height: capsuleHeight, radius: capsuleRadius)],
            mode: .trigger,
            filter: CollisionFilter(
                group: CollisionGroups.roach,
                mask:  [CollisionGroups.ball]
            )
        ))
        container.components.set(PhysicsMotionComponent())
        container.components.set(component)

        return container
    }

    // MARK: - Fallback mesh

    private static func makeFallbackMesh(component: RoachComponent) -> ModelEntity {
        let color: UIColor
        switch component.roachType {
        case .chaser: color = UIColor(red: 0.35, green: 0.20, blue: 0.10, alpha: 1.0)
        case .giant:  color = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        case .flying: color = UIColor(red: 0.50, green: 0.20, blue: 0.10, alpha: 1.0)
        }
        let mesh = MeshResource.generateBox(width: 0.7, height: 0.4, depth: 1.4, cornerRadius: 0.08)
        var mat  = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: color)
        mat.roughness = .init(floatLiteral: 0.4)
        mat.metallic  = .init(floatLiteral: 0.2)
        return ModelEntity(mesh: mesh, materials: [mat])
    }

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
