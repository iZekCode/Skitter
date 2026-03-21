import CoreHaptics
import UIKit

/// Manages CoreHaptics engine and provides predefined haptic patterns
class HapticManager {
    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool

    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

        guard supportsHaptics else {
            print("[HapticManager] Device does not support haptics")
            return
        }

        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                do {
                    try self?.engine?.start()
                } catch {
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

    /// Sharp transient hit — obstacle collision
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
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticManager] Obstacle hit haptic error: \(error)")
        }
    }

    /// Game over — continuous ramp down
    func playGameOver() {
        guard supportsHaptics, let engine = engine else { return }

        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0,
                duration: 1.2
            )

            let rampDown = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: 1.0),
                    .init(relativeTime: 1.2, value: 0)
                ],
                relativeTime: 0
            )

            let pattern = try CHHapticPattern(events: [event], parameterCurves: [rampDown])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticManager] Game over haptic error: \(error)")
        }
    }
    
    /// Three rapid transient bursts — baygon found, victory
    func playBaygonWin() {
        guard supportsHaptics, let engine = engine else { return }

        do {
            let events: [CHHapticEvent] = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0.12
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0.24
                ),
                // Sustained tail — relief/triumph feel
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.32,
                    duration: 0.4
                )
            ]

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticManager] Baygon win haptic error: \(error)")
        }
    }

    /// Ramp-up continuous — dread, something bad just happened
    func playBaitTrigger() {
        guard supportsHaptics, let engine = engine else { return }

        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
                duration: 0.9
            )

            // Intensity ramps UP — opposite of game over ramp-down
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
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticManager] Bait trigger haptic error: \(error)")
        }
    }

    func stop() {
        engine?.stop(completionHandler: nil)
    }
}
