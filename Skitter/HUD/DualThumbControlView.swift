import SwiftUI

struct DualThumbControlView: View {

    /// Left thumb
    let onMovement: (_ dx: Float, _ dz: Float) -> Void

    /// Right thumb
    let onLook: (_ screenDX: Float) -> Void

    // Joystick geometry
    private let baseRadius:  CGFloat = 58
    private let knobRadius:  CGFloat = 22
    private let deadZone:    Float   = 0.06

    // Joystick state
    @State private var joystickOrigin: CGPoint = .zero
    @State private var knobOffset:     CGSize  = .zero
    @State private var joystickActive: Bool    = false

    // Look state
    @State private var prevLookTranslationX: CGFloat = 0
    @State private var lookActive: Bool = false

    var body: some View {
        HStack(spacing: 0) {

            // Left zone
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(movementGesture)

                // Joystick visual
                if joystickActive {
                    ZStack {
                        // Base ring
                        Circle()
                            .fill(Color.black.opacity(0.35))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.30), lineWidth: 1.5)
                            )
                            .frame(width: baseRadius * 2, height: baseRadius * 2)

                        // Knob
                        Circle()
                            .fill(Color.white.opacity(0.60))
                            .frame(width: knobRadius * 2, height: knobRadius * 2)
                            .offset(knobOffset)
                    }
                    .position(joystickOrigin)
                    .allowsHitTesting(false)
                } else {
                    // Idle ring
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        .frame(width: baseRadius * 2, height: baseRadius * 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottomLeading)
                        .padding(.leading, 32)
                        .padding(.bottom, 32)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Right zone
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(lookGesture)

                // Idle hint
                if !lookActive {
                    lookHint
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Movement gesture

    private var movementGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if !joystickActive {
                    joystickActive  = true
                    joystickOrigin  = value.startLocation
                }

                // Raw offset from where the thumb first touched
                let rawX = value.location.x - joystickOrigin.x
                let rawY = value.location.y - joystickOrigin.y
                let dist = sqrt(rawX * rawX + rawY * rawY)

                let clamped = min(dist, baseRadius)
                let angle   = atan2(rawY, rawX)

                let cx = clamped * cos(angle)
                let cy = clamped * sin(angle)

                knobOffset = CGSize(width: cx, height: cy)

                // Normalise and apply dead zone
                let normDX = Float(cx / baseRadius)
                let normDZ = Float(cy / baseRadius)
                let mag    = sqrt(normDX * normDX + normDZ * normDZ)

                if mag > deadZone {
                    onMovement(normDX, normDZ)
                } else {
                    onMovement(0, 0)
                }
            }
            .onEnded { _ in
                joystickActive = false
                withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
                    knobOffset = .zero
                }
                onMovement(0, 0)
            }
    }

    // MARK: - Look gesture

    private var lookGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                lookActive = true
                let delta = value.translation.width - prevLookTranslationX
                prevLookTranslationX = value.translation.width
                onLook(Float(delta))
            }
            .onEnded { _ in
                lookActive = false
                prevLookTranslationX = 0
            }
    }

    // MARK: - Look hint

    private var lookHint: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 14, height: 1)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 14)
        }
    }
}
