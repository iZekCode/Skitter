import Foundation

enum DifficultyLevel: String, CaseIterable {
    case newbie = "NEWBIE"
    case pro    = "PRO"
}

struct EscalationWave {
    let giants: Int
    let flying: Int
    let applySpeedBump: Bool
}

struct DifficultySettings {
    let roachSpeedMultiplier: Float
    let totalBags:            Int
    let initialRoachCount:    Int
    let roachSpawnInterval:   Double
    let escalationWaves:      [Int: EscalationWave]
    let defaultWave:          EscalationWave
    let speedBumpPerBait:     Float

    static let newbie = DifficultySettings(
        roachSpeedMultiplier: 0.60,
        totalBags:            3,
        initialRoachCount:    2,
        roachSpawnInterval:   4.0,
        escalationWaves: [
            1: EscalationWave(giants: 2, flying: 0, applySpeedBump: false),
            2: EscalationWave(giants: 1, flying: 2, applySpeedBump: false),
        ],
        defaultWave:      EscalationWave(giants: 0, flying: 2, applySpeedBump: false),
        speedBumpPerBait: 0.08
    )

    static let pro = DifficultySettings(
        roachSpeedMultiplier: 1.00,
        totalBags:            5,
        initialRoachCount:    4,
        roachSpawnInterval:   2.0,
        escalationWaves: [
            1: EscalationWave(giants: 3, flying: 0, applySpeedBump: false),
            2: EscalationWave(giants: 2, flying: 3, applySpeedBump: false),
            3: EscalationWave(giants: 1, flying: 4, applySpeedBump: true),
        ],
        defaultWave:      EscalationWave(giants: 0, flying: 5, applySpeedBump: true),
        speedBumpPerBait: 0.15
    )

    static func settings(for level: DifficultyLevel) -> DifficultySettings {
        switch level {
        case .newbie: return .newbie
        case .pro:    return .pro
        }
    }
}
