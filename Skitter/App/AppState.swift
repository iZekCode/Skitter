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

    var bestWinTime: TimeInterval {
        get { UserDefaults.standard.double(forKey: "bestWinTime") }
        set { UserDefaults.standard.set(newValue, forKey: "bestWinTime") }
    }

    var bestBagsOpened: Int {
        get { UserDefaults.standard.integer(forKey: "bestBagsOpened") }
        set { UserDefaults.standard.set(newValue, forKey: "bestBagsOpened") }
    }

    func startGame() {
        currentScreen = .playing
    }

    func endGame(survivedTime: TimeInterval, isWin: Bool, bagsOpened: Int) {
        lastSurvivedTime = survivedTime
        lastBagsOpened   = bagsOpened
        lastIsWin        = isWin

        if isWin {
            if bestWinTime == 0 || survivedTime < bestWinTime {
                bestWinTime  = survivedTime
                bestBagsOpened = bagsOpened
            }
        }
        currentScreen = .menu
    }

    func returnToMenu() {
        currentScreen = .menu
    }
}
