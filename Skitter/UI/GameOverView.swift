import SwiftUI

/// Game over screen with stats and replay/menu buttons
struct GameOverView: View {
    @Environment(AppState.self) private var appState
    @State private var showStats = false

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.02, green: 0.01, blue: 0.03)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Header
                Text("GAME OVER")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.85, green: 0.15, blue: 0.15))
                    .kerning(10)

                // Stat cards — 2x2 grid
                LazyVGrid(columns: [
                    GridItem(.fixed(150)),
                    GridItem(.fixed(150))
                ], spacing: 12) {
                    statCard(
                        title: "SURVIVED",
                        value: formatTime(appState.lastSurvivedTime),
                        icon: "clock"
                    )
                    statCard(
                        title: "CRUSHED",
                        value: "\(appState.lastCrushedCount)",
                        icon: "ant"
                    )
                    statCard(
                        title: "BEST",
                        value: formatTime(appState.bestTime),
                        icon: "trophy"
                    )
                    statCard(
                        title: "SPEED",
                        value: "--",
                        icon: "gauge.high"
                    )
                }
                .opacity(showStats ? 1 : 0)
                .offset(y: showStats ? 0 : 30)

                Spacer()

                // Buttons
                VStack(spacing: 10) {
                    Button(action: {
                        appState.startGame()
                    }) {
                        Text("PLAY AGAIN")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .kerning(4)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.45, green: 0.65, blue: 0.25),
                                        Color(red: 0.35, green: 0.55, blue: 0.18)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button(action: {
                        appState.returnToMenu()
                    }) {
                        Text("MENU")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                showStats = true
            }
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.3))

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))

            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
                .kerning(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
