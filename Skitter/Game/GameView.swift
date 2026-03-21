import SwiftUI
import RealityKit
import Combine
import simd

struct GameView: View {
    @Environment(AppState.self) private var appState
    @State private var gameState        = GameState()
    @State private var motionController = MotionController()
    @State private var hapticManager    = HapticManager()
    @State private var audioManager     = AudioManager()
    @State private var contactSystem:     ContactSystem?
    @State private var bagTriggerSystem:  BagTriggerSystem?
    @State private var escalationSystem:  EscalationSystem?
    @State private var fogSphere:         FogSphere?
    @State private var playerEntity:      ModelEntity?
    @State private var roachSpawnTimer:   Timer?
    @State private var showCountdown      = true
    @State private var countdownValue     = 3
    @State private var cameraEntity:            PerspectiveCamera?
    @State private var sceneUpdateSubscription: (any Cancellable)?
    @State private var assetsLoading = true

    /// Mirrors MotionController.cameraYaw into SwiftUI state so the minimap
    /// radar cone re-renders every time the player looks around.
    /// (MotionController.cameraYaw is not @Published, so we copy it in tickCamera.)
    @State private var hudCameraYaw: Float = .pi

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if assetsLoading {
                loadingOverlay
            } else {
                realityViewScene
                // Vignette — sits above 3D scene, below all UI
                VignetteView(baitCount: gameState.baitTriggeredCount)

                if !showCountdown && !gameState.isGameOver {
                    DualThumbControlView(
                        onMovement: { dx, dz in motionController.applyJoystickInput(dx: dx, dz: dz) },
                        onLook:     { screenDX in motionController.applyLookDelta(screenDX: screenDX) }
                    )
                    .ignoresSafeArea()
                }
                if !showCountdown {
                    HUDView(
                        gameState:  gameState,
                        labelState: bagTriggerSystem?.labelState ?? BagTriggerLabelState(),
                        cameraYaw:  hudCameraYaw
                    )
                }
                if showCountdown  { countdownOverlay }
                if gameState.isGameOver { gameOverOverlay }
            }
        }
        .ignoresSafeArea()
        .onAppear   { preloadThenStart() }
        .onDisappear { cleanup() }
    }

    // MARK: - Asset loading

    private func preloadThenStart() {
        Task { @MainActor in
            await Task.yield()
            ArenaBuilder.preload()
            MysteryBagEntity.preload()
            RoachEntity.preload()
            assetsLoading = false
            startCountdown()
        }
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white.opacity(0.4))
                .scaleEffect(0.8)
            Text("LOADING")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
                .kerning(4)
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
        showCountdown  = true
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdownValue -= 1
            if countdownValue <= 0 {
                timer.invalidate()
                showCountdown = false
                beginGame()
            }
        }
    }

    // MARK: - Game Over overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.75)
            VStack(spacing: 24) {
                Text(gameState.isWin ? "YOU WIN" : "GAME OVER")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        gameState.isWin
                            ? Color(red: 0.3, green: 0.9, blue: 0.3)
                            : Color(red: 0.9, green: 0.2, blue: 0.2)
                    )
                    .kerning(8)
                statCard(title: "SURVIVED", value: gameState.formattedTime)
                HStack(spacing: 16) {
                    Button { restartGame() } label: {
                        Text("PLAY AGAIN")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.45, green: 0.65, blue: 0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button { appState.endGame(survivedTime: gameState.elapsedTime) } label: {
                        Text("MENU")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.vertical, 14).padding(.horizontal, 24)
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
                .foregroundStyle(.white.opacity(0.4)).kerning(2)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(width: 140, height: 80)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Scene

    private var realityViewScene: some View {
        RealityView { content in
            let physicsRoot = Entity()
            physicsRoot.name = "physicsRoot"
            var sim = PhysicsSimulationComponent()
            sim.gravity = SIMD3<Float>(0, -9.8, 0)
            physicsRoot.components.set(sim)
            content.add(physicsRoot)

            physicsRoot.addChild(ArenaBuilder.buildArena())

            let player = PlayerEntity.create()
            physicsRoot.addChild(player)
            self.playerEntity = player
            motionController.attach(to: player)

            // Fog sphere
            let fog = FogSphere.create()
            physicsRoot.addChild(fog.entity)
            self.fogSphere = fog

            let camera = PerspectiveCamera()
            camera.name = "gameCamera"
            camera.camera.fieldOfViewInDegrees = 75
            camera.position    = player.position + SIMD3<Float>(0, PlayerEntity.eyeHeight, 0)
            camera.orientation = simd_quatf(angle: motionController.cameraYaw, axis: SIMD3<Float>(0,1,0))
            physicsRoot.addChild(camera)
            self.cameraEntity = camera

            // Lights
            let fill = Entity()
            fill.components.set(PointLightComponent(color: .white, intensity: 600, attenuationRadius: 80))
            fill.position = SIMD3<Float>(0, 12, 0)
            physicsRoot.addChild(fill)

            let dir = Entity()
            dir.components.set(DirectionalLightComponent(
                color: UIColor(red: 0.15, green: 0.10, blue: 0.08, alpha: 1), intensity: 2000))
            dir.orientation = simd_quatf(angle: -.pi/3, axis: SIMD3<Float>(1, 0, 0.3))
            physicsRoot.addChild(dir)

            let pl1 = Entity()
            pl1.components.set(PointLightComponent(
                color: UIColor(red: 0.8, green: 0.15, blue: 0.05, alpha: 1), intensity: 5000, attenuationRadius: 25))
            pl1.position = SIMD3<Float>(-15, 8, -10)
            physicsRoot.addChild(pl1)

            let pl2 = Entity()
            pl2.components.set(PointLightComponent(
                color: UIColor(red: 0.1, green: 0.6, blue: 0.1, alpha: 1), intensity: 3000, attenuationRadius: 20))
            pl2.position = SIMD3<Float>(12, 6, 15)
            physicsRoot.addChild(pl2)

            if let scene = physicsRoot.scene { gameState.scene = scene }
        }
    }

    // MARK: - Per-frame tick

    private func subscribeToSceneUpdates(scene: RealityKit.Scene) {
        sceneUpdateSubscription = scene.subscribe(to: SceneEvents.Update.self) { [self] _ in
            tickCamera()
        }
    }

    private func tickCamera() {
        guard let player = playerEntity, let camera = cameraEntity else { return }

        motionController.tickMovement()

        let basePos = player.position(relativeTo: nil)
        let eyePos  = basePos + SIMD3<Float>(0, PlayerEntity.eyeHeight, 0)

        camera.position    = eyePos
        camera.orientation = simd_quatf(angle: motionController.cameraYaw, axis: SIMD3<Float>(0,1,0))

        if let motion = player.components[PhysicsMotionComponent.self] {
            gameState.ballSpeed      = length(motion.linearVelocity)
            gameState.playerPosition = basePos
        }

        // Push yaw into SwiftUI state so the minimap radar cone re-renders.
        // We throttle to ~20 fps for the HUD (every ~3 frames at 60 fps) to
        // avoid forcing a full SwiftUI layout pass every single frame.
        let newYaw = motionController.cameraYaw
        if abs(newYaw - hudCameraYaw) > 0.04 {
            hudCameraYaw = newYaw
        }

        // Spatial audio: update listener + roach positions every frame
        guard let root = player.parent else { return }
        let roachEntities = root.children.filter { $0.components[RoachComponent.self] != nil }
        audioManager.updatePositions(
            listenerPosition: eyePos,
            listenerYaw:      motionController.cameraYaw,
            roachEntities:    Array(roachEntities)
        )

        // Proximity haptic — closest roach distance
        let closestDist = roachEntities.map {
            length($0.position(relativeTo: nil) - basePos)
        }.min() ?? Float.infinity
        hapticManager.updateRoachProximity(closestDistance: closestDist)

        // Fog sphere follows player every frame
        fogSphere?.follow(player: player)
    }

    // MARK: - Game logic

    private func beginGame() {
        RoachAISystem.registerSystem()
        RoachComponent.registerComponent()
        MysteryBagComponent.registerComponent()

        gameState.startGame()
        audioManager.startMusic()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let scene = playerEntity?.scene else { return }
            subscribeToSceneUpdates(scene: scene)
            contactSystem = ContactSystem(
                scene: scene, gameState: gameState,
                hapticManager: hapticManager, audioManager: audioManager)
            if let arenaRoot = playerEntity?.parent {
                MysteryBagEntity.spawnAll(in: arenaRoot)
                escalationSystem = EscalationSystem(gameState: gameState, roachParent: arenaRoot, audioManager: audioManager)
                bagTriggerSystem = BagTriggerSystem(
                    scene: scene, gameState: gameState,
                    hapticManager: hapticManager, audioManager: audioManager,
                    bagParent: arenaRoot)
            }
        }
        spawnInitialRoaches()
        startRoachSpawning()
    }

    private func spawnInitialRoaches() {
        guard let root = playerEntity?.parent else { return }
        for _ in 0..<2 {
            let roach = RoachEntity.createChaser(at: RoachEntity.randomEdgePosition())
            root.addChild(roach)
            audioManager.addRoach(roach)
        }
    }

    private func startRoachSpawning() {
        roachSpawnTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            guard !gameState.isGameOver else { roachSpawnTimer?.invalidate(); return }
            guard let root = playerEntity?.parent else { return }
            let roach = RoachEntity.createChaser(at: RoachEntity.randomEdgePosition())
            root.addChild(roach)
            audioManager.addRoach(roach)
        }
    }

    private func restartGame() {
        cleanup()
        gameState.reset()
        audioManager = AudioManager()
        assetsLoading = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { startCountdown() }
    }

    private func cleanup() {
        sceneUpdateSubscription?.cancel(); sceneUpdateSubscription = nil
        contactSystem?.cancel();          contactSystem = nil
        bagTriggerSystem?.cancel();       bagTriggerSystem = nil
        escalationSystem?.cancel();       escalationSystem = nil
        roachSpawnTimer?.invalidate();    roachSpawnTimer = nil
        fogSphere = nil
        audioManager.stop()
        gameState.reset()
    }
}
