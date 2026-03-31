import RealityKit
import Foundation
import simd

class MotionController: ObservableObject {

    // MARK: - State

    private(set) var cameraYaw: Float = .pi

    private weak var player: ModelEntity?

    private var joystickDX: Float = 0
    private var joystickDZ: Float = 0

    private(set) var frozen: Bool = false

    // MARK: - Tuning

    let moveSensitivity: Float = 18.0
    let maxSpeed:        Float = 10.0
    let moveSmoothing:   Float = 0.18
    let lookSensitivity: Float = 0.005

    // MARK: - Setup

    func attach(to entity: ModelEntity) {
        player = entity
    }

    // MARK: - Freeze/Unfreeze

    func freeze() {
        frozen     = true
        joystickDX = 0
        joystickDZ = 0

        guard let player = player else { return }
        var motion = player.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        motion.linearVelocity  = .zero
        motion.angularVelocity = .zero
        player.components[PhysicsMotionComponent.self] = motion
    }

    func unfreeze() {
        frozen = false
    }

    // MARK: - Look (right thumb)

    func applyLookDelta(screenDX: Float) {
        guard !frozen else { return }
        cameraYaw -= screenDX * lookSensitivity
    }

    // MARK: - Movement (left thumb/joystick)

    func applyJoystickInput(dx: Float, dz: Float) {
        guard !frozen else { return }
        joystickDX = dx
        joystickDZ = dz
    }

    /// nerjemahin input joystick ke world-space — supaya "maju" di joystick selalu berarti maju ke arah kamera lagi ngelihat, bukan selalu ke arah yang sama di dunia
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
