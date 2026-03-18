import SwiftUI
import RealityKit

/// Main game screen: RealityView + HUD overlay
struct GameView: View {
    @Environment(AppState.self) private var appState
    @State private var gameState = GameState()
    @State private var motionController = MotionController()
    @State private var hapticManager = HapticManager()
    @State private var crushSystem: CrushSystem?
    @State private var ballEntity: ModelEntity?
    @State private var roachSpawnTimer: Timer?
    @State private var showCountdown = true
    @State private var countdownValue = 3

    // Drag state for simulator fallback
    @State private var dragVelocity: CGSize = .zero

    var body: some View {
        ZStack {
            // 3D scene
            realityViewScene
                .gesture(simulatorDragGesture)

            // HUD overlay
            if !showCountdown {
                HUDView(gameState: gameState)
            }

            // Countdown overlay
            if showCountdown {
                countdownOverlay
            }

            // Game over overlay
            if gameState.isGameOver {
                gameOverOverlay
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Countdown

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
            Text("\(countdownValue)")
                .font(.system(size: 120, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .contentTransition(.numericText())
        }
        .ignoresSafeArea()
    }

    private func startCountdown() {
        countdownValue = 3
        showCountdown = true

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdownValue -= 1
            if countdownValue <= 0 {
                timer.invalidate()
                showCountdown = false
                beginGame()
            }
        }
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.9, green: 0.2, blue: 0.2))
                    .kerning(8)

                HStack(spacing: 20) {
                    statCard(title: "SURVIVED", value: gameState.formattedTime)
                    statCard(title: "CRUSHED", value: "\(gameState.crushedCount)")
                }

                HStack(spacing: 16) {
                    Button(action: {
                        restartGame()
                    }) {
                        Text("PLAY AGAIN")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.45, green: 0.65, blue: 0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button(action: {
                        appState.endGame(
                            survivedTime: gameState.elapsedTime,
                            crushedCount: gameState.crushedCount
                        )
                    }) {
                        Text("MENU")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 24)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxWidth: 400)
            }
            .padding(40)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .kerning(2)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(width: 140, height: 80)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Scene Setup

    private var realityViewScene: some View {
        RealityView { content in
            // Configure physics
            let physicsRoot = Entity()
            physicsRoot.name = "physicsRoot"
            var physicsSimulation = PhysicsSimulationComponent()
            physicsSimulation.gravity = SIMD3<Float>(0, -9.8, 0)
            physicsRoot.components.set(physicsSimulation)
            content.add(physicsRoot)

            // Arena
            let arena = ArenaBuilder.buildArena()
            physicsRoot.addChild(arena)

            // Ball
            let ball = BallEntity.create()
            physicsRoot.addChild(ball)
            self.ballEntity = ball
            motionController.attach(to: ball)

            // Camera (isometric perspective)
            let camera = PerspectiveCamera()
            camera.name = "gameCamera"
            camera.camera.fieldOfViewInDegrees = 50

            // Position above and behind, looking down at ~45°
            let cameraOffset = SIMD3<Float>(0, 35, 35)
            camera.position = ball.position + cameraOffset
            camera.look(at: ball.position, from: camera.position, relativeTo: nil)
            physicsRoot.addChild(camera)

            // Lighting
            let directionalLight = Entity()
            directionalLight.name = "directionalLight"
            directionalLight.components.set(DirectionalLightComponent(
                color: UIColor(red: 0.15, green: 0.1, blue: 0.08, alpha: 1.0),
                intensity: 2000
            ))
            directionalLight.orientation = simd_quatf(
                angle: -.pi / 3,
                axis: SIMD3<Float>(1, 0, 0.3)
            )
            physicsRoot.addChild(directionalLight)

            // Dim reddish point light for mood
            let pointLight1 = Entity()
            pointLight1.name = "pointLight1"
            pointLight1.components.set(PointLightComponent(
                color: UIColor(red: 0.8, green: 0.15, blue: 0.05, alpha: 1.0),
                intensity: 5000,
                attenuationRadius: 25
            ))
            pointLight1.position = SIMD3<Float>(-15, 8, -10)
            physicsRoot.addChild(pointLight1)

            // Green gas-like point light
            let pointLight2 = Entity()
            pointLight2.name = "pointLight2"
            pointLight2.components.set(PointLightComponent(
                color: UIColor(red: 0.1, green: 0.6, blue: 0.1, alpha: 1.0),
                intensity: 3000,
                attenuationRadius: 20
            ))
            pointLight2.position = SIMD3<Float>(12, 6, 15)
            physicsRoot.addChild(pointLight2)

            // Store scene reference for systems
            if let scene = physicsRoot.scene {
                gameState.scene = scene
            }
        } update: { content in
            self.updateCamera(content: content)
        }
    }

    private func updateCamera(content: some RealityViewContentProtocol) {
        guard let ball = ballEntity else { return }

        // Find camera
        var cameraEntity: Entity?
        for entity in content.entities {
            if let found = entity.findEntity(named: "gameCamera") {
                cameraEntity = found
                break
            }
        }
        guard let camera = cameraEntity else { return }

        let cameraOffset = SIMD3<Float>(0, 35, 35)
        let targetPosition = ball.position(relativeTo: nil) + cameraOffset

        // Smooth follow
        let smoothing: Float = 0.05
        camera.position = camera.position + (targetPosition - camera.position) * smoothing

        camera.look(at: ball.position(relativeTo: nil), from: camera.position, relativeTo: nil)

        // Update ball speed in game state
        if let motion = ball.components[PhysicsMotionComponent.self] {
            gameState.ballSpeed = length(motion.linearVelocity)
        }
    }

    // MARK: - Simulator Drag Gesture

    private var simulatorDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let dx = Float(value.velocity.width) / 8000.0
                let dz = Float(value.velocity.height) / 8000.0
                motionController.applySimulatedInput(dx: dx, dz: dz)
            }
    }

    // MARK: - Game Logic

    private func beginGame() {
        // Preload roach USDZ template FIRST — subsequent spawns just clone it
        RoachEntity.preload()
        
        // Register ECS system
        RoachAISystem.registerSystem()
        RoachComponent.registerComponent()

        gameState.startGame()
        motionController.startMotionUpdates()

        // Setup crush system after scene is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let scene = ballEntity?.scene {
                crushSystem = CrushSystem(scene: scene, gameState: gameState, hapticManager: hapticManager)
            }
        }

        // Spawn roaches periodically
        spawnInitialRoaches()
        startRoachSpawning()
    }

    private func spawnInitialRoaches() {
        guard let root = ballEntity?.parent else { return }
        // Spawn 2 initial chasers
        for _ in 0..<2 {
            let pos = RoachEntity.randomEdgePosition()
            let roach = RoachEntity.createChaser(at: pos)
            root.addChild(roach)
        }
    }

    private func startRoachSpawning() {
        roachSpawnTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [self] _ in
            guard !gameState.isGameOver else {
                roachSpawnTimer?.invalidate()
                return
            }
            guard let root = ballEntity?.parent else { return }

            let pos = RoachEntity.randomEdgePosition()
            let roach = RoachEntity.createChaser(at: pos)
            root.addChild(roach)
        }
    }

    private func restartGame() {
        cleanup()

        // Clear old entities and rebuild
        gameState.reset()

        // Small delay to let state reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startCountdown()
        }
    }

    private func cleanup() {
        motionController.stopMotionUpdates()
        crushSystem?.cancel()
        crushSystem = nil
        roachSpawnTimer?.invalidate()
        roachSpawnTimer = nil
        gameState.reset()
    }
}
