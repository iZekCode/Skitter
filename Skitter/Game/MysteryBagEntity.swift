import RealityKit
import UIKit

// MARK: - Bag Type

enum BagType {
    case baygon
    case bait
}

// MARK: - Component

struct MysteryBagComponent: Component {
    let bagType: BagType
    var hasTriggered: Bool = false
}

// MARK: - Factory

enum MysteryBagEntity {

    // MARK: - Dimensions

    static let width:  Float = 1.2
    static let height: Float = 1.0
    static let depth:  Float = 0.9
    static let triggerRadius: Float = 1.4

    // MARK: - Spawn rules

    static let minBagSpacing:    Float = 15.0
    static let minDistFromStart: Float = 20.0

    // MARK: - Model cache

    private static var bagTemplate:    Entity? = nil
    private static var baygonTemplate: Entity? = nil
    private static var baitTemplate:   Entity? = nil

    static func preload() {
        if bagTemplate == nil {
            if let e = try? Entity.load(named: "black_plastic") {
                bagTemplate = e
                print("[MysteryBagEntity] ✅ Preloaded black_plastic.usdz")
            } else {
                print("[MysteryBagEntity] ⚠️  Could not load black_plastic.usdz — using fallback")
            }
        }
        if baygonTemplate == nil {
            if let e = try? Entity.load(named: "byegone") {
                baygonTemplate = e
                print("[MysteryBagEntity] ✅ Preloaded byegone.usdz")
            } else {
                print("[MysteryBagEntity] ⚠️  Could not load byegone.usdz")
            }
        }
        if baitTemplate == nil {
            if let e = try? Entity.load(named: "food_pile") {
                baitTemplate = e
                print("[MysteryBagEntity] ✅ Preloaded food_pile.usdz")
            } else {
                print("[MysteryBagEntity] ⚠️  Could not load food_pile.usdz")
            }
        }
    }

    // MARK: - Factory

    static func create(at position: SIMD3<Float>, type bagType: BagType) -> Entity {
        let bag  = Entity()
        bag.name = "mysteryBag"

        // Visual child
        if let template = bagTemplate {
            let visual = template.clone(recursive: true)
            fitModel(visual, width: width, height: height, depth: depth)
            bag.addChild(visual)
        } else {
            // Fallback
            let mesh = MeshResource.generateBox(
                width: width, height: height, depth: depth, cornerRadius: 0.25
            )
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(tint: UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1.0))
            mat.roughness = .init(floatLiteral: 0.35)
            mat.metallic  = .init(floatLiteral: 0.0)
            let fallback  = ModelEntity(mesh: mesh, materials: [mat])
            fallback.position.y = height / 2.0
            bag.addChild(fallback)
        }

        bag.position = SIMD3<Float>(position.x, 0, position.z)

        // Collision — trigger only
        bag.components.set(CollisionComponent(
            shapes: [.generateSphere(radius: triggerRadius)],
            mode: .trigger,
            filter: CollisionFilter(
                group: CollisionGroups.obstacle,
                mask:  [CollisionGroups.ball]
            )
        ))
        
        // ECS component
        bag.components.set(MysteryBagComponent(bagType: bagType))

        return bag
    }

    // MARK: - Reveal entity
    
    static func createRevealEntity(for bagType: BagType) -> Entity? {
        let template = bagType == .baygon ? baygonTemplate : baitTemplate
        guard let t = template else { return nil }

        let reveal = t.clone(recursive: true)
        fitModel(reveal, width: width, height: height, depth: depth)
        return reveal
    }

    // MARK: - Batch spawn

    /// Spawns bags: 1 baygon + (totalBags-1) bait, randomly placed
    static func spawnAll(in parent: Entity, totalBags: Int = 5) {
        let positions = generatePositions(count: totalBags)
        var types: [BagType] = [.baygon] + Array(repeating: .bait, count: max(0, totalBags - 1))
        types.shuffle()

        for (i, pos) in positions.enumerated() {
            let bag      = create(at: pos, type: types[i])
            bag.name     = "mysteryBag_\(i)"
            parent.addChild(bag)
        }
    }

    // MARK: - Position generation

    private static func generatePositions(count: Int) -> [SIMD3<Float>] {
        let halfArena = ArenaBuilder.arenaSize / 2.0 - 4.0
        var placed: [SIMD3<Float>] = []

        for _ in 0..<count {
            var candidate = SIMD3<Float>.zero
            var attempts  = 0

            repeat {
                candidate = SIMD3<Float>(
                    Float.random(in: -halfArena...halfArena),
                    0,
                    Float.random(in: -halfArena...halfArena)
                )
                attempts += 1
            } while !isValidPosition(candidate, against: placed) && attempts < 100

            placed.append(candidate)
        }
        return placed
    }

    private static func isValidPosition(
        _ pos: SIMD3<Float>,
        against placed: [SIMD3<Float>]
    ) -> Bool {
        let distFromCenter = length(SIMD2<Float>(pos.x, pos.z))
        if distFromCenter < minDistFromStart { return false }

        for other in placed {
            let dist = length(SIMD2<Float>(pos.x - other.x, pos.z - other.z))
            if dist < minBagSpacing { return false }
        }
        return true
    }

    // MARK: - Shared model-fitting helper

    private static func fitModel(
        _ entity: Entity,
        width:  Float,
        height: Float,
        depth:  Float
    ) {
        let rawBounds = entity.visualBounds(relativeTo: entity)
        let rawHeight = rawBounds.extents.y

        let scale: Float = rawHeight > 0.001 ? height / rawHeight : 1.0
        entity.scale = SIMD3<Float>(repeating: scale)

        let scaledMinY  = rawBounds.min.y * scale
        entity.position = SIMD3<Float>(0, -scaledMinY, 0)
    }
}
