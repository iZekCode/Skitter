import RealityKit
import Foundation

/// Observes baitTriggeredCount on GameState and reacts to each new trigger.
///
/// Phase 2 scope — Chaser only:
/// - Each bait trigger spawns a wave of new Chasers
/// - Speed of all active roaches increases slightly each trigger
///
/// Phase 3 will add Giant & Flying upgrades on top of this.
class EscalationSystem {
    private weak var gameState: GameState?
    private weak var roachParent: Entity?

    /// Track which bait count we've already reacted to — prevents double-firing
    private var lastHandledBaitCount: Int = 0

    /// Poll timer — checks gameState for new bait triggers every 0.2s.
    /// Using a timer instead of Combine/observation keeps this self-contained.
    private var pollTimer: Timer?

    /// Speed multiplier applied to all active roaches per bait trigger.
    private static let speedBumpPerBait: Float = 0.15   // +15% each trigger

    init(gameState: GameState, roachParent: Entity) {
        self.gameState   = gameState
        self.roachParent = roachParent

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkEscalation()
        }
    }

    // MARK: - Poll

    private func checkEscalation() {
        guard let gameState = gameState, !gameState.isGameOver else { return }
        guard gameState.baitTriggeredCount > lastHandledBaitCount else { return }

        // One or more new bait triggers since last check
        let newTriggers = gameState.baitTriggeredCount - lastHandledBaitCount
        for _ in 0..<newTriggers {
            lastHandledBaitCount += 1
            handleEscalationTick(baitCount: lastHandledBaitCount)
        }
    }

    // MARK: - Escalation logic per bait

    private func handleEscalationTick(baitCount: Int) {
        guard let parent = roachParent else { return }

        // ── Spawn wave ───────────────────────────────────────────────────────
        let spawnCount: Int
        switch baitCount {
        case 1:  spawnCount = 3
        case 2:  spawnCount = 4
        case 3:  spawnCount = 5
        default: spawnCount = 6
        }

        for _ in 0..<spawnCount {
            let pos = RoachEntity.randomEdgePosition()
            let roach = RoachEntity.createChaser(at: pos)
            parent.addChild(roach)
        }

        // ── Speed bump all active roaches ────────────────────────────────────
        // Walk every existing roach and increase its speed component.
        // RoachAISystem reads speed from RoachComponent every frame,
        // so this takes effect immediately next update.
        bumpActiveRoachSpeeds(in: parent)

        print("[EscalationSystem] Bait \(baitCount): spawned \(spawnCount) chasers, speed bumped")
    }

    // MARK: - Speed bump

    private func bumpActiveRoachSpeeds(in parent: Entity) {
        for child in parent.children {
            guard var roachComp = child.components[RoachComponent.self] else { continue }
            roachComp.speed *= (1.0 + Self.speedBumpPerBait)
            child.components[RoachComponent.self] = roachComp
        }
    }

    // MARK: - Teardown

    func cancel() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
