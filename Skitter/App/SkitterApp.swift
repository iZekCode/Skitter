import SwiftUI

@main
struct SkitterApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch appState.currentScreen {
            case .menu:
                MainMenuView()
                    .transition(.opacity)
            case .playing:
                GameView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.currentScreen)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}
