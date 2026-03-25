import SwiftUI

struct VignetteView: View {
    let baitCount: Int

    // MARK: - Tunable

    private static let maxBait:    Int    = 4
    private static let opacitySteps: [Double] = [0.30, 0.55, 0.75, 0.90]
    private static let reachSteps:   [Double] = [0.12, 0.25, 0.40, 0.55]
    private static let gasColor = Color(red: 0.05, green: 0.40, blue: 0.05)

    // MARK: - Computed

    private var opacity: Double {
        guard baitCount > 0 else { return 0 }
        let idx = min(baitCount - 1, Self.opacitySteps.count - 1)
        return Self.opacitySteps[idx]
    }

    private var reach: Double {
        guard baitCount > 0 else { return 0 }
        let idx = min(baitCount - 1, Self.reachSteps.count - 1)
        return Self.reachSteps[idx]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Top
            LinearGradient(
                colors: [Self.gasColor.opacity(opacity), .clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: reach)
            )
            // Bottom
            LinearGradient(
                colors: [Self.gasColor.opacity(opacity), .clear],
                startPoint: .bottom,
                endPoint: .init(x: 0.5, y: 1.0 - reach)
            )
            // Left
            LinearGradient(
                colors: [Self.gasColor.opacity(opacity), .clear],
                startPoint: .leading,
                endPoint: .init(x: reach, y: 0.5)
            )
            // Right
            LinearGradient(
                colors: [Self.gasColor.opacity(opacity), .clear],
                startPoint: .trailing,
                endPoint: .init(x: 1.0 - reach, y: 0.5)
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.8), value: baitCount)
    }
}
