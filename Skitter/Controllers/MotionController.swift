import CoreMotion
import RealityKit
import simd

/// Wraps CMMotionManager to translate device tilt into ball velocity.
/// Falls back to a manual input mode when gyro is unavailable (Simulator).
class MotionController: ObservableObject {
    private let motionManager = CMMotionManager()
    private var baselineAttitude: CMAttitude?
    private weak var ball: ModelEntity?

    let sensitivity: Float = 15.0
    let maxSpeed: Float = 20.0

    /// Whether real gyro is available
    var isGyroAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    // Simulator fallback: accumulated simulated tilt
    @Published var simulatedPitch: Float = 0
    @Published var simulatedRoll: Float = 0

    func attach(to ball: ModelEntity) {
        self.ball = ball
    }

    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("[MotionController] Device motion not available — using simulated input")
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: .main
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }

            // Capture baseline on first reading
            if self.baselineAttitude == nil {
                self.baselineAttitude = motion.attitude.copy() as? CMAttitude
            }

            // Make attitude relative to baseline
            if let baseline = self.baselineAttitude {
                motion.attitude.multiply(byInverseOf: baseline)
            }

            let pitch = Float(motion.attitude.pitch)
            let roll = Float(motion.attitude.roll)

            self.applyForce(pitch: pitch, roll: roll)
        }
    }

    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        baselineAttitude = nil
    }

    func recalibrate() {
        baselineAttitude = nil
    }

    /// Apply simulated input (for Simulator / touch drag)
    func applySimulatedInput(dx: Float, dz: Float) {
        guard let ball = ball else { return }

        var motion = ball.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        var velocity = motion.linearVelocity
        velocity.x += dx * sensitivity * 0.5
        velocity.z += dz * sensitivity * 0.5
        velocity.y = 0

        // Clamp speed
        let speed = length(SIMD2<Float>(velocity.x, velocity.z))
        if speed > maxSpeed {
            let scale = maxSpeed / speed
            velocity.x *= scale
            velocity.z *= scale
        }

        motion.linearVelocity = velocity
        ball.components[PhysicsMotionComponent.self] = motion
    }

    private func applyForce(pitch: Float, roll: Float) {
        guard let ball = ball else { return }

        let fx = sin(roll) * sensitivity
        let fz = -sin(pitch) * sensitivity  // Negative because tilt forward = move toward -z in landscape

        var motion = ball.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        var velocity = motion.linearVelocity
        velocity.x += fx * (1.0 / 60.0) * sensitivity
        velocity.z += fz * (1.0 / 60.0) * sensitivity
        velocity.y = 0

        // Clamp speed
        let speed = length(SIMD2<Float>(velocity.x, velocity.z))
        if speed > maxSpeed {
            let scale = maxSpeed / speed
            velocity.x *= scale
            velocity.z *= scale
        }

        motion.linearVelocity = velocity
        ball.components[PhysicsMotionComponent.self] = motion
    }
}
