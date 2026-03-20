import RealityKit
import Foundation
import simd

/// Translates joystick and look-drag input into player velocity + camera yaw.
///
/// Owns `cameraYaw` so both the joystick (needs yaw to rotate input into world
/// space) and the look drag (writes yaw) share the same source of truth.
/// GameView reads `cameraYaw` every frame to orient the PerspectiveCamera.
class MotionController: ObservableObject {

    // MARK: - State

    /// Current camera yaw, radians. Written by the right-thumb look drag,
    /// read by GameView each frame and by applyJoystickInput to keep movement
    /// relative to where the player is looking.
    private(set) var cameraYaw: Float = .pi   // start facing +Z ("forward" in arena)

    private weak var player: ModelEntity?

    // MARK: - Tuning

    let moveSensitivity: Float = 18.0
    let maxSpeed:        Float = 20.0
    let moveSmoothing:   Float = 0.18

    /// Radians per screen-point of right-thumb drag.
    /// 0.005 ≈ full 180° turn over ~630pt — responsive but not twitchy.
    let lookSensitivity: Float = 0.005

    // MARK: - Setup

    func attach(to entity: ModelEntity) {
        player = entity
    }

    // MARK: - Look (right thumb)

    /// Call each frame with the delta screen-X from the right-side drag.
    /// Positive screenDX (drag right) → cameraYaw increases → player turns right.
    func applyLookDelta(screenDX: Float) {
        cameraYaw -= screenDX * lookSensitivity
    }

    // MARK: - Movement (left thumb / joystick)

    /// Normalised joystick axes in –1…+1:
    ///   dx  positive = pushed right on screen
    ///   dz  positive = pushed down on screen (= moving backward)
    ///
    /// The input vector is rotated by `cameraYaw` so movement is always
    /// relative to the camera's facing direction, not absolute world axes.
    func applyJoystickInput(dx: Float, dz: Float) {
        guard let player = player else { return }

        // Decompose joystick into camera-local axes, then rotate into world space.
        // cameraForward = (−sinθ, 0, −cosθ)
        // cameraRight   = ( cosθ, 0, −sinθ)
        // worldV = dx*(cameraRight) + (−dz)*(cameraForward)
        let θ = cameraYaw
        let targetVx = ( dx * cos(θ) + dz * sin(θ)) * moveSensitivity
        let targetVz = (-dx * sin(θ) + dz * cos(θ)) * moveSensitivity

        var motion   = player.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        var velocity = motion.linearVelocity
        velocity.x  += (targetVx - velocity.x) * moveSmoothing
        velocity.z  += (targetVz - velocity.z) * moveSmoothing
        velocity.y   = 0

        clampAndApply(velocity: velocity, to: player)
    }

    // MARK: - Private

    private func clampAndApply(velocity: SIMD3<Float>, to entity: ModelEntity) {
        var v = velocity
        let lateral = length(SIMD2<Float>(v.x, v.z))
        if lateral > maxSpeed {
            let s = maxSpeed / lateral
            v.x *= s
            v.z *= s
        }
        var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        motion.linearVelocity = v
        entity.components[PhysicsMotionComponent.self] = motion
    }
}
