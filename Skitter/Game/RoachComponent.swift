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

    /// Default chaser roach stats
    static func chaser() -> RoachComponent {
        RoachComponent(
            roachType: .chaser,
            speed: 4.0,       // meters/s in RealityKit scale
            crushThreshold: 6.0 // ball speed needed to crush
        )
    }
}
