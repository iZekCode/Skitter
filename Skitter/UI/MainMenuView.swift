import SwiftUI

/// Dark-themed main menu with play button and best score
struct MainMenuView: View {
    @Environment(AppState.self) private var appState
    @State private var pulseAnimation = false
    @State private var showTitle = false

    var body: some View {
        ZStack {
            // Dark background with subtle gradient
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

            // Subtle green gas particles (simulated with circles)
            gasParticles

            VStack(spacing: 0) {
                Spacer()

                // Logo section
                VStack(spacing: 8) {
                    // Ball icon
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color(red: 0.6, green: 0.55, blue: 0.3).opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .scaleEffect(pulseAnimation ? 1.05 : 0.95)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )

                    // Title
                    Text("SKITTER")
                        .font(.system(size: 42, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .kerning(16)

                    Text("SURVIVE THE SWARM")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                        .kerning(6)
                }
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 10)

                // Best score
                if appState.bestTime > 0 {
                    VStack(spacing: 4) {
                        Text("BEST")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.3))
                            .kerning(3)

                        Text(formatTime(appState.bestTime))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 24)
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
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            pulseAnimation = true
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                showTitle = true
            }
        }
    }

    private var gasParticles: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(Color(red: 0.1, green: 0.4, blue: 0.1).opacity(0.03))
                    .frame(width: CGFloat.random(in: 80...200))
                    .offset(
                        x: CGFloat.random(in: -200...200),
                        y: CGFloat.random(in: -100...200)
                    )
                    .blur(radius: 30)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
