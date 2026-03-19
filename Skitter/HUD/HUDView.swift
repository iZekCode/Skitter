import SwiftUI

/// In-game HUD overlay — timer and crushed counter
struct HUDView: View {
    let gameState: GameState

    var body: some View {
        VStack {
            // Top bar
            HStack {
                Spacer()

                // Timer — center
                Text(gameState.formattedTime)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Spacer()

                // Crush speed indicator — right
                crushSpeedIndicator
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            // Bottom bar — speed meter
            HStack {
                speedMeter
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    private var crushSpeedIndicator: some View {
        let speed = gameState.ballSpeed
        let threshold: Float = 6.0 
        let canCrush = speed >= threshold

        return HStack(spacing: 4) {
            Image(systemName: canCrush ? "bolt.fill" : "bolt")
                .font(.system(size: 12))
                .foregroundStyle(canCrush ? Color.green : Color.red.opacity(0.6))

            Text(canCrush ? "CRUSH" : "SLOW")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(canCrush ? Color.green : Color.red.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var speedMeter: some View {
        let speed = gameState.ballSpeed
        let threshold: Float = 6.0
        let ratio = min(CGFloat(speed / threshold), 1.0)

        return HStack(spacing: 2) {
            ForEach(0..<10, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(index: i, ratio: ratio))
                    .frame(width: 6, height: 14)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func barColor(index: Int, ratio: CGFloat) -> Color {
        let barThreshold = CGFloat(index) / 10.0
        if ratio >= barThreshold {
            if ratio >= 1.0 {
                return Color.green
            } else if ratio >= 0.6 {
                return Color.yellow
            } else {
                return Color.red.opacity(0.7)
            }
        }
        return Color.white.opacity(0.1)
    }
}
