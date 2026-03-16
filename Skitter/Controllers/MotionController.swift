import CoreMotion
import RealityKit
import simd

/// Wraps CMMotionManager to translate device tilt into ball velocity.
///
/// Captures the phone's position at game start as "neutral". Tilt is measured
/// relative to that position — so the player can hold the phone at any
/// comfortable angle (like a normal landscape gaming grip).
///
/// Falls back to drag gesture input when gyro is unavailable (Simulator).
class MotionController: ObservableObject {
    private let motionManager = CMMotionManager()
    private weak var ball: ModelEntity?

    /// Baseline gravity captured at game start — this is the "zero tilt" position
    private var baselineGravity: SIMD2<Float>?

    let sensitivity: Float = 18.0
    let maxSpeed: Float = 20.0

    /// Dead zone — ignore tiny tilts near neutral position
    let deadZone: Float = 0.03

    /// Whether real gyro is available
    var isGyroAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    func attach(to ball: ModelEntity) {
        self.ball = ball
    }

    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("[MotionController] Device motion not available — using simulated input")
            return
        }

        // Reset baseline so it captures fresh on first reading
        baselineGravity = nil

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: .main
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.applyGravityInput(gravity: motion.gravity)
        }
    }

    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        baselineGravity = nil
    }

    /// Reset the neutral position to the current phone orientation
    func recalibrate() {
        baselineGravity = nil
    }

    /// Apply simulated input (for Simulator / touch drag)
    func applySimulatedInput(dx: Float, dz: Float) {
        guard let ball = ball else { return }

        let motion = ball.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        var velocity = motion.linearVelocity
        velocity.x += dx * sensitivity * 0.5
        velocity.z += dz * sensitivity * 0.5
        velocity.y = 0

        clampAndApply(velocity: velocity, to: ball)
    }

    /// Map gravity delta (from baseline) to ball velocity.
    ///
    /// On first call, captures current gravity as baseline.
    /// Subsequent calls compute tilt as difference from baseline.
    ///
    /// In landscape RIGHT:
    /// - gravity.x → forward/backward axis
    /// - gravity.y → left/right axis
    private func applyGravityInput(gravity: CMAcceleration) {
        guard let ball = ball else { return }

        let currentGravity = SIMD2<Float>(Float(gravity.x), Float(gravity.y))

        // Capture baseline on first reading (= current phone position is "neutral")
        if baselineGravity == nil {
            baselineGravity = currentGravity
        }

        guard let baseline = baselineGravity else { return }

        // Tilt = how much gravity has shifted from the baseline position
        var tiltForward = currentGravity.x - baseline.x   // Delta on forward/back axis
        var tiltRight   = -(currentGravity.y - baseline.y) // Delta on left/right axis

        // Apply dead zone
        if abs(tiltForward) < deadZone { tiltForward = 0 }
        if abs(tiltRight) < deadZone { tiltRight = 0 }

        // Map tilt delta to target velocity
        let targetVx = tiltRight * sensitivity
        let targetVz = -tiltForward * sensitivity  // -Z is "forward" in our arena

        // Smooth interpolation for responsive but not jarring feel
        let smoothing: Float = 0.15
        let motion = ball.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        var velocity = motion.linearVelocity
        velocity.x += (targetVx - velocity.x) * smoothing
        velocity.z += (targetVz - velocity.z) * smoothing
        velocity.y = 0

        clampAndApply(velocity: velocity, to: ball)
    }

    private func clampAndApply(velocity: SIMD3<Float>, to ball: ModelEntity) {
        var v = velocity
        let speed = length(SIMD2<Float>(v.x, v.z))
        if speed > maxSpeed {
            let scale = maxSpeed / speed
            v.x *= scale
            v.z *= scale
        }

        var motion = ball.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        motion.linearVelocity = v
        ball.components[PhysicsMotionComponent.self] = motion
    }
}
