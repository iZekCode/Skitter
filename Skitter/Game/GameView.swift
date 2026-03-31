import SwiftUI
import RealityKit
import Combine
import simd

struct GameView: View {
    @Environment(AppState.self) private var appState
    @State private var gameState                = GameState()
    @State private var motionController         = MotionController()
    @State private var hapticManager            = HapticManager()
    @State private var audioManager             = AudioManager()
    @State private var contactSystem:           ContactSystem?
    @State private var bagTriggerSystem:        BagTriggerSystem?
    @State private var escalationSystem:        EscalationSystem?
    @State private var fogSphere:               FogSphere?
    @State private var puddleSystem:            PuddleSystem?
    @State private var playerEntity:            ModelEntity?
    @State private var roachSpawnTimer:         Timer?
    @State private var showCountdown            = true
    @State private var countdownValue           = 3
    @State private var cameraEntity:            PerspectiveCamera?
    @State private var sceneUpdateSubscription: (any Cancellable)?
    @State private var assetsLoading            = true
    @State private var hudCameraYaw: Float      = .pi

    private var difficulty: DifficultySettings {
        DifficultySettings.settings(for: appState.selectedDifficulty)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if assetsLoading {
                loadingOverlay
            } else {
                realityViewScene
                
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
                if showCountdown { countdownOverlay }
                if gameState.isGameOver { gameOverOverlay }
            }
        }
        .ignoresSafeArea()
        .onAppear { preloadThenStart() }
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
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        gameState.isWin
                            ? Color(red: 0.3, green: 0.9, blue: 0.3)
                            : Color(red: 0.9, green: 0.2, blue: 0.2)
                    )
                    .kerning(8)
                    .padding(.bottom, 20)

                // Stats
                HStack(spacing: 10) {
                    statCard(title: "RESULT",      value: gameState.isWin ? "WIN" : "LOSE")
                    statCard(title: "SURVIVED",    value: gameState.formattedTime)
                    statCard(title: "BAGS OPENED", value: "\(difficulty.totalBags - gameState.bagsRemaining)/\(difficulty.totalBags)")
                }
                .frame(maxWidth: 600)

                HStack(spacing: 16) {
                    Button {
                        appState.endGame(
                            survivedTime: gameState.elapsedTime,
                            isWin:        gameState.isWin,
                            bagsOpened:   difficulty.totalBags - gameState.bagsRemaining
                        )
                    } label: {
                        Text("MENU")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.45, green: 0.65, blue: 0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxWidth: 200)
                .padding(.top, 20)
            }
            .padding(40)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .kerning(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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

            // Arena
            physicsRoot.addChild(ArenaBuilder.buildArena())
            
            // Player
            let player = PlayerEntity.create()
            physicsRoot.addChild(player)
            self.playerEntity = player
            motionController.attach(to: player)

            // Fog sphere
            let fog = FogSphere.create()
            physicsRoot.addChild(fog.entity)
            self.fogSphere = fog

            // Camera
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

    /// set orientasi kamera
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

        let newYaw = motionController.cameraYaw
        if abs(newYaw - hudCameraYaw) > 0.04 {
            hudCameraYaw = newYaw
        }

        // Send roach position for proximity audio update
        guard let root = player.parent else { return }
        let roachEntities = root.children.filter { $0.components[RoachComponent.self] != nil }
        gameState.roachPositions = roachEntities.map { $0.position(relativeTo: nil) }
        
        audioManager.updatePositions(
            listenerPosition: eyePos,
            listenerYaw:      motionController.cameraYaw,
            roachEntities:    Array(roachEntities)
        )

        // Send closest roach position for proximity haptic update
        let closestDist = roachEntities.map {
            length($0.position(relativeTo: nil) - basePos)
        }.min() ?? Float.infinity
        hapticManager.updateRoachProximity(closestDistance: closestDist)

        fogSphere?.follow(player: player)
    }

    // MARK: - Game logic

    private func beginGame() {
        RoachAISystem.isGameOver = false
        RoachAISystem.registerSystem()
        RoachComponent.registerComponent()
        MysteryBagComponent.registerComponent()

        gameState.startGame(totalBags: difficulty.totalBags)
        audioManager.startMusic()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let scene = playerEntity?.scene else { return }
            subscribeToSceneUpdates(scene: scene)
            
            contactSystem = ContactSystem(
                scene: scene, gameState: gameState,
                hapticManager: hapticManager, audioManager: audioManager,
                onGameOver: {
                    motionController.freeze()
                    freezeAllRoaches()    
                }
            )
            
            puddleSystem = PuddleSystem(scene: scene)
            
            if let arenaRoot = playerEntity?.parent {
                MysteryBagEntity.spawnAll(in: arenaRoot, totalBags: difficulty.totalBags)
                
                escalationSystem = EscalationSystem(
                    gameState: gameState, roachParent: arenaRoot,
                    audioManager: audioManager, difficulty: difficulty
                )
                
                bagTriggerSystem = BagTriggerSystem(
                    scene: scene, gameState: gameState,
                    hapticManager: hapticManager, audioManager: audioManager,
                    bagParent: arenaRoot)
                
                bagTriggerSystem?.freezePlayer = {
                    motionController.freeze()
                    freezeAllRoaches()
                }
            }
        }
        spawnInitialRoaches()
        startRoachSpawning()
    }

    private func spawnInitialRoaches() {
        guard let root = playerEntity?.parent else { return }
        let playerPos = playerEntity?.position(relativeTo: nil)
        for _ in 0..<difficulty.initialRoachCount {
            let pos = RoachEntity.randomEdgePosition(avoidingPosition: playerPos)
            let roach = RoachEntity.createChaser(at: pos, speedMultiplier: difficulty.roachSpeedMultiplier)
            root.addChild(roach)
            audioManager.addRoach(roach)
        }
    }

    private func startRoachSpawning() {
        roachSpawnTimer = Timer.scheduledTimer(withTimeInterval: difficulty.roachSpawnInterval, repeats: true) { _ in
            guard !gameState.isGameOver else { roachSpawnTimer?.invalidate(); return }
            guard let root = playerEntity?.parent else { return }
            let playerPos = playerEntity?.position(relativeTo: nil)
            let pos = RoachEntity.randomEdgePosition(avoidingPosition: playerPos)
            let roach = RoachEntity.createChaser(at: pos, speedMultiplier: difficulty.roachSpeedMultiplier)
            root.addChild(roach)
            audioManager.addRoach(roach)
        }
    }
    
    private func freezeAllRoaches() {
        RoachAISystem.isGameOver = true
        audioManager.stopAllRoachAudio() 

        guard let root = playerEntity?.parent else { return }
        for child in root.children {
            guard child.components[RoachComponent.self] != nil else { continue }
            if var motion = child.components[PhysicsMotionComponent.self] {
                motion.linearVelocity  = .zero
                motion.angularVelocity = .zero
                child.components[PhysicsMotionComponent.self] = motion
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes     = Int(time) / 60
        let seconds     = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }

    private func cleanup() {
        sceneUpdateSubscription?.cancel(); sceneUpdateSubscription = nil
        contactSystem?.cancel();          contactSystem = nil
        bagTriggerSystem?.cancel();       bagTriggerSystem = nil
        escalationSystem?.cancel();       escalationSystem = nil
        roachSpawnTimer?.invalidate();    roachSpawnTimer = nil
        fogSphere = nil
        puddleSystem?.cancel();           puddleSystem = nil
        audioManager.stop()
        gameState.reset()
    }
}
