import SwiftUI
import RealityKit
import Combine

enum GamePhase: Equatable {
    case countdown
    case playing
    case gameOver
}

@Observable
class GameState {
    var gamePhase: GamePhase = .countdown
    var elapsedTime: TimeInterval = 0
    var isGameOver: Bool = false
    var ballSpeed: Float = 0
    
    var playerPosition: SIMD3<Float> = .zero
    
    var baitTriggeredCount: Int = 0
    var bagsRemaining: Int = 5
    var isWin: Bool = false

    // Track the RealityKit scene for system access
    weak var scene: RealityKit.Scene?

    private var gameTimer: Timer?
    private var startDate: Date?

    var formattedTime: String {
        let minutes      = Int(elapsedTime) / 60
        let seconds      = Int(elapsedTime) % 60
        let milliseconds = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }

    func startGame() {
        gamePhase = .playing
        elapsedTime = 0
        isGameOver = false
        startDate = Date()

        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, !self.isGameOver else { return }
            self.elapsedTime = Date().timeIntervalSince(self.startDate ?? Date())
        }
    }
    
    func triggerWin() {
        guard !isWin else { return }
        isWin = true
        isGameOver = true
        gamePhase = .gameOver
        gameTimer?.invalidate()
        gameTimer = nil
    }

    func triggerGameOver() {
        guard !isGameOver else { return }
        isGameOver = true
        gamePhase = .gameOver
        gameTimer?.invalidate()
        gameTimer = nil
    }

    func reset() {
        gameTimer?.invalidate()
        gameTimer = nil
        gamePhase = .countdown
        elapsedTime = 0
        isGameOver = false
        ballSpeed = 0
        startDate = nil
        baitTriggeredCount = 0
        bagsRemaining = 5
        isWin = false
    }
}
