import RealityKit
import Foundation
import simd

/// Translates joystick and look-drag input into player velocity + camera yaw.
class MotionController: ObservableObject {

    // MARK: - State

    private(set) var cameraYaw: Float = .pi

    private weak var player: ModelEntity?

    /// Last joystick axes set by applyJoystickInput.
    /// Stored so tickMovement() can re-apply them every frame even when
    /// the gesture's onChanged stops firing (thumb held still).
    private var joystickDX: Float = 0
    private var joystickDZ: Float = 0

    // MARK: - Tuning

    let moveSensitivity: Float = 18.0
    let maxSpeed:        Float = 20.0
    let moveSmoothing:   Float = 0.18
    let lookSensitivity: Float = 0.005

    // MARK: - Setup

    func attach(to entity: ModelEntity) {
        player = entity
    }

    // MARK: - Look (right thumb)

    func applyLookDelta(screenDX: Float) {
        cameraYaw -= screenDX * lookSensitivity
    }

    // MARK: - Movement (left thumb / joystick)

    /// Called by the gesture's onChanged — just stores the axes.
    /// Actual velocity is applied every frame by tickMovement().
    func applyJoystickInput(dx: Float, dz: Float) {
        joystickDX = dx
        joystickDZ = dz
    }

    /// Call every frame from tickCamera (SceneEvents.Update).
    /// Re-applies the stored joystick axes so the character keeps
    /// moving even when the thumb is held still and onChanged stops firing.
    func tickMovement() {
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
