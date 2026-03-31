import RealityKit

/// ECS component storing roach behavior data
struct RoachComponent: Component {
    enum RoachType {
        case chaser
        case giant
        case flying
    }

    var roachType: RoachType
    var speed: Float
    var crushThreshold: Float

    // MARK: - Factory presets

    static func chaser(speedMultiplier: Float = 1.0) -> RoachComponent {
        RoachComponent(
            roachType: .chaser,
            speed: 4.0 * speedMultiplier,
            crushThreshold: 6.0
        )
    }

    static func giant(speedMultiplier: Float = 1.0) -> RoachComponent {
        RoachComponent(
            roachType: .giant,
            speed: 2.0 * speedMultiplier,
            crushThreshold: 6.0
        )
    }

    static func flying(speedMultiplier: Float = 1.0) -> RoachComponent {
        RoachComponent(
            roachType: .flying,
            speed: 6.0 * speedMultiplier,
            crushThreshold: 6.0
        )
    }
}
