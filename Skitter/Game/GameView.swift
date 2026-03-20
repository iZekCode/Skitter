import SwiftUI
import RealityKit
import Combine
import simd

/// Main game screen: RealityKit scene + HUD + dual-thumb controls overlay
struct GameView: View {
    @Environment(AppState.self) private var appState
    @State private var gameState        = GameState()
    @State private var motionController = MotionController()
    @State private var hapticManager    = HapticManager()
    @State private var contactSystem:     ContactSystem?
    @State private var bagTriggerSystem:  BagTriggerSystem?
    @State private var escalationSystem:  EscalationSystem?
    @State private var playerEntity:      ModelEntity?
    @State private var roachSpawnTimer:   Timer?
    @State private var showCountdown      = true
    @State private var countdownValue     = 3

    @State private var cameraEntity:           PerspectiveCamera?
    @State private var sceneUpdateSubscription: (any Cancellable)?

    var body: some View {
        ZStack {
            // ── 3D scene ──────────────────────────────────────────────────────
            realityViewScene

            // ── Dual-thumb control overlay ────────────────────────────────────
            // Always present during play so touches are never swallowed by HUD
            if !showCountdown && !gameState.isGameOver {
                DualThumbControlView(
                    onMovement: { dx, dz in
                        motionController.applyJoystickInput(dx: dx, dz: dz)
                    },
                    onLook: { screenDX in
                        motionController.applyLookDelta(screenDX: screenDX)
                    }
                )
                .ignoresSafeArea()
            }

            // ── HUD (sits on top of controls) ─────────────────────────────────
            if !showCountdown {
                HUDView(
                    gameState: gameState,
                    labelState: bagTriggerSystem?.labelState ?? BagTriggerLabelState()
                )
            }

            // ── Countdown ─────────────────────────────────────────────────────
            if showCountdown {
                countdownOverlay
            }

            // ── Game over ─────────────────────────────────────────────────────
            if gameState.isGameOver {
                gameOverOverlay
            }
        }
        .ignoresSafeArea()
        .onAppear  { startCountdown() }
        .onDisappear { cleanup() }
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

            let physicsRoot = Entity()
            physicsRoot.name = "physicsRoot"
            var sim = PhysicsSimulationComponent()
            sim.gravity = SIMD3<Float>(0, -9.8, 0)
            physicsRoot.components.set(sim)
            content.add(physicsRoot)

            let arena = ArenaBuilder.buildArena()
            physicsRoot.addChild(arena)

            let player = PlayerEntity.create()
            physicsRoot.addChild(player)
            self.playerEntity = player
            motionController.attach(to: player)

            // Camera — initial orientation matches motionController.cameraYaw
            let camera = PerspectiveCamera()
            camera.name = "gameCamera"
            camera.camera.fieldOfViewInDegrees = 75

            if let eye = player.findEntity(named: "playerEye") {
                camera.position = eye.position(relativeTo: nil)
            } else {
                camera.position = player.position + SIMD3<Float>(0, PlayerEntity.eyeHeight, 0)
            }
            camera.orientation = simd_quatf(
                angle: motionController.cameraYaw,
                axis: SIMD3<Float>(0, 1, 0)
            )
            physicsRoot.addChild(camera)
            self.cameraEntity = camera

            // Lighting
            let dirLight = Entity()
            dirLight.components.set(DirectionalLightComponent(
                color: UIColor(red: 0.15, green: 0.10, blue: 0.08, alpha: 1.0),
                intensity: 2000
            ))
            dirLight.orientation = simd_quatf(angle: -.pi / 3, axis: SIMD3<Float>(1, 0, 0.3))
            physicsRoot.addChild(dirLight)

            let pl1 = Entity()
            pl1.components.set(PointLightComponent(
                color: UIColor(red: 0.8, green: 0.15, blue: 0.05, alpha: 1.0),
                intensity: 5000, attenuationRadius: 25
            ))
            pl1.position = SIMD3<Float>(-15, 8, -10)
            physicsRoot.addChild(pl1)

            let pl2 = Entity()
            pl2.components.set(PointLightComponent(
                color: UIColor(red: 0.1, green: 0.6, blue: 0.1, alpha: 1.0),
                intensity: 3000, attenuationRadius: 20
            ))
            pl2.position = SIMD3<Float>(12, 6, 15)
            physicsRoot.addChild(pl2)

            if let scene = physicsRoot.scene {
                gameState.scene = scene
            }
        }
    }

    // MARK: - Per-frame camera tick (SceneEvents.Update)

    private func subscribeToSceneUpdates(scene: RealityKit.Scene) {
        sceneUpdateSubscription = scene.subscribe(to: SceneEvents.Update.self) { [self] _ in
            tickCamera()
        }
    }

    /// Positions the camera at the player's eye anchor and applies the current
    /// yaw from MotionController. Camera yaw is now *only* driven by right-thumb
    /// drag — no auto-follow from velocity.
    private func tickCamera() {
        guard let player = playerEntity,
              let camera = cameraEntity else { return }

        // ── Position at eye anchor ────────────────────────────────────────────
        let eyePos: SIMD3<Float>
        if let eye = player.findEntity(named: "playerEye") {
            eyePos = eye.position(relativeTo: nil)
        } else {
            eyePos = player.position(relativeTo: nil) + SIMD3<Float>(0, PlayerEntity.eyeHeight, 0)
        }
        camera.position = eyePos

        // ── Orientation from motionController.cameraYaw ───────────────────────
        camera.orientation = simd_quatf(
            angle: motionController.cameraYaw,
            axis: SIMD3<Float>(0, 1, 0)
        )

        // ── HUD state (safe — SceneEvents.Update fires on main thread) ────────
        if let motion = player.components[PhysicsMotionComponent.self] {
            gameState.ballSpeed      = length(motion.linearVelocity)
            gameState.playerPosition = player.position(relativeTo: nil)
        }
    }

    // MARK: - Game Logic

    private func beginGame() {
        RoachEntity.preload()
        RoachAISystem.registerSystem()
        RoachComponent.registerComponent()
        MysteryBagComponent.registerComponent()

        gameState.startGame()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let scene = playerEntity?.scene else { return }

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
            root.addChild(RoachEntity.createChaser(at: pos))
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
            root.addChild(RoachEntity.createChaser(at: pos))
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
    }
}
