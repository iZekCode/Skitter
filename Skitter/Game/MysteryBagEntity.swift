import RealityKit
import UIKit

// MARK: - Bag Type

enum BagType {
    case baygon   // WIN — the one pesticide can hidden among the bags
    case bait     // LOSE escalation — rotten food pile inside
}

// MARK: - Component

/// ECS component attached to every mystery bag entity.
/// Stores the bag's hidden type and whether it has already been triggered.
struct MysteryBagComponent: Component {
    let bagType: BagType
    var hasTriggered: Bool = false
}

// MARK: - Factory

/// Factory for the 5 identical black trash bags scattered around the arena.
///
/// All bags look the same — matte black kresek hitam. The player can't tell
/// which is which until they walk into one and trigger a collision.
enum MysteryBagEntity {

    // MARK: - Dimensions

    /// Width of the bag mesh (X axis)
    static let width: Float  = 1.2
    /// Height of the bag mesh (Y axis) — crumpled bag, not tall
    static let height: Float = 1.0
    /// Depth of the bag mesh (Z axis)
    static let depth: Float  = 0.9

    /// Trigger radius — slightly larger than the mesh so the player
    /// "finds" the bag just before visually walking into it.
    static let triggerRadius: Float = 1.4

    // MARK: - Spawn rules

    /// Minimum distance between any two bags
    static let minBagSpacing: Float = 15.0
    /// Minimum distance from the player start position (arena center)
    static let minDistFromStart: Float = 20.0

    // MARK: - Factory

    /// Creates one mystery bag entity at `position`.
    /// `bagType` is the hidden payload — unknown to the player until triggered.
    static func create(at position: SIMD3<Float>, type bagType: BagType) -> ModelEntity {
        let bag = ModelEntity()
        bag.name = "mysteryBag"

        // ── Mesh — crumpled rectangular bag ─────────────────────────────────
        let mesh = MeshResource.generateBox(
            width: width,
            height: height,
            depth: depth,
            cornerRadius: 0.25   // soft corners — plastic bag, not a crate
        )

        // Matte black, slightly wet-looking (low roughness, near-zero metallic)
        var material = PhysicallyBasedMaterial()
        material.baseColor    = .init(tint: UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1.0))
        material.roughness    = .init(floatLiteral: 0.35)   // slightly shiny — damp plastic
        material.metallic     = .init(floatLiteral: 0.0)

        bag.model = ModelComponent(mesh: mesh, materials: [material])

        // Sit flush on the floor — origin is at centre of the box,
        // so lift by half the height.
        bag.position = SIMD3<Float>(position.x, height / 2.0, position.z)

        // ── Collision — trigger only ─────────────────────────────────────────
        // The bag doesn't block movement; the player walks through it.
        // BagTriggerSystem listens for CollisionEvents.Began on this shape.
        bag.components.set(CollisionComponent(
            shapes: [.generateSphere(radius: triggerRadius)],
            mode: .trigger,
            filter: CollisionFilter(
                group: CollisionGroups.obstacle,    // reuse existing group
                mask: [CollisionGroups.ball]        // ball = player (Phase 2 reuse)
            )
        ))

        // ── ECS component ────────────────────────────────────────────────────
        bag.components.set(MysteryBagComponent(bagType: bagType))

        return bag
    }

    // MARK: - Batch spawn

    /// Spawns exactly 5 bags into `parent` — 1 baygon, 4 bait.
    /// Placement rules:
    ///   - No bag within `minDistFromStart` of arena center
    ///   - No two bags within `minBagSpacing` of each other
    ///   - Keeps trying random positions until both rules are satisfied
    ///     (max 100 attempts per bag before giving up and placing anyway)
    static func spawnAll(in parent: Entity) {
        let positions = generatePositions(count: 5)

        // Shuffle so baygon index is random — not always the first one placed
        let types: [BagType] = [.baygon, .bait, .bait, .bait, .bait].shuffled()

        for (i, pos) in positions.enumerated() {
            let bag = create(at: pos, type: types[i])
            bag.name = "mysteryBag_\(i)"
            parent.addChild(bag)
        }
    }

    // MARK: - Position generation

    private static func generatePositions(count: Int) -> [SIMD3<Float>] {
        let halfArena = ArenaBuilder.arenaSize / 2.0 - 4.0  // stay away from walls
        var placed: [SIMD3<Float>] = []

        for _ in 0..<count {
            var candidate = SIMD3<Float>.zero
            var attempts = 0

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

    private static func isValidPosition(_ pos: SIMD3<Float>, against placed: [SIMD3<Float>]) -> Bool {
        // Too close to player start (arena center)
        let distFromCenter = length(SIMD2<Float>(pos.x, pos.z))
        if distFromCenter < minDistFromStart { return false }

        // Too close to another bag
        for other in placed {
            let dist = length(SIMD2<Float>(pos.x - other.x, pos.z - other.z))
            if dist < minBagSpacing { return false }
        }

        return true
    }
}
