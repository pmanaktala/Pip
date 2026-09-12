import Foundation

/// Time-derived idle motion layered on top of a resolved rig.
///
/// Everything is a pure function of `time`, so the same instant renders identically
/// in the app and in a static widget snapshot, and Reduce Motion simply passes `nil`.
public struct LiveMotion: Equatable, Sendable {
    public var breathScale: Double = 1
    public var bounce: Double = 0
    /// -1…1 tail swing.
    public var tailWag: Double = 0
    public var jitterX: Double = 0
    public var jitterY: Double = 0
    public var sway: Double = 0
    public var earTwitch: Double = 0

    public static let still = LiveMotion()
}

public enum PetAnimator {

    /// Applies idle behaviour to `rig` for the given time. Returns the adjusted rig and motion extras.
    public static func animate(rig base: PetRig, motion: PetMotionProfile, time: TimeInterval?) -> (rig: PetRig, live: LiveMotion) {
        guard let t = time else { return (base, .still) }
        var rig = base
        var live = LiveMotion()

        // Breathing – asymmetric (quick in, slow out) reads as more alive than a sine.
        let breathPhase = (t * motion.breathRate).truncatingRemainder(dividingBy: 1)
        let breath = breathPhase < 0.4 ? sin(breathPhase / 0.4 * .pi / 2) : cos((breathPhase - 0.4) / 0.6 * .pi / 2)
        live.breathScale = 1 + motion.breathAmount * breath

        // Bounce – |sin| gives a hop with a hard landing.
        if motion.bounceAmount > 0 {
            live.bounce = -abs(sin(t * motion.bounceRate * .pi)) * motion.bounceAmount
        }

        // Tail wag.
        if motion.tailWagRate > 0, motion.tailWagAmount > 0 {
            live.tailWag = sin(t * motion.tailWagRate * 2 * .pi) * motion.tailWagAmount
        }

        // Stress jitter – layered incommensurate sines look random without being noisy.
        if motion.jitter > 0 {
            live.jitterX = (sin(t * 23.0) * 0.6 + sin(t * 37.0) * 0.4) * motion.jitter
            live.jitterY = (sin(t * 29.0 + 1) * 0.5) * motion.jitter * 0.5
        }

        // Sway.
        if motion.swayAmount > 0 {
            live.sway = sin(t * motion.swayRate * 2 * .pi) * motion.swayAmount
        }

        // Blink – deterministic pseudo-random schedule.
        if motion.blinkInterval.isFinite, rig.eyeOpen > 0.05 {
            let cycle = floor(t / motion.blinkInterval)
            let jitter = hash01(cycle) * 0.6 + 0.7 // 0.7…1.3 × interval
            let phase = t - cycle * motion.blinkInterval
            let blinkAt = motion.blinkInterval * (jitter - 0.5)
            let d = phase - blinkAt
            if d >= 0 && d < 0.14 {
                let k = sin(d / 0.14 * .pi) // 0→1→0
                rig.eyeOpen *= (1 - 0.95 * k)
            }
            // Occasional double blink on higher-energy moods.
            if motion.blinkInterval < 2 && d >= 0.2 && d < 0.32 {
                let k = sin((d - 0.2) / 0.12 * .pi)
                rig.eyeOpen *= (1 - 0.9 * k)
            }
        }

        // Gaze – glance somewhere every few seconds, ease over 0.3s.
        if motion.gazeInterval.isFinite {
            let cycle = floor(t / motion.gazeInterval)
            let phase = t - cycle * motion.gazeInterval
            let prev = gazeTarget(cycle - 1)
            let next = gazeTarget(cycle)
            let e = smoothstep(min(phase / 0.3, 1))
            let gx = prev.x + (next.x - prev.x) * e
            let gy = prev.y + (next.y - prev.y) * e
            rig.gazeX = rig.gazeX * 0.4 + gx * 0.6
            rig.gazeY = rig.gazeY * 0.6 + gy * 0.4
        }

        // Ear twitch – short, rare.
        if motion.earTwitch > 0 {
            let cycle = floor(t / 6)
            let phase = t - cycle * 6
            let at = 1 + hash01(cycle + 17) * 4
            let d = phase - at
            if d >= 0, d < 0.25, hash01(cycle + 3) < motion.earTwitch {
                live.earTwitch = sin(d / 0.25 * .pi) * 0.25
            }
        }

        return (rig, live)
    }

    // MARK: - Helpers

    private static func gazeTarget(_ cycle: Double) -> (x: Double, y: Double) {
        // Mostly centred with the occasional glance to the side or up.
        let r = hash01(cycle)
        let a = hash01(cycle + 101)
        if r < 0.45 { return (0, 0) }
        let angle = a * 2 * .pi
        let radius = 0.25 + hash01(cycle + 7) * 0.3
        return (cos(angle) * radius, sin(angle) * radius * 0.6)
    }

    static func hash01(_ x: Double) -> Double {
        let s = sin(x * 12.9898 + 78.233) * 43758.5453
        return s - floor(s)
    }

    static func smoothstep(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}
