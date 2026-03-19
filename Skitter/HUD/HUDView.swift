import SwiftUI

/// In-game HUD overlay — Phase 2 layout
///
/// Top-left:  Mini map + bags remaining
/// Top-right: Timer
/// Center:    Trigger label (fades in/out after bag collision)
struct HUDView: View {
    let gameState: GameState
    let labelState: BagTriggerLabelState

    var body: some View {
        ZStack {
            // ── Top bar ───────────────────────────────────────────────────────
            VStack {
                HStack(alignment: .top) {

                    // Left — minimap + bag dots
                    VStack(alignment: .leading, spacing: 6) {
                        MiniMapView(playerPosition: playerPosition)
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

            // ── Center — trigger label ────────────────────────────────────────
            TriggerLabelView(labelState: labelState)
        }
    }

    /// Pull player position from gameState for the minimap.
    /// Defaults to zero if not yet available.
    private var playerPosition: SIMD3<Float> {
        gameState.playerPosition
    }
}
