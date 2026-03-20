import SwiftUI

/// Fixed virtual analog joystick — sits in the bottom-left corner of the HUD.
///
/// Reports normalised (–1 … +1) X/Z axes to `onInput` every drag change.
/// Sends (0, 0) on release so MotionController can bleed velocity via damping.
struct JoystickView: View {

    /// Called with (dx, dz) where each axis is in –1 … +1.
    /// dx: left/right,  dz: forward/backward (positive = down-screen = backward)
    let onInput: (Float, Float) -> Void

    // ── Geometry ──────────────────────────────────────────────────────────────
    private let baseRadius:  CGFloat = 56
    private let knobRadius:  CGFloat = 26

    @State private var knobOffset: CGSize = .zero
    @State private var isActive: Bool = false

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(Color.black.opacity(isActive ? 0.45 : 0.25))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isActive ? 0.35 : 0.18), lineWidth: 1.5)
                )
                .frame(width: baseRadius * 2, height: baseRadius * 2)

            // Knob
            Circle()
                .fill(Color.white.opacity(isActive ? 0.65 : 0.40))
                .frame(width: knobRadius * 2, height: knobRadius * 2)
                .offset(knobOffset)
        }
        .frame(width: baseRadius * 2, height: baseRadius * 2)
        .contentShape(Circle().scale(1.2))   // slightly larger hit area
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    isActive = true

                    let rawX = value.translation.width
                    let rawZ = value.translation.height
                    let dist = sqrt(rawX * rawX + rawZ * rawZ)
                    let clamped = min(dist, baseRadius)
                    let angle = atan2(rawZ, rawX)

                    let clampedX = clamped * cos(angle)
                    let clampedZ = clamped * sin(angle)

                    knobOffset = CGSize(width: clampedX, height: clampedZ)

                    // Normalise and send — apply a small dead zone at the centre
                    let normX = Float(clampedX / baseRadius)
                    let normZ = Float(clampedZ / baseRadius)
                    let magnitude = sqrt(normX * normX + normZ * normZ)
                    if magnitude > 0.08 {
                        onInput(normX, normZ)
                    } else {
                        onInput(0, 0)
                    }
                }
                .onEnded { _ in
                    isActive = false
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        knobOffset = .zero
                    }
                    onInput(0, 0)
                }
        )
    }
}
