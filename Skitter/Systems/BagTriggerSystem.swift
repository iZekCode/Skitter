import RealityKit
import Combine
import Foundation
import SwiftUI

// MARK: - Trigger Label State

@Observable
class BagTriggerLabelState {
    var message:   String = ""
    var isVisible: Bool   = false
    var isWin:     Bool   = false
    var isBait:    Bool   = false

    private var hideTask: DispatchWorkItem?

    func show(message: String, isWin: Bool, isBait: Bool = false) {
        hideTask?.cancel()
        self.message   = message
        self.isWin     = isWin
        self.isBait    = isBait
        self.isVisible = true

        let task = DispatchWorkItem { [weak self] in
            self?.isVisible = false
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }
}

// MARK: - Bag Trigger System

class BagTriggerSystem {
    private var collisionSubscription: (any Cancellable)?
    private weak var gameState:     GameState?
    private weak var hapticManager: HapticManager?
    private weak var audioManager:  AudioManager?
    private weak var bagParent:     Entity?
    var freezePlayer: (() -> Void)?
    let labelState = BagTriggerLabelState()

    init(
        scene:          RealityKit.Scene,
        gameState:      GameState,
        hapticManager:  HapticManager?,
        audioManager:   AudioManager?,
        bagParent:      Entity
    ) {
        self.gameState     = gameState
        self.hapticManager = hapticManager
        self.audioManager  = audioManager
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

        // Swap visual to reveal model
        for child in bagEntity.children { child.removeFromParent() }
        if let reveal = MysteryBagEntity.createRevealEntity(for: bagType) {
            reveal.position = .zero
            bagEntity.addChild(reveal)
        }

        switch bagType {

        case .baygon:
            labelState.show(message: "BYEGONE", isWin: true)
            hapticManager?.playBaygonWin()
            audioManager?.playCorrect()
            freezePlayer?()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                gameState.triggerWin()
                self?.hapticManager?.playGameOver()
                self?.audioManager?.playGameOverWin()
            }

        case .bait:
            gameState.baitTriggeredCount += 1
            labelState.show(message: "FOOD PILE", isWin: false, isBait: true)
            hapticManager?.playBaitTrigger()
            audioManager?.playWrong()

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
