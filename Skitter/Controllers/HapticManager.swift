import CoreHaptics
import UIKit

class HapticManager {
    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool

    // MARK: - Proximity player (continuous, modulated each frame)

    private var proximityPlayer: CHHapticAdvancedPatternPlayer?
    private var proximityRunning = false

    // MARK: - Tunable proximity constants

    private static let proximityStartDist: Float = 12.0
    private static let proximityMaxDist:   Float = 5.0
    private static let proximityMinIntensity: Float = 0.05
    private static let proximityMaxIntensity: Float = 0.9

    // MARK: - Init

    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

        guard supportsHaptics else {
            print("[HapticManager] Device does not support haptics")
            return
        }

        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                do { try self?.engine?.start() } catch {
                    print("[HapticManager] Failed to restart engine: \(error)")
                }
            }
            engine?.stoppedHandler = { reason in
                print("[HapticManager] Engine stopped: \(reason)")
            }
            try engine?.start()
        } catch {
            print("[HapticManager] Failed to create engine: \(error)")
        }
    }

    // MARK: - Obstacle hit

    func playObstacleHit() {
        guard supportsHaptics, let engine = engine else { return }
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player  = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticManager] Obstacle hit error: \(error)")
        }
    }

    // MARK: - Baygon win

    func playBaygonWin() {
        guard supportsHaptics, let engine = engine else { return }
        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0.12),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ], relativeTime: 0.24),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0.32, duration: 0.4)
            ]
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player  = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticManager] Baygon win error: \(error)")
        }
    }

    // MARK: - Bait trigger

    func playBaitTrigger() {
        guard supportsHaptics, let engine = engine else { return }
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0, duration: 0.9
            )
            let rampUp = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0,   value: 0.1),
                    .init(relativeTime: 0.5, value: 0.7),
                    .init(relativeTime: 0.9, value: 1.0)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameterCurves: [rampUp])
            let player  = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticManager] Bait trigger error: \(error)")
        }
    }

    // MARK: - Game over

    func playGameOver() {
        guard supportsHaptics, let engine = engine else { return }
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0, duration: 1.2
            )
            let rampDown = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0,   value: 1.0),
                    .init(relativeTime: 1.2, value: 0.0)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameterCurves: [rampDown])
            let player  = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticManager] Game over error: \(error)")
        }
    }

    // MARK: - Roach proximity (continuous, modulated every frame)

    func updateRoachProximity(closestDistance: Float) {
        guard supportsHaptics, let engine = engine else { return }

        let start = Self.proximityStartDist
        let end   = Self.proximityMaxDist

        // Outside range — stop if running
        guard closestDistance < start else {
            stopProximity()
            return
        }

        let t         = 1.0 - min(max((closestDistance - end) / (start - end), 0), 1)
        let intensity = Self.proximityMinIntensity + t * (Self.proximityMaxIntensity - Self.proximityMinIntensity)
        let sharpness = Float(0.3 + t * 0.3)

        if !proximityRunning {
            // Start the continuous player
            do {
                let event = CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: 0,
                    duration: 100
                )
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                proximityPlayer  = try engine.makeAdvancedPlayer(with: pattern)
                try proximityPlayer?.start(atTime: CHHapticTimeImmediate)
                proximityRunning = true
            } catch {
                print("[HapticManager] Proximity start error: \(error)")
            }
        } else {
            // Already running — update intensity dynamically
            do {
                try proximityPlayer?.sendParameters([
                    CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0),
                    CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: sharpness, relativeTime: 0)
                ], atTime: CHHapticTimeImmediate)
            } catch {
            }
        }
    }

    private func stopProximity() {
        guard proximityRunning else { return }
        try? proximityPlayer?.stop(atTime: CHHapticTimeImmediate)
        proximityPlayer  = nil
        proximityRunning = false
    }

    // MARK: - Teardown

    func stop() {
        stopProximity()
        engine?.stop(completionHandler: nil)
    }
}
