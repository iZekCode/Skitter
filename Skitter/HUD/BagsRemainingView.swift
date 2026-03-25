import SwiftUI

struct BagsRemainingView: View {
    let bagsRemaining: Int
    let total: Int = 5

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < bagsRemaining ? Color.white.opacity(0.8) : Color.white.opacity(0.15))
                    .frame(width: 8, height: 8)
                    .animation(.easeOut(duration: 0.2), value: bagsRemaining)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
