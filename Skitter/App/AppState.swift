import SwiftUI

enum Screen: Equatable {
    case menu
    case playing
    case gameOver
}

@Observable
class AppState {
    var currentScreen: Screen = .menu
    var lastSurvivedTime: TimeInterval = 0
    var lastCrushedCount: Int = 0

    var bestTime: TimeInterval {
        get { UserDefaults.standard.double(forKey: "bestTime") }
        set { UserDefaults.standard.set(newValue, forKey: "bestTime") }
    }

    func startGame() {
        currentScreen = .playing
    }

    func endGame(survivedTime: TimeInterval, crushedCount: Int) {
        lastSurvivedTime = survivedTime
        lastCrushedCount = crushedCount
        if survivedTime > bestTime {
            bestTime = survivedTime
        }
        currentScreen = .gameOver
    }

    func returnToMenu() {
        currentScreen = .menu
    }
}
