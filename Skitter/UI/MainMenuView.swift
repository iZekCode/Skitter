import SwiftUI

struct MainMenuView: View {
    @Environment(AppState.self) private var appState
    @State private var pulseAnimation = false
    @State private var showTitle = false
    @State private var selectedDifficulty: DifficultyLevel = .newbie

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
                VStack(spacing: 12) {
                    Text("SKITTER")
                        .font(.system(size: 54, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .kerning(16)

                    Text("Among \(DifficultySettings.settings(for: selectedDifficulty).totalBags) black plastic bags, only 1 contains baygon.\nOpen the wrong plastic bag… and you’ll attract them.\nFind the right one before they get you.")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()
                
                // Difficulty and Best Run side-by-side
                HStack(spacing: 40) {
                    
                    // Difficulty selector
                    VStack(spacing: 10) {
                        Text("DIFFICULTY")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .kerning(3)

                        HStack(spacing: 0) {
                            ForEach(DifficultyLevel.allCases, id: \.self) { level in
                                let isSelected = selectedDifficulty == level
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDifficulty = level
                                    }
                                }) {
                                    Text(level.rawValue)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .kerning(3)
                                        .foregroundStyle(isSelected ? .black : .white.opacity(0.45))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background {
                                            if isSelected {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color(red: 0.45, green: 0.65, blue: 0.25),
                                                                     Color(red: 0.35, green: 0.55, blue: 0.18)],
                                                            startPoint: .top, endPoint: .bottom)
                                                    )
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(width: 240)
                    }
                    
                    // Best score
                    if appState.bestWinTime(for: selectedDifficulty) > 0 {
                        
                        // Vertical Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 1, height: 50)
                        
                        VStack(spacing: 6) {
                            Text("BEST RUN")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .kerning(3)

                            Text(formatTime(appState.bestWinTime(for: selectedDifficulty)))
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))

                            Text("\(appState.bestBagsOpened(for: selectedDifficulty))/\(DifficultySettings.settings(for: selectedDifficulty).totalBags) BAGS OPENED")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .kerning(2)
                        }
                        .frame(minWidth: 160)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: selectedDifficulty)
                    }
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    // Play button
                    Button(action: {
                        appState.startGame(difficulty: selectedDifficulty)
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
