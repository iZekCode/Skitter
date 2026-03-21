import RealityKit
import UIKit

// MARK: - Collision groups

struct CollisionGroups {
    static let ball      = CollisionGroup(rawValue: 1 << 0)
    static let obstacle  = CollisionGroup(rawValue: 1 << 1)
    static let roach     = CollisionGroup(rawValue: 1 << 2)
    static let boundary  = CollisionGroup(rawValue: 1 << 3)
}

// MARK: - Arena builder

enum ArenaBuilder {
    static let arenaSize:     Float = 60.0
    static let wallHeight:    Float = 3.0
    static let wallThickness: Float = 1.0

    // MARK: - Obstacle configs (shared with MiniMapView)

    static let obstacleConfigs: [(position: SIMD3<Float>, size: SIMD3<Float>)] = [
        (SIMD3<Float>(-12, 1.0,  -8),  SIMD3<Float>(3,   2,   3)),
        (SIMD3<Float>( 10, 0.75,  5),  SIMD3<Float>(2.5, 1.5, 4)),
        (SIMD3<Float>( -5, 1.2,  14),  SIMD3<Float>(4,   2.4, 2)),
        (SIMD3<Float>( 18, 0.9, -12),  SIMD3<Float>(3,   1.8, 3)),
        (SIMD3<Float>(-18, 0.8, -18),  SIMD3<Float>(2,   1.6, 5)),
        (SIMD3<Float>(  8, 1.1, -20),  SIMD3<Float>(5,   2.2, 2.5)),
        (SIMD3<Float>(-15, 0.05,  10),  SIMD3<Float>(3.5, 0.1, 3)),
        (SIMD3<Float>( 20, 1.0,  15),  SIMD3<Float>(2.5, 2,   2.5)),
        (SIMD3<Float>(  0, 0.6, -15),  SIMD3<Float>(2,   1.2, 2)),
        (SIMD3<Float>( -8, 0.85, 22),  SIMD3<Float>(3,   1.7, 3)),
    ]

    // MARK: - Slot → model mapping

    private struct SlotModel { let name: String; let solid: Bool }

    private static let slotModels: [SlotModel] = [
        SlotModel(name: "trash_pile",   solid: true),
        SlotModel(name: "trash_barrel", solid: true),
        SlotModel(name: "trash_pile",   solid: true),
        SlotModel(name: "oil_drum",     solid: true),
        SlotModel(name: "fence",        solid: true),
        SlotModel(name: "trash_barrel", solid: true),
        SlotModel(name: "oil_puddle",   solid: false),
        SlotModel(name: "oil_drum",     solid: true),
        SlotModel(name: "trash_pile",   solid: true),
        SlotModel(name: "fence",        solid: true),
    ]

    // MARK: - Caches

    private static var modelCache:   [String: Entity] = [:]
    private static var floorTexture: TextureResource?  = nil

    // MARK: - Preload

    /// Must be called on the main actor before buildArena().
    static func preload() {
        // ── Floor texture ────────────────────────────────────────────────────
        // Load via UIImage → CGImage → TextureResource(image:) so the texture
        // is fully resident in memory with no async GPU-upload step.
        // TextureResource.load(contentsOf:) schedules an async GPU upload that
        // may not complete before the first rendered frame — this avoids that.
        if floorTexture == nil {
            // UIImage(named:) only resolves Asset Catalog entries.
            // floor.jpg is a loose bundle resource — must use Bundle.main URL.
            let uiImage: UIImage? = {
                if let url = Bundle.main.url(forResource: "floor", withExtension: "jpg") {
                    return UIImage(contentsOfFile: url.path)
                }
                return UIImage(named: "floor") // fallback if ever moved to .xcassets
            }()

            if let uiImage,
               let cgImage = uiImage.cgImage,
               let tex = try? TextureResource(image: cgImage,
                                              options: .init(semantic: .color)) {
                floorTexture = tex
                print("[ArenaBuilder] ✅ Loaded floor texture via bundle URL")
            } else {
                print("[ArenaBuilder] ⚠️  floor.jpg not found — using solid colour")
            }
        }

        // ── Obstacle models ──────────────────────────────────────────────────
        let names = Set(slotModels.map(\.name))
        for name in names where modelCache[name] == nil {
            if let e = try? Entity.load(named: name) {
                modelCache[name] = e
                print("[ArenaBuilder] ✅ Preloaded \(name).usdz")
            } else {
                print("[ArenaBuilder] ⚠️  \(name).usdz missing — using fallback box")
            }
        }
    }

    // MARK: - Build

    static func buildArena() -> Entity {
        let root = Entity()
        root.name = "arena"
        root.addChild(createFloor())
        createBoundaryWalls().forEach { root.addChild($0) }
        createObstacles().forEach    { root.addChild($0) }
        return root
    }

    // MARK: - Floor

    private static func createFloor() -> ModelEntity {
        // Build a tiled quad manually so the texture repeats instead of stretching.
        let h:     Float = arenaSize / 2.0
        let tiles: Float = 15.0    // 15×15 repeats across 60 m

        var desc = MeshDescriptor(name: "tiledFloor")
        desc.positions = MeshBuffer([
            SIMD3<Float>(-h, 0, -h),
            SIMD3<Float>( h, 0, -h),
            SIMD3<Float>(-h, 0,  h),
            SIMD3<Float>( h, 0,  h),
        ])
        desc.textureCoordinates = MeshBuffer([
            SIMD2<Float>(0,     0    ),
            SIMD2<Float>(tiles, 0    ),
            SIMD2<Float>(0,     tiles),
            SIMD2<Float>(tiles, tiles),
        ])
        desc.normals = MeshBuffer([
            SIMD3<Float>(0,1,0), SIMD3<Float>(0,1,0),
            SIMD3<Float>(0,1,0), SIMD3<Float>(0,1,0),
        ])
        desc.primitives = .triangles([0, 2, 1, 1, 2, 3])

        // Fall back to a plain plane if MeshDescriptor fails (e.g. on Simulator)
        let mesh = (try? MeshResource.generate(from: [desc]))
                   ?? MeshResource.generatePlane(width: arenaSize, depth: arenaSize)

        // UnlitMaterial: bypasses IBL entirely — always visible from frame 1.
        // Tint is set even when texture is present so the fallback is never black.
        var mat = UnlitMaterial()
        let tint = UIColor(red: 0.35, green: 0.28, blue: 0.18, alpha: 1.0)
        if let tex = floorTexture {
            mat.color = .init(tint: tint, texture: .init(tex))
        } else {
            mat.color = .init(tint: tint)
        }

        let floor      = ModelEntity(mesh: mesh, materials: [mat])
        floor.name     = "floor"
        floor.position = SIMD3<Float>(0, -0.05, 0)

        floor.components.set(CollisionComponent(
            shapes: [.generateBox(width: arenaSize, height: 0.1, depth: arenaSize)],
            mode: .default,
            filter: CollisionFilter(group: CollisionGroups.obstacle, mask: CollisionGroups.ball)
        ))
        var phys = PhysicsBodyComponent(mode: .static)
        phys.material = .generate(staticFriction: 0.5, dynamicFriction: 0.4, restitution: 0.2)
        floor.components.set(phys)

        return floor
    }

    // MARK: - Walls

    private static func createBoundaryWalls() -> [ModelEntity] {
        let half = arenaSize / 2.0
        var mat  = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(red: 0.05, green: 0.05, blue: 0.03, alpha: 0.5))
        mat.roughness = .init(floatLiteral: 0.9)

        let cfgs: [(SIMD3<Float>, Float, Float)] = [
            (SIMD3<Float>(0,     wallHeight/2, -half), arenaSize,     wallThickness),
            (SIMD3<Float>(0,     wallHeight/2,  half), arenaSize,     wallThickness),
            (SIMD3<Float>(-half, wallHeight/2,  0   ), wallThickness, arenaSize),
            (SIMD3<Float>( half, wallHeight/2,  0   ), wallThickness, arenaSize),
        ]
        return cfgs.enumerated().map { i, cfg in
            let (pos, w, d) = cfg
            let wall = ModelEntity(
                mesh: MeshResource.generateBox(width: w, height: wallHeight, depth: d),
                materials: [mat]
            )
            wall.name = "wall_\(i)"; wall.position = pos
            wall.components.set(CollisionComponent(
                shapes: [.generateBox(width: w, height: wallHeight, depth: d)],
                mode: .default,
                filter: CollisionFilter(group: CollisionGroups.boundary, mask: CollisionGroups.ball)
            ))
            wall.components.set(PhysicsBodyComponent(mode: .static))
            return wall
        }
    }

    // MARK: - Obstacles

    private static func createObstacles() -> [Entity] {
        obstacleConfigs.enumerated().map { makeObstacle(index: $0, config: $1) }
    }

    private static func makeObstacle(
        index: Int, config: (position: SIMD3<Float>, size: SIMD3<Float>)
    ) -> Entity {
        let slot = slotModels[index]
        let node = Entity()
        node.name = "obstacle_\(index)"; node.position = config.position

        if let tmpl = modelCache[slot.name] {
            let v = tmpl.clone(recursive: true)
            fitModel(v, to: config.size)
            node.addChild(v)
        } else {
            node.addChild(fallbackBox(size: config.size, index: index))
        }

        let mode: CollisionComponent.Mode = slot.solid ? .default : .trigger
        let mask: CollisionGroup = slot.solid
            ? [CollisionGroups.ball, CollisionGroups.roach] : CollisionGroups.ball
        node.components.set(CollisionComponent(
            shapes: [.generateBox(width: config.size.x, height: config.size.y, depth: config.size.z)],
            mode: mode, filter: CollisionFilter(group: CollisionGroups.obstacle, mask: mask)
        ))
        if slot.solid {
            var p = PhysicsBodyComponent(mode: .static)
            p.material = .generate(staticFriction: 0.6, dynamicFriction: 0.5, restitution: 0.4)
            node.components.set(p)
        }
        return node
    }

    // MARK: - Helpers

    private static func fitModel(_ e: Entity, to s: SIMD3<Float>) {
        let b     = e.visualBounds(relativeTo: e)
        let scale = b.extents.y > 0.001 ? s.y / b.extents.y : 1.0
        e.scale    = SIMD3<Float>(repeating: scale)
        e.position = SIMD3<Float>(0, -(b.min.y * scale) - s.y / 2.0, 0)
    }

    private static func fallbackBox(size: SIMD3<Float>, index: Int) -> ModelEntity {
        let colors: [UIColor] = [
            UIColor(red: 0.25, green: 0.18, blue: 0.10, alpha: 1),
            UIColor(red: 0.30, green: 0.15, blue: 0.08, alpha: 1),
            UIColor(red: 0.20, green: 0.20, blue: 0.12, alpha: 1),
            UIColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 1),
        ]
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: colors[index % colors.count])
        mat.roughness = .init(floatLiteral: 0.9)
        mat.metallic  = .init(floatLiteral: 0.05)
        return ModelEntity(
            mesh: MeshResource.generateBox(
                width: size.x, height: size.y, depth: size.z, cornerRadius: 0.1),
            materials: [mat])
    }
}
