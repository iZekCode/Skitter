import RealityKit
import UIKit

class FogSphere {

    static let outerRadius: Float = 28.0
    static let bandWidth:   Float = 10.0

    private static let r: CGFloat = 0.02
    private static let g: CGFloat = 0.05
    private static let b: CGFloat = 0.02

    private struct Layer {
        let radiusOffset: Float
        let alpha: CGFloat
    }

    private static let layers: [Layer] = [
        Layer(radiusOffset: bandWidth * 1.0, alpha: 0.10),
        Layer(radiusOffset: bandWidth * 0.65, alpha: 0.35),
        Layer(radiusOffset: bandWidth * 0.30, alpha: 0.70),
        Layer(radiusOffset: 0,                alpha: 1.00),
    ]

    // MARK: - Root

    let entity: Entity

    private init(entity: Entity) {
        self.entity = entity
    }

    // MARK: - Factory

    static func create() -> FogSphere {
        let root  = Entity()
        root.name = "fogSphere"

        for layer in layers {
            let radius = outerRadius - layer.radiusOffset
            root.addChild(makeSphere(radius: radius, alpha: layer.alpha))
        }

        return FogSphere(entity: root)
    }

    // MARK: - Per-frame

    func follow(player: ModelEntity) {
        entity.position = player.position(relativeTo: nil)
    }

    // MARK: - Sphere builder

    private static func makeSphere(radius: Float, alpha: CGFloat) -> ModelEntity {
        let mesh  = MeshResource.generateSphere(radius: radius)
        var mat   = UnlitMaterial()

        mat.color = .init(tint: UIColor(red: r, green: g, blue: b, alpha: alpha))

        let sphere      = ModelEntity(mesh: mesh, materials: [mat])
        sphere.scale    = SIMD3<Float>(-1, 1, 1)

        sphere.components.remove(CollisionComponent.self)
        sphere.components.remove(PhysicsBodyComponent.self)

        return sphere
    }
}
