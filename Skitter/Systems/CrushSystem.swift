import RealityKit
import Combine
import Foundation

/// Handles ball-roach collisions: crush (fast enough) or game over (too slow)
class CrushSystem {
    private var collisionSubscription: (any Cancellable)?
    private weak var gameState: GameState?
    private var hapticManager: HapticManager?

    init(scene: RealityKit.Scene, gameState: GameState, hapticManager: HapticManager?) {
        self.gameState = gameState
        self.hapticManager = hapticManager

        // Subscribe to collision events
        collisionSubscription = scene.subscribe(to: CollisionEvents.Began.self) { [weak self] event in
            self?.handleCollision(event)
        }
    }

    private func handleCollision(_ event: CollisionEvents.Began) {
        guard let gameState = gameState, !gameState.isGameOver else { return }

        let entityA = event.entityA
        let entityB = event.entityB

        let isRoachHit =
            (entityA.name == "ball" && entityB.components[RoachComponent.self] != nil) ||
            (entityB.name == "ball" && entityA.components[RoachComponent.self] != nil)

        guard isRoachHit else {
            // Ball hit obstacle/wall
            let other = entityA.name == "ball" ? entityB : entityA
            if entityA.name == "ball" || entityB.name == "ball" {
                if other.name.starts(with: "obstacle") || other.name.starts(with: "wall") {
                    hapticManager?.playObstacleHit()
                }
            }
            return
        }

        // Any roach contact = game over
        DispatchQueue.main.async {
            gameState.triggerGameOver()
            self.hapticManager?.playGameOver()
        }
    }

    func cancel() {
        collisionSubscription?.cancel()
        collisionSubscription = nil
    }
}
