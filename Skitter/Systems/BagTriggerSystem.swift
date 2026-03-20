import RealityKit
import Combine
import Foundation
import SwiftUI

// MARK: - Trigger Label State

/// Published to the HUD so it can show a brief label after a bag is triggered.
@Observable
class BagTriggerLabelState {
    var message:   String = ""
    var isVisible: Bool   = false
    var isWin:     Bool   = false

    private var hideTask: DispatchWorkItem?

    func show(message: String, isWin: Bool) {
        hideTask?.cancel()
        self.message   = message
        self.isWin     = isWin
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
class BagTriggerSystem {
    private var collisionSubscription: (any Cancellable)?
    private weak var gameState:     GameState?
    private weak var hapticManager: HapticManager?
    private weak var bagParent:     Entity?
    let labelState = BagTriggerLabelState()

    init(
        scene:          RealityKit.Scene,
        gameState:      GameState,
        hapticManager:  HapticManager?,
        bagParent:      Entity
    ) {
        self.gameState     = gameState
        self.hapticManager = hapticManager
        self.bagParent     = bagParent

        collisionSubscription = scene.subscribe(to: CollisionEvents.Began.self) { [weak self] event in
            self?.handleCollision(event)
        }
    }

    // MARK: - Collision handling

    private func handleCollision(_ event: CollisionEvents.Began) {
        guard let gameState = gameState, !gameState.isGameOver else { return }

        let a = event.entityA
        let b = event.entityB

        let playerInvolved = a.name == "player" || b.name == "player"
        guard playerInvolved else { return }

        let other = a.name == "player" ? b : a
        guard other.name.starts(with: "mysteryBag"),
              var bagComp = other.components[MysteryBagComponent.self],
              !bagComp.hasTriggered
        else { return }

        bagComp.hasTriggered = true
        other.components[MysteryBagComponent.self] = bagComp

        DispatchQueue.main.async { [weak self] in
            self?.executeTrigger(for: bagComp.bagType, bagEntity: other)
        }
    }

    // MARK: - Execute trigger

    private func executeTrigger(for bagType: BagType, bagEntity: Entity) {
        guard let gameState = gameState else { return }

        gameState.bagsRemaining = max(0, gameState.bagsRemaining - 1)

        // ── Swap the bag's visual to the reveal model ─────────────────────────
        // Remove the black plastic children, add the reveal model in their place
        for child in bagEntity.children { child.removeFromParent() }

        if let reveal = MysteryBagEntity.createRevealEntity(for: bagType) {
            reveal.position = .zero
            bagEntity.addChild(reveal)
        }

        switch bagType {

        // ── WIN ───────────────────────────────────────────────────────────────
        case .baygon:
            labelState.show(message: "BAYGON!", isWin: true)
            hapticManager?.playBaygonWin()

            // Short pause so the player sees both the label and the byegone model
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                gameState.triggerWin()
                self?.hapticManager?.playGameOver()  // ramp-down for transition feel
            }

        // ── BAIT ──────────────────────────────────────────────────────────────
        case .bait:
            gameState.baitTriggeredCount += 1
            labelState.show(message: "TUMPUKAN BUSUK", isWin: false)
            hapticManager?.playBaitTrigger()

            // Remove the food pile reveal after 1.5 s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                bagEntity.removeFromParent()
            }
        }
    }

    // MARK: - Teardown

    func cancel() {
        collisionSubscription?.cancel()
        collisionSubscription = nil
    }
}
