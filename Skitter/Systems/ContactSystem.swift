import RealityKit
import Combine
import Foundation

class ContactSystem {
    private var collisionSubscription: (any Cancellable)?
    private weak var gameState:     GameState?
    private weak var hapticManager: HapticManager?
    private weak var audioManager:  AudioManager?
    let onGameOver: (() -> Void)?

    init(scene: RealityKit.Scene,
         gameState: GameState,
         hapticManager: HapticManager?,
         audioManager: AudioManager?,
         onGameOver: (() -> Void)? = nil) {
        self.gameState     = gameState
        self.hapticManager = hapticManager
        self.audioManager  = audioManager
        self.onGameOver    = onGameOver

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

        // Roach contact → instant death
        if other.components[RoachComponent.self] != nil {
            DispatchQueue.main.async { [weak self] in
                gameState.triggerGameOver()
                self?.hapticManager?.playGameOver()
                self?.audioManager?.playGameOverLose()
                self?.onGameOver?() 
            }
            return
        }

        // Obstacle/wall contact → bump haptic only
        if other.name.starts(with: "obstacle") || other.name.starts(with: "wall") {
            hapticManager?.playObstacleHit()
        }
    }

    func cancel() {
        collisionSubscription?.cancel()
        collisionSubscription = nil
    }
}
