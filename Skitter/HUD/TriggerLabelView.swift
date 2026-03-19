import SwiftUI

/// Brief center-screen label shown right after a bag collision.
/// "BAYGON!" in green (win) or "TUMPUKAN BUSUK" in red (bait).
/// Auto-hides after ~1.8 seconds via BagTriggerLabelState.
struct TriggerLabelView: View {
    let labelState: BagTriggerLabelState

    var body: some View {
        if labelState.isVisible {
            Text(labelState.message)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(labelState.isWin ? Color.green : Color(red: 0.9, green: 0.2, blue: 0.2))
                .kerning(4)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.easeOut(duration: 0.2), value: labelState.isVisible)
        }
    }
}
