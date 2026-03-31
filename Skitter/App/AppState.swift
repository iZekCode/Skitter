import SwiftUI

enum Screen: Equatable {
    case menu
    case playing
}

@Observable
class AppState {
    var currentScreen: Screen = .menu
    var lastSurvivedTime: TimeInterval = 0
    var lastBagsOpened: Int = 0
    var lastIsWin: Bool = false
    var selectedDifficulty: DifficultyLevel = .newbie

    func bestWinTime(for level: DifficultyLevel) -> TimeInterval {
        UserDefaults.standard.double(forKey: "bestWinTime_\(level.rawValue.lowercased())")
    }

    func bestBagsOpened(for level: DifficultyLevel) -> Int {
        UserDefaults.standard.integer(forKey: "bestBagsOpened_\(level.rawValue.lowercased())")
    }

    private func setBestWinTime(_ value: TimeInterval, for level: DifficultyLevel) {
        UserDefaults.standard.set(value, forKey: "bestWinTime_\(level.rawValue.lowercased())")
    }

    private func setBestBagsOpened(_ value: Int, for level: DifficultyLevel) {
        UserDefaults.standard.set(value, forKey: "bestBagsOpened_\(level.rawValue.lowercased())")
    }

    func startGame(difficulty: DifficultyLevel = .newbie) {
        selectedDifficulty = difficulty
        currentScreen = .playing
    }

    func endGame(survivedTime: TimeInterval, isWin: Bool, bagsOpened: Int) {
        lastSurvivedTime = survivedTime
        lastBagsOpened   = bagsOpened
        lastIsWin        = isWin

        if isWin {
            let currentBest = bestWinTime(for: selectedDifficulty)
            if currentBest == 0 || survivedTime < currentBest {
                setBestWinTime(survivedTime, for: selectedDifficulty)
                setBestBagsOpened(bagsOpened, for: selectedDifficulty)
            }
        }
        currentScreen = .menu
    }

    func returnToMenu() {
        currentScreen = .menu
    }
}
