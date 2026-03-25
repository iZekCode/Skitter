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

    static func chaser() -> RoachComponent {
        RoachComponent(
            roachType: .chaser,
            speed: 4.0,
            crushThreshold: 6.0
        )
    }

    static func giant() -> RoachComponent {
        RoachComponent(
            roachType: .giant,
            speed: 2.0,
            crushThreshold: 6.0
        )
    }

    static func flying() -> RoachComponent {
        RoachComponent(
            roachType: .flying,
            speed: 6.0,
            crushThreshold: 6.0
        )
    }
}
