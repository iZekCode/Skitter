import RealityKit
import Foundation

class EscalationSystem {
    private weak var gameState:  GameState?
    private weak var roachParent: Entity?
    private weak var audioManager: AudioManager?

    private let difficultySettings: DifficultySettings
    private var lastHandledBaitCount: Int = 0
    private var pollTimer: Timer?

    init(gameState: GameState, roachParent: Entity, audioManager: AudioManager? = nil, difficulty: DifficultySettings = .newbie) {
        self.gameState          = gameState
        self.roachParent        = roachParent
        self.audioManager       = audioManager
        self.difficultySettings = difficulty

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

        let wave = difficultySettings.escalationWaves[baitCount] ?? difficultySettings.defaultWave

        if wave.giants > 0  { spawnWave(parent: parent, count: wave.giants,  type: .giant) }
        if wave.flying > 0  { spawnWave(parent: parent, count: wave.flying,  type: .flying) }
        if wave.applySpeedBump { bumpAllSpeeds(in: parent) }

        print("[EscalationSystem] Bait \(baitCount): +\(wave.giants) Giants +\(wave.flying) Flying speedBump=\(wave.applySpeedBump)")
    }

    // MARK: - Spawn wave

    private enum SpawnType { case chaser, giant, flying }

    private func spawnWave(parent: Entity, count: Int, type: SpawnType) {
        let playerPos = gameState?.playerPosition
        let speedMult = difficultySettings.roachSpeedMultiplier
        
        for _ in 0..<count {
            let pos   = RoachEntity.randomEdgePosition(avoidingPosition: playerPos)
            let roach: ModelEntity
            switch type {
            case .chaser:  roach = RoachEntity.createChaser(at: pos, speedMultiplier: speedMult)
            case .giant:   roach = RoachEntity.createGiant(at: pos,  speedMultiplier: speedMult)
            case .flying:  roach = RoachEntity.createFlying(at: pos,  speedMultiplier: speedMult)
            }
            parent.addChild(roach)
            audioManager?.addRoach(roach)
        }
    }

    // MARK: - Speed bump

    private func bumpAllSpeeds(in parent: Entity) {
        for child in parent.children {
            guard var comp = child.components[RoachComponent.self] else { continue }
            comp.speed *= (1.0 + difficultySettings.speedBumpPerBait)
            child.components[RoachComponent.self] = comp
        }
    }

    // MARK: - Teardown

    func cancel() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
