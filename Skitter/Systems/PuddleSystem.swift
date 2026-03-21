import RealityKit
import Combine

/// Increases player linear damping while inside an oil puddle trigger,
/// making movement feel sluggish and resistant. Restores normal damping on exit.
class PuddleSystem {

    // Must match PlayerEntity.physics.linearDamping
    private static let normalDamping: Float = 4.0
    // High damping = fighting through thick oil
    private static let puddleDamping: Float = 30.0

    private var beganSub: (any Cancellable)?
    private var endedSub: (any Cancellable)?

    init(scene: RealityKit.Scene) {
        beganSub = scene.subscribe(to: CollisionEvents.Began.self) { event in
            Self.handle(event.entityA, event.entityB, entering: true)
        }
        endedSub = scene.subscribe(to: CollisionEvents.Ended.self) { event in
            Self.handle(event.entityA, event.entityB, entering: false)
        }
    }

    private static func handle(_ a: Entity, _ b: Entity, entering: Bool) {
        let playerEntity = [a, b].first { $0.name == "player" }
        let puddleEntity = [a, b].first { $0.name.starts(with: "puddle") }
        guard let player = playerEntity as? ModelEntity,
              puddleEntity != nil else { return }

        Task { @MainActor in
            guard var phys = player.components[PhysicsBodyComponent.self] else { return }
            phys.linearDamping = entering ? puddleDamping : normalDamping
            player.components[PhysicsBodyComponent.self] = phys
        }
    }

    func cancel() {
        beganSub?.cancel(); beganSub = nil
        endedSub?.cancel(); endedSub = nil
    }
}
