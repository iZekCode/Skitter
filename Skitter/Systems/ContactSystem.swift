import RealityKit
import Combine
import Foundation

/// Handles all collision events between the player and the world.
///
/// Phase 2+ rules — no crush mechanic:
/// - Player touches a roach → instant game over
/// - Player touches obstacle / wall → haptic bump, no penalty
class ContactSystem {
    private var collisionSubscription: (any Cancellable)?
    private weak var gameState:     GameState?
    private weak var hapticManager: HapticManager?
    private weak var audioManager:  AudioManager?

    init(scene: RealityKit.Scene,
         gameState: GameState,
         hapticManager: HapticManager?,
         audioManager: AudioManager?) {
        self.gameState     = gameState
        self.hapticManager = hapticManager
        self.audioManager  = audioManager

        collisionSubscription = scene.subscribe(to: CollisionEvents.Began.self) { [weak self] event in
            self?.handleCollision(event)
        }
    }

    private func handleCollision(_ event: CollisionEvents.Began) {
        guard let gameState = gameState, !gameState.isGameOver else { return }

        let a = event.entityA
        let b = event.entityB

        let playerInvolved = a.name == "player" || b.name == "player"
        guard playerInvolved else { return }

        let other = a.name == "player" ? b : a

        // ── Roach contact → instant death ────────────────────────────────────
        if other.components[RoachComponent.self] != nil {
            DispatchQueue.main.async { [weak self] in
                gameState.triggerGameOver()
                self?.hapticManager?.playGameOver()
                self?.audioManager?.playGameOverLose()
            }
            return
        }

        // ── Obstacle / wall contact → bump haptic only ────────────────────────
        if other.name.starts(with: "obstacle") || other.name.starts(with: "wall") {
            hapticManager?.playObstacleHit()
        }
    }

    func cancel() {
        collisionSubscription?.cancel()
        collisionSubscription = nil
    }
}
