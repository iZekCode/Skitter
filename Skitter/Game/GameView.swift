import SwiftUI
import RealityKit
import Combine
import simd

/// Main game screen: RealityView + HUD overlay
struct GameView: View {
    @Environment(AppState.self) private var appState
    @State private var gameState = GameState()
    @State private var motionController = MotionController()
    @State private var hapticManager = HapticManager()
    @State private var contactSystem: ContactSystem?
    @State private var bagTriggerSystem: BagTriggerSystem?
    @State private var escalationSystem: EscalationSystem?
    @State private var playerEntity: ModelEntity?
    @State private var roachSpawnTimer: Timer?
    @State private var showCountdown = true
    @State private var countdownValue = 3

    // Stored so SceneEvents.Update can drive the camera every frame
    @State private var cameraEntity: PerspectiveCamera?
    @State private var sceneUpdateSubscription: (any Cancellable)?

    // Tracks the camera's current yaw so we can slerp smoothly
    @State private var cameraYaw: Float = 0

    var body: some View {
        ZStack {
            // 3D scene
            realityViewScene
                .gesture(simulatorDragGesture)

            // HUD overlay
            if !showCountdown {
                HUDView(
                    gameState: gameState,
                    labelState: bagTriggerSystem?.labelState ?? BagTriggerLabelState()
                )
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

                statCard(title: "SURVIVED", value: gameState.formattedTime)

                HStack(spacing: 16) {
                    Button(action: { restartGame() }) {
                        Text("PLAY AGAIN")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.45, green: 0.65, blue: 0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button(action: {
                        appState.endGame(survivedTime: gameState.elapsedTime)
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
        // update: closure intentionally left empty — per-frame work happens in
        // the SceneEvents.Update subscription set up inside beginGame().
        RealityView { content in

            // ── Physics root ─────────────────────────────────────────────────
            let physicsRoot = Entity()
            physicsRoot.name = "physicsRoot"
            var physicsSimulation = PhysicsSimulationComponent()
            physicsSimulation.gravity = SIMD3<Float>(0, -9.8, 0)
            physicsRoot.components.set(physicsSimulation)
            content.add(physicsRoot)

            // ── Arena ────────────────────────────────────────────────────────
            let arena = ArenaBuilder.buildArena()
            physicsRoot.addChild(arena)

            // ── Player ───────────────────────────────────────────────────────
            let player = PlayerEntity.create()
            physicsRoot.addChild(player)
            self.playerEntity = player
            motionController.attach(to: player)

            // ── Camera ───────────────────────────────────────────────────────
            let camera = PerspectiveCamera()
            camera.name = "gameCamera"
            camera.camera.fieldOfViewInDegrees = 75

            if let eye = player.findEntity(named: "playerEye") {
                camera.position = eye.position(relativeTo: nil)
            } else {
                camera.position = player.position + SIMD3<Float>(0, PlayerEntity.eyeHeight, 0)
            }
            camera.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
            physicsRoot.addChild(camera)

            // Store reference so the per-frame subscription can access it
            // without searching the scene hierarchy every tick.
            self.cameraEntity = camera

            // ── Lighting ─────────────────────────────────────────────────────
            let directionalLight = Entity()
            directionalLight.name = "directionalLight"
            directionalLight.components.set(DirectionalLightComponent(
                color: UIColor(red: 0.15, green: 0.10, blue: 0.08, alpha: 1.0),
                intensity: 2000
            ))
            directionalLight.orientation = simd_quatf(
                angle: -.pi / 3,
                axis: SIMD3<Float>(1, 0, 0.3)
            )
            physicsRoot.addChild(directionalLight)

            let pointLight1 = Entity()
            pointLight1.name = "pointLight1"
            pointLight1.components.set(PointLightComponent(
                color: UIColor(red: 0.8, green: 0.15, blue: 0.05, alpha: 1.0),
                intensity: 5000,
                attenuationRadius: 25
            ))
            pointLight1.position = SIMD3<Float>(-15, 8, -10)
            physicsRoot.addChild(pointLight1)

            let pointLight2 = Entity()
            pointLight2.name = "pointLight2"
            pointLight2.components.set(PointLightComponent(
                color: UIColor(red: 0.1, green: 0.6, blue: 0.1, alpha: 1.0),
                intensity: 3000,
                attenuationRadius: 20
            ))
            pointLight2.position = SIMD3<Float>(12, 6, 15)
            physicsRoot.addChild(pointLight2)

            // ── Store scene reference ─────────────────────────────────────────
            if let scene = physicsRoot.scene {
                gameState.scene = scene
            }
        }
        // No update: closure needed — SceneEvents.Update handles per-frame work.
    }

    // MARK: - Per-frame Camera Update (driven by SceneEvents.Update)

    /// Subscribes to RealityKit's per-frame scene update so the camera
    /// tracks the player every single render tick, not just on SwiftUI redraws.
    private func subscribeToSceneUpdates(scene: RealityKit.Scene) {
        sceneUpdateSubscription = scene.subscribe(to: SceneEvents.Update.self) { [self] _ in
            self.tickCameraAndHUD()
        }
    }

    private func tickCameraAndHUD() {
        guard let player = playerEntity,
              let camera = cameraEntity else { return }

        // ── Position: stick camera to eye anchor ─────────────────────────────
        let eyeWorldPos: SIMD3<Float>
        if let eye = player.findEntity(named: "playerEye") {
            eyeWorldPos = eye.position(relativeTo: nil)
        } else {
            eyeWorldPos = player.position(relativeTo: nil) + SIMD3<Float>(0, PlayerEntity.eyeHeight, 0)
        }
        camera.position = eyeWorldPos

        // ── Orientation: face direction of movement ───────────────────────────
        if let motion = player.components[PhysicsMotionComponent.self] {
            let vel = motion.linearVelocity
            let moveDir = SIMD2<Float>(vel.x, vel.z)
            let moveSpeed = length(moveDir)

            // Update HUD values — safe to write from this closure (main thread)
            gameState.ballSpeed = length(vel)
            gameState.playerPosition = player.position(relativeTo: nil)

            if moveSpeed > 0.5 {
                let targetYaw = atan2(vel.x, vel.z) + .pi

                // Shortest-path lerp to avoid 360° snapping
                var delta = targetYaw - cameraYaw
                if delta >  .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }

                let smoothing: Float = 0.12
                cameraYaw += delta * smoothing

                camera.orientation = simd_quatf(
                    angle: cameraYaw,
                    axis: SIMD3<Float>(0, 1, 0)
                )
            }
        }
    }

    // MARK: - Simulator Drag Gesture

    private var simulatorDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let dx = Float(value.velocity.width)  / 2000.0
                let dz = Float(value.velocity.height) / 2000.0
                motionController.applySimulatedInput(dx: dx, dz: dz)
            }
    }

    // MARK: - Game Logic

    private func beginGame() {
        RoachEntity.preload()

        RoachAISystem.registerSystem()
        RoachComponent.registerComponent()
        MysteryBagComponent.registerComponent()

        gameState.startGame()
        motionController.startMotionUpdates()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let scene = playerEntity?.scene else { return }

            // ── Subscribe to per-frame scene updates for the camera ───────────
            subscribeToSceneUpdates(scene: scene)

            contactSystem = ContactSystem(
                scene: scene,
                gameState: gameState,
                hapticManager: hapticManager
            )

            if let arenaRoot = playerEntity?.parent {
                MysteryBagEntity.spawnAll(in: arenaRoot)
                escalationSystem = EscalationSystem(
                    gameState: gameState,
                    roachParent: arenaRoot
                )
                bagTriggerSystem = BagTriggerSystem(
                    scene: scene,
                    gameState: gameState,
                    hapticManager: hapticManager,
                    bagParent: arenaRoot
                )
            }
        }

        spawnInitialRoaches()
        startRoachSpawning()
    }

    private func spawnInitialRoaches() {
        guard let root = playerEntity?.parent else { return }
        for _ in 0..<2 {
            let pos = RoachEntity.randomEdgePosition()
            let roach = RoachEntity.createChaser(at: pos)
            root.addChild(roach)
        }
    }

    private func startRoachSpawning() {
        roachSpawnTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            guard !gameState.isGameOver else {
                roachSpawnTimer?.invalidate()
                return
            }
            guard let root = playerEntity?.parent else { return }
            let pos = RoachEntity.randomEdgePosition()
            let roach = RoachEntity.createChaser(at: pos)
            root.addChild(roach)
        }
    }

    private func restartGame() {
        cleanup()
        gameState.reset()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            startCountdown()
        }
    }

    private func cleanup() {
        motionController.stopMotionUpdates()
        sceneUpdateSubscription?.cancel()
        sceneUpdateSubscription = nil
        contactSystem?.cancel()
        contactSystem = nil
        bagTriggerSystem?.cancel()
        bagTriggerSystem = nil
        escalationSystem?.cancel()
        escalationSystem = nil
        roachSpawnTimer?.invalidate()
        roachSpawnTimer = nil
        gameState.reset()
        cameraYaw = 0
    }
}
