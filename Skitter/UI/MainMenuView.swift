import SwiftUI

struct MainMenuView: View {
    @Environment(AppState.self) private var appState
    @State private var pulseAnimation = false
    @State private var showTitle = false

    var body: some View {
        ZStack {
            // Dark background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.04),
                    Color(red: 0.05, green: 0.04, blue: 0.02),
                    Color(red: 0.02, green: 0.02, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo section
                VStack(spacing: 8) {
                    Text("SKITTER")
                        .font(.system(size: 42, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .kerning(16)

                    Text("SURVIVE THE SWARM")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                        .kerning(6)
                }

                Spacer()
                
                // Best score
                if appState.bestWinTime > 0 {
                    VStack(spacing: 6) {
                        Text("BEST RUN")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                            .kerning(3)

                        Text(formatTime(appState.bestWinTime))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))

                        Text("\(appState.bestBagsOpened)/5 BAGS OPENED")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                            .kerning(2)
                    }
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    // Play button
                    Button(action: {
                        appState.startGame()
                    }) {
                        Text("PLAY")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .kerning(6)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
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
                    .frame(maxWidth: 360)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
        .onAppear {
            pulseAnimation = true
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                showTitle = true
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes     = Int(time) / 60
        let seconds     = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}
