import RealityKit
import Foundation

class EscalationSystem {
    private weak var gameState:  GameState?
    private weak var roachParent: Entity?
    private weak var audioManager: AudioManager?

    private var lastHandledBaitCount: Int = 0
    private var pollTimer: Timer?

    private static let speedBumpPerBait: Float = 0.15

    init(gameState: GameState, roachParent: Entity, audioManager: AudioManager? = nil) {
        self.gameState    = gameState
        self.roachParent  = roachParent
        self.audioManager = audioManager

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkEscalation()
        }
    }

    // MARK: - Poll

    private func checkEscalation() {
        guard let gameState = gameState, !gameState.isGameOver else { return }
        guard gameState.baitTriggeredCount > lastHandledBaitCount else { return }

        let newTriggers = gameState.baitTriggeredCount - lastHandledBaitCount
        for _ in 0..<newTriggers {
            lastHandledBaitCount += 1
            handleEscalationTick(baitCount: lastHandledBaitCount)
        }
    }

    // MARK: - Escalation per bait

    private func handleEscalationTick(baitCount: Int) {
        guard let parent = roachParent else { return }

        switch baitCount {

        case 1:
            spawnWave(parent: parent, count: 3, type: .giant)
            print("[EscalationSystem] Bait 1: +3 Giants")
         
        case 2:
            spawnWave(parent: parent, count: 2, type: .giant)
            spawnWave(parent: parent, count: 3, type: .flying)
            print("[EscalationSystem] Bait 2: +2 Giants +3 Flying")
         
        case 3:
            spawnWave(parent: parent, count: 1, type: .giant)
            spawnWave(parent: parent, count: 4, type: .flying)
            bumpAllSpeeds(in: parent)
            print("[EscalationSystem] Bait 3: +1 Giant +4 Flying, speed bump")
         
        default:
            spawnWave(parent: parent, count: 5, type: .flying)
            bumpAllSpeeds(in: parent)
            print("[EscalationSystem] Bait \(baitCount): +5 Flying, speed bump")
        }
    }

    // MARK: - Spawn wave

    private enum SpawnType { case chaser, giant, flying }

    private func spawnWave(parent: Entity, count: Int, type: SpawnType) {
        let playerPos = gameState?.playerPosition
        
        for _ in 0..<count {
            let pos   = RoachEntity.randomEdgePosition(avoidingPosition: playerPos)
            let roach: ModelEntity
            switch type {
            case .chaser:  roach = RoachEntity.createChaser(at: pos)
            case .giant:   roach = RoachEntity.createGiant(at: pos)
            case .flying:  roach = RoachEntity.createFlying(at: pos)
            }
            parent.addChild(roach)
            audioManager?.addRoach(roach)
        }
    }

    // MARK: - Speed bump

    private func bumpAllSpeeds(in parent: Entity) {
        for child in parent.children {
            guard var comp = child.components[RoachComponent.self] else { continue }
            comp.speed *= (1.0 + Self.speedBumpPerBait)
            child.components[RoachComponent.self] = comp
        }
    }

    // MARK: - Teardown

    func cancel() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
