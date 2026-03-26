import SwiftUI

struct HUDView: View {
    let gameState: GameState
    let labelState: BagTriggerLabelState
    let cameraYaw: Float

    var body: some View {
        ZStack {
            // Top bar
            VStack {
                HStack(alignment: .top) {

                    // Left — minimap + bag dots
                    VStack(alignment: .leading, spacing: 6) {
                        MiniMapView(
                            playerPosition: playerPosition,
                            roachPositions: gameState.roachPositions, 
                            cameraYaw:      cameraYaw
                        )
                        BagsRemainingView(bagsRemaining: gameState.bagsRemaining)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 12)

                    Spacer()

                    // Right — timer
                    Text(gameState.formattedTime)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.trailing, 16)
                        .padding(.top, 12)
                }

                Spacer()
            }

            // Center — trigger label
            TriggerLabelView(labelState: labelState)
        }
    }

    private var playerPosition: SIMD3<Float> {
        gameState.playerPosition
    }
}
