import AVFoundation
import RealityKit

/// Manages all game audio via AVAudioEngine.
///
/// Architecture:
///   AVAudioEnvironmentNode  ← 3D panning + distance attenuation for roach nodes
///   AVAudioMixerNode        ← flat mix for BGM + one-shot SFX
///   AVAudioOutputNode       ← device output
///
/// Spatial roach nodes are updated every frame from GameView's tickCamera loop.
class AudioManager {

    // MARK: - Engine

    private let engine      = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private let sfxMixer    = AVAudioMixerNode()

    // MARK: - BGM

    private var bgmPlayer: AVAudioPlayerNode?
    private var bgmBuffer:  AVAudioPCMBuffer?

    // MARK: - Roach nodes
    // key = roach entity name (e.g. "roach_chaser_0")

    private struct RoachAudio {
        let player: AVAudioPlayerNode
        let buffer: AVAudioPCMBuffer
    }
    private var roachNodes: [ObjectIdentifier: RoachAudio] = [:]
    private var skitterBuffer: AVAudioPCMBuffer?

    // MARK: - One-shot buffers

    private var correctBuffer:      AVAudioPCMBuffer?
    private var wrongBuffer:        AVAudioPCMBuffer?
    private var gameoverLoseBuffer: AVAudioPCMBuffer?
    private var gameoverWinBuffer:  AVAudioPCMBuffer?

    // MARK: - State

    private(set) var isRunning = false

    // MARK: - Init

    init() {
        setupSession()
        setupGraph()
        preloadBuffers()
    }

    // MARK: - Session

    private func setupSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioManager] Session setup failed: \(error)")
        }
    }

    // MARK: - Graph

    private func setupGraph() {
        engine.attach(environment)
        engine.attach(sfxMixer)

        // Connect both nodes to the engine's mainMixerNode instead of directly to output.
        // The main mixer safely accepts multiple inputs and automatically routes to the output.
        let mainMixer = engine.mainMixerNode
        
        engine.connect(environment, to: mainMixer, format: nil)
        engine.connect(sfxMixer,    to: mainMixer, format: nil)

        // 3D listener defaults — will be overridden each frame
        environment.listenerPosition   = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerAngularOrientation = AVAudioMake3DAngularOrientation(0, 0, 0)

        // Distance model: inverse, rolls off between 1 m and 40 m
        environment.distanceAttenuationParameters.distanceAttenuationModel    = .inverse
        environment.distanceAttenuationParameters.referenceDistance           = 1
        environment.distanceAttenuationParameters.maximumDistance             = 40
        environment.distanceAttenuationParameters.rolloffFactor               = 2

        do {
            try engine.start()
            isRunning = true
            print("[AudioManager] Engine started")
        } catch {
            print("[AudioManager] Engine start failed: \(error)")
        }
    }

    // MARK: - Buffer preload

    private func preloadBuffers() {
        bgmBuffer          = loadBuffer(named: "background_music", ext: "wav")
        skitterBuffer      = loadBuffer(named: "skittering_sound", ext: "wav")
        correctBuffer      = loadBuffer(named: "correct",          ext: "wav")
        wrongBuffer        = loadBuffer(named: "wrong",            ext: "wav")
        gameoverLoseBuffer = loadBuffer(named: "gameover_lose",    ext: "wav")
        gameoverWinBuffer  = loadBuffer(named: "gameover_win",     ext: "wav")
    }

    private func loadBuffer(named name: String, ext: String) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("[AudioManager] ⚠️  Missing: \(name).\(ext)")
            return nil
        }
        do {
            let file   = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frames = AVAudioFrameCount(file.length)
            guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
                return nil
            }
            try file.read(into: buf)
            return buf
        } catch {
            print("[AudioManager] ⚠️  Failed to load \(name).\(ext): \(error)")
            return nil
        }
    }

    // MARK: - BGM

    func startMusic() {
        guard let buf = bgmBuffer else { return }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: sfxMixer, format: buf.format)
        player.volume = 0.35
        scheduleLooping(player: player, buffer: buf)
        player.play()
        bgmPlayer = player
    }

    func stopMusic() {
        bgmPlayer?.stop()
    }

    // MARK: - Roach spatial audio

    /// Call this when a new roach entity is added to the scene.
    func addRoach(_ entity: Entity) {
        guard let buf = skitterBuffer, isRunning else { return }
        let key    = ObjectIdentifier(entity)
        guard roachNodes[key] == nil else { return }

        let player = AVAudioPlayerNode()
        engine.attach(player)

        // Connect to the environment node for 3D positioning
        engine.connect(player, to: environment, format: buf.format)
        player.volume = 0.1
        scheduleLooping(player: player, buffer: buf)
        player.play()

        roachNodes[key] = RoachAudio(player: player, buffer: buf)
    }

    /// Call this when a roach is removed from the scene.
    func removeRoach(_ entity: Entity) {
        let key = ObjectIdentifier(entity)
        guard let audio = roachNodes.removeValue(forKey: key) else { return }
        audio.player.stop()
        engine.detach(audio.player)
    }

    /// Update listener position + all roach positions. Call every frame from tickCamera.
    func updatePositions(listenerPosition: SIMD3<Float>,
                         listenerYaw: Float,
                         roachEntities: [Entity]) {
        guard isRunning else { return }

        // Listener
        environment.listenerPosition = AVAudio3DPoint(
            x: listenerPosition.x,
            y: listenerPosition.y,
            z: listenerPosition.z
        )
        // Yaw in degrees, convert from radians
        let yawDeg = listenerYaw * (180.0 / .pi)
        environment.listenerAngularOrientation = AVAudioMake3DAngularOrientation(yawDeg, 0, 0)

        // Roach positions
        for entity in roachEntities {
            let key = ObjectIdentifier(entity)
            guard let audio = roachNodes[key] else { continue }
            let pos = entity.position(relativeTo: nil)
            audio.player.position = AVAudio3DPoint(x: pos.x, y: pos.y, z: pos.z)
        }
    }

    // MARK: - One-shot SFX

    func playCorrect() {
        playOneShot(buffer: correctBuffer, volume: 0.9)
    }

    func playWrong() {
        playOneShot(buffer: wrongBuffer, volume: 0.9)
    }

    func playGameOverLose() {
        stopMusic()
        playOneShot(buffer: gameoverLoseBuffer, volume: 1.0)
    }

    func playGameOverWin() {
        stopMusic()
        playOneShot(buffer: gameoverWinBuffer, volume: 1.0)
    }

    private func playOneShot(buffer: AVAudioPCMBuffer?, volume: Float) {
        guard let buf = buffer, isRunning else { return }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: sfxMixer, format: buf.format)
        player.volume = volume
        // Schedule once — detach after playback completes
        player.scheduleBuffer(buf, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                player.stop()
                self?.engine.detach(player)
            }
        }
        player.play()
    }

    // MARK: - Looping helper

    private func scheduleLooping(player: AVAudioPlayerNode, buffer: AVAudioPCMBuffer) {
        player.scheduleBuffer(buffer, at: nil, options: .loops)
    }

    // MARK: - Teardown

    func stop() {
        bgmPlayer?.stop()
        for (_, audio) in roachNodes {
            audio.player.stop()
            engine.detach(audio.player)
        }
        roachNodes.removeAll()
        engine.stop()
        isRunning = false
    }
}
