import RealityKit
import UIKit

/// Collision group and filter definitions for Skitter
struct CollisionGroups {
    static let ball = CollisionGroup(rawValue: 1 << 0)
    static let obstacle = CollisionGroup(rawValue: 1 << 1)
    static let roach = CollisionGroup(rawValue: 1 << 2)
    static let boundary = CollisionGroup(rawValue: 1 << 3)
}

/// Builds the arena with floor, obstacles, and boundary walls
enum ArenaBuilder {
    static let arenaSize: Float = 60.0  // Total arena size in meters
    static let wallHeight: Float = 3.0
    static let wallThickness: Float = 1.0

    /// Create the complete arena and return all entities
    static func buildArena() -> Entity {
        let root = Entity()
        root.name = "arena"

        // Floor
        let floor = createFloor()
        root.addChild(floor)

        // Boundary walls
        let walls = createBoundaryWalls()
        for wall in walls {
            root.addChild(wall)
        }

        // Obstacles (solid blocks)
        let obstacles = createObstacles()
        for obstacle in obstacles {
            root.addChild(obstacle)
        }

        return root
    }

    private static func createFloor() -> ModelEntity {
        let mesh = MeshResource.generatePlane(width: arenaSize, depth: arenaSize)

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.15, green: 0.12, blue: 0.08, alpha: 1.0))
        material.roughness = .init(floatLiteral: 0.85)
        material.metallic = .init(floatLiteral: 0.1)

        let floor = ModelEntity(mesh: mesh, materials: [material])
        floor.name = "floor"
        floor.position = .zero

        // Static physics for collisions
        floor.components.set(CollisionComponent(
            shapes: [.generateBox(width: arenaSize, height: 0.1, depth: arenaSize)],
            mode: .default,
            filter: CollisionFilter(group: CollisionGroups.obstacle, mask: CollisionGroups.ball)
        ))

        var physics = PhysicsBodyComponent(mode: .static)
        physics.material = .generate(staticFriction: 0.5, dynamicFriction: 0.4, restitution: 0.2)
        floor.components.set(physics)

        floor.position.y = -0.05

        return floor
    }

    private static func createBoundaryWalls() -> [ModelEntity] {
        let halfSize = arenaSize / 2.0
        var walls: [ModelEntity] = []

        // Wall material — dark, nearly invisible
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.05, green: 0.05, blue: 0.03, alpha: 0.5))
        material.roughness = .init(floatLiteral: 0.9)

        let positions: [(SIMD3<Float>, Float, Float)] = [
            // (position, width, depth)
            (SIMD3<Float>(0, wallHeight / 2, -halfSize), arenaSize, wallThickness),   // North
            (SIMD3<Float>(0, wallHeight / 2, halfSize), arenaSize, wallThickness),    // South
            (SIMD3<Float>(-halfSize, wallHeight / 2, 0), wallThickness, arenaSize),   // West
            (SIMD3<Float>(halfSize, wallHeight / 2, 0), wallThickness, arenaSize),    // East
        ]

        for (i, (pos, width, depth)) in positions.enumerated() {
            let mesh = MeshResource.generateBox(width: width, height: wallHeight, depth: depth)
            let wall = ModelEntity(mesh: mesh, materials: [material])
            wall.name = "wall_\(i)"
            wall.position = pos

            wall.components.set(CollisionComponent(
                shapes: [.generateBox(width: width, height: wallHeight, depth: depth)],
                mode: .default,
                filter: CollisionFilter(group: CollisionGroups.boundary, mask: CollisionGroups.ball)
            ))
            wall.components.set(PhysicsBodyComponent(mode: .static))

            walls.append(wall)
        }

        return walls
    }

    private static func createObstacles() -> [ModelEntity] {
        var obstacles: [ModelEntity] = []

        // Semi-random obstacle positions, spread around the arena
        let obstacleConfigs: [(position: SIMD3<Float>, size: SIMD3<Float>)] = [
            (SIMD3<Float>(-12, 1.0, -8), SIMD3<Float>(3, 2, 3)),
            (SIMD3<Float>(10, 0.75, 5), SIMD3<Float>(2.5, 1.5, 4)),
            (SIMD3<Float>(-5, 1.2, 14), SIMD3<Float>(4, 2.4, 2)),
            (SIMD3<Float>(18, 0.9, -12), SIMD3<Float>(3, 1.8, 3)),
            (SIMD3<Float>(-18, 0.8, -18), SIMD3<Float>(2, 1.6, 5)),
            (SIMD3<Float>(8, 1.1, -20), SIMD3<Float>(5, 2.2, 2.5)),
            (SIMD3<Float>(-15, 0.7, 10), SIMD3<Float>(3.5, 1.4, 3)),
            (SIMD3<Float>(20, 1.0, 15), SIMD3<Float>(2.5, 2, 2.5)),
            (SIMD3<Float>(0, 0.6, -15), SIMD3<Float>(2, 1.2, 2)),
            (SIMD3<Float>(-8, 0.85, 22), SIMD3<Float>(3, 1.7, 3)),
        ]

        // Different brownish/rusty materials for variety
        let colors: [UIColor] = [
            UIColor(red: 0.25, green: 0.18, blue: 0.10, alpha: 1.0),
            UIColor(red: 0.30, green: 0.15, blue: 0.08, alpha: 1.0),
            UIColor(red: 0.20, green: 0.20, blue: 0.12, alpha: 1.0),
            UIColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 1.0),
        ]

        for (i, config) in obstacleConfigs.enumerated() {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: colors[i % colors.count])
            material.roughness = .init(floatLiteral: 0.9)
            material.metallic = .init(floatLiteral: 0.05)

            let mesh = MeshResource.generateBox(
                width: config.size.x,
                height: config.size.y,
                depth: config.size.z,
                cornerRadius: 0.1
            )

            let obstacle = ModelEntity(mesh: mesh, materials: [material])
            obstacle.name = "obstacle_\(i)"
            obstacle.position = config.position

            obstacle.components.set(CollisionComponent(
                shapes: [.generateBox(width: config.size.x, height: config.size.y, depth: config.size.z)],
                mode: .default,
                filter: CollisionFilter(group: CollisionGroups.obstacle, mask: [CollisionGroups.ball, CollisionGroups.roach])
            ))

            var physics = PhysicsBodyComponent(mode: .static)
            physics.material = .generate(staticFriction: 0.6, dynamicFriction: 0.5, restitution: 0.4)
            obstacle.components.set(physics)

            obstacles.append(obstacle)
        }

        return obstacles
    }
}
