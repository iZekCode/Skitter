import RealityKit
import UIKit

/// Factory for creating the player character entity.
///
/// The "player" is a small human trapped in a landfill — proportionally tiny
/// relative to the roaches. In first-person, the body itself is never visible;
/// what matters is the physics capsule, collision shape, and the eye-level
/// anchor point the camera attaches to.
enum PlayerEntity {

    // MARK: - Constants

    /// Capsule half-height (meters). Total standing height = 2 × halfHeight + 2 × radius.
    static let halfHeight: Float = 0.2
    /// Capsule radius (meters).
    static let radius: Float = 0.1
    /// Full standing height, convenience.
    static let standingHeight: Float = halfHeight * 2 + radius * 2   // 1.2 m

    /// Eye level above the capsule's origin (which sits at ground level).
    /// Camera is placed at this Y offset relative to the player entity.
    static let eyeHeight: Float = standingHeight * 0.85              // ~1.02 m

    /// Mass in kg — light enough to feel responsive, heavy enough not to fly on collision.
    static let mass: Float = 70.0

    // MARK: - Factory

    /// Creates the player entity and a named eye-anchor child for camera attachment.
    ///
    /// Returns the root player entity. Camera should be parented to the child
    /// entity named `"playerEye"`.
    static func create() -> ModelEntity {
        let player = ModelEntity()
        player.name = "player"

        // Start position: center of arena, capsule base at floor level.
        // The capsule origin is at the *centre* of the shape, so we lift by
        // half the total height so the bottom sits on y = 0.
        let totalHalfExtent = halfHeight + radius
        player.position = SIMD3<Float>(0, totalHalfExtent, 0)

        // ── Physics ──────────────────────────────────────────────────────────
        var physics = PhysicsBodyComponent(mode: .dynamic)
        physics.massProperties = .init(mass: mass)
        physics.material = .generate(
            staticFriction: 0.5,
            dynamicFriction: 0.4,
            restitution: 0.0      // no bounce — humans don't bounce
        )
        physics.isAffectedByGravity = true

        // High angular damping prevents the capsule from tipping over.
        // Linear damping simulates ground friction / air resistance.
        physics.linearDamping = 4.0
        physics.angularDamping = 100.0

        player.components.set(physics)

        // ── Collision ────────────────────────────────────────────────────────
        // Use a capsule so the player slides smoothly along walls and obstacles.
        player.components.set(CollisionComponent(
            shapes: [.generateCapsule(height: halfHeight * 2, radius: radius)],
            mode: .default,
            filter: CollisionFilter(
                group: CollisionGroups.ball,           // reuse existing group
                mask: [
                    CollisionGroups.obstacle,
                    CollisionGroups.roach,
                    CollisionGroups.boundary
                ]
            )
        ))

        // ── Motion component ─────────────────────────────────────────────────
        // MotionController writes directly to linearVelocity each frame.
        player.components.set(PhysicsMotionComponent())

        // ── Eye anchor ───────────────────────────────────────────────────────
        // A plain Entity child at eye height — the camera is positioned here
        // in GameView so it always sits at the correct world-space Y.
        let eye = Entity()
        eye.name = "playerEye"
        eye.position = SIMD3<Float>(0, eyeHeight - totalHalfExtent, 0)
        player.addChild(eye)

        return player
    }
}
