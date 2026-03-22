import RealityKit
import Foundation
import simd

/// Translates joystick and look-drag input into player velocity + camera yaw.
class MotionController: ObservableObject {

    // MARK: - State

    private(set) var cameraYaw: Float = .pi

    private weak var player: ModelEntity?

    /// Last joystick axes set by applyJoystickInput.
    private var joystickDX: Float = 0
    private var joystickDZ: Float = 0

    /// When true, tickMovement() is a no-op and player velocity is zeroed.
    private(set) var frozen: Bool = false

    // MARK: - Tuning

    let moveSensitivity: Float = 18.0
    let maxSpeed:        Float = 20.0
    let moveSmoothing:   Float = 0.18
    let lookSensitivity: Float = 0.005

    // MARK: - Setup

    func attach(to entity: ModelEntity) {
        player = entity
    }

    // MARK: - Freeze / Unfreeze

    /// Instantly stops all player movement and ignores further input.
    /// Call when the game is won or lost.
    func freeze() {
        frozen     = true
        joystickDX = 0
        joystickDZ = 0

        // Zero out physics velocity so the player stops immediately
        guard let player = player else { return }
        var motion = player.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        motion.linearVelocity  = .zero
        motion.angularVelocity = .zero
        player.components[PhysicsMotionComponent.self] = motion
    }

    /// Re-enables movement (call on game restart).
    func unfreeze() {
        frozen = false
    }

    // MARK: - Look (right thumb)

    func applyLookDelta(screenDX: Float) {
        guard !frozen else { return }
        cameraYaw -= screenDX * lookSensitivity
    }

    // MARK: - Movement (left thumb / joystick)

    func applyJoystickInput(dx: Float, dz: Float) {
        guard !frozen else { return }
        joystickDX = dx
        joystickDZ = dz
    }

    /// Call every frame from tickCamera (SceneEvents.Update).
    func tickMovement() {
        guard !frozen else { return }
        guard let player = player else { return }
        guard abs(joystickDX) > 0.001 || abs(joystickDZ) > 0.001 else { return }

        let θ = cameraYaw
        let targetVx = ( joystickDX * cos(θ) + joystickDZ * sin(θ)) * moveSensitivity
        let targetVz = (-joystickDX * sin(θ) + joystickDZ * cos(θ)) * moveSensitivity

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
