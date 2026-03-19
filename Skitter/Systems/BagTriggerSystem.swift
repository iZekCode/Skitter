import RealityKit
import Combine
import Foundation
import SwiftUI

// MARK: - Trigger Label State

/// Published to the HUD so it can show a brief label after a bag is triggered.
/// "BAYGON" in green, or "TUMPUKAN BUSUK" in red — visible for ~1.5 seconds.
@Observable
class BagTriggerLabelState {
    var message: String = ""
    var isVisible: Bool = false
    var isWin: Bool = false

    private var hideTask: DispatchWorkItem?

    func show(message: String, isWin: Bool) {
        hideTask?.cancel()
        self.message = message
        self.isWin = isWin
        self.isVisible = true

        let task = DispatchWorkItem { [weak self] in
            self?.isVisible = false
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }
}

// MARK: - Bag Trigger System

/// Listens for CollisionEvents between the player and mystery bags.
/// On contact:
///   - Marks the bag as triggered (prevents double-firing)
///   - Shows a HUD label briefly
///   - If baygon   → triggers win
///   - If bait     → spawns new roaches + increments bait count
class BagTriggerSystem {
    private var collisionSubscription: (any Cancellable)?
    private weak var gameState: GameState?
    private weak var hapticManager: HapticManager?
    private weak var bagParent: Entity?       // the entity bags are children of
    let labelState = BagTriggerLabelState()

    init(
        scene: RealityKit.Scene,
        gameState: GameState,
        hapticManager: HapticManager?,
        bagParent: Entity
    ) {
        self.gameState    = gameState
        self.hapticManager = hapticManager
        self.bagParent    = bagParent

        collisionSubscription = scene.subscribe(to: CollisionEvents.Began.self) { [weak self] event in
            self?.handleCollision(event)
        }
    }

    private func handleCollision(_ event: CollisionEvents.Began) {
        guard let gameState = gameState, !gameState.isGameOver else { return }

        let a = event.entityA
        let b = event.entityB

        // One entity must be the player, the other a mystery bag
        let playerInvolved = a.name == "player" || b.name == "player"
        guard playerInvolved else { return }

        let other = a.name == "player" ? b : a
        guard other.name.starts(with: "mysteryBag"),
              var bagComp = other.components[MysteryBagComponent.self],
              !bagComp.hasTriggered
        else { return }

        // Mark as triggered immediately to prevent double-fire
        bagComp.hasTriggered = true
        other.components[MysteryBagComponent.self] = bagComp

        DispatchQueue.main.async { [weak self] in
            self?.executeTrigger(for: bagComp.bagType, bagEntity: other)
        }
    }

    private func executeTrigger(for bagType: BagType, bagEntity: Entity) {
        guard let gameState = gameState else { return }

        // Update remaining bag count
        gameState.bagsRemaining = max(0, gameState.bagsRemaining - 1)

        switch bagType {

        case .baygon:
            // ── WIN ──────────────────────────────────────────────────────────
            labelState.show(message: "BAYGON!", isWin: true)
            hapticManager?.playBaygonWin()

            // Short delay so the player sees the label before the screen changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                gameState.triggerWin()
                self?.hapticManager?.playGameOver() // reuse ramp-down for now
            }

        case .bait:
            // ── BAIT — escalation ────────────────────────────────────────────
            gameState.baitTriggeredCount += 1
            labelState.show(message: "TUMPUKAN BUSUK", isWin: false)
            hapticManager?.playBaitTrigger()

            // Remove the bag visually — it's been "opened"
            bagEntity.removeFromParent()
        }   
    }

    // MARK: - Escalation spawn

    /// Each bait trigger spawns progressively more roaches.
    /// Phase 2: Chaser only. Giant & Flying come in Phase 3.
    private func spawnEscalationRoaches(baitCount: Int) {
        guard let parent = bagParent else { return }

        // Scale up pressure with each bait triggered
        let count: Int
        switch baitCount {
        case 1:  count = 3
        case 2:  count = 4
        case 3:  count = 5
        default: count = 6   // bait 4+ — swarming
        }

        for _ in 0..<count {
            let pos = RoachEntity.randomEdgePosition()
            let roach = RoachEntity.createChaser(at: pos)
            parent.addChild(roach)
        }
    }

    func cancel() {
        collisionSubscription?.cancel()
        collisionSubscription = nil
    }
}
