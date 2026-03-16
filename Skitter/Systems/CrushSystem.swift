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

        // Determine which is ball and which is roach
        let entityA = event.entityA
        let entityB = event.entityB

        let ball: Entity
        let roach: Entity

        if entityA.name == "ball" && (entityB.components[RoachComponent.self] != nil) {
            ball = entityA
            roach = entityB
        } else if entityB.name == "ball" && (entityA.components[RoachComponent.self] != nil) {
            ball = entityB
            roach = entityA
        } else {
            // Not a ball-roach collision — could be ball-obstacle
            if entityA.name == "ball" || entityB.name == "ball" {
                let other = entityA.name == "ball" ? entityB : entityA
                if other.name.starts(with: "obstacle") || other.name.starts(with: "wall") {
                    hapticManager?.playObstacleHit()
                }
            }
            return
        }

        // Check ball speed
        guard let roachComp = roach.components[RoachComponent.self] else { return }

        let ballVelocity: SIMD3<Float>
        if let motion = ball.components[PhysicsMotionComponent.self] {
            ballVelocity = motion.linearVelocity
        } else {
            ballVelocity = .zero
        }

        let speed = length(ballVelocity)

        if speed >= roachComp.crushThreshold {
            // Crush! Remove roach and update score
            roach.removeFromParent()
            gameState.crushRoach()
            hapticManager?.playCrush()
        } else {
            // Game over — too slow
            DispatchQueue.main.async {
                gameState.triggerGameOver()
            }
        }
    }

    func cancel() {
        collisionSubscription?.cancel()
        collisionSubscription = nil
    }
}
