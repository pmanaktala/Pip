import Foundation

/// Time-derived idle motion layered on top of a resolved rig.
///
/// Everything is a pure function of `time`, so the same instant renders identically
/// in the app and in a static widget snapshot, and Reduce Motion simply passes `nil`.
/// Motion is built from *scheduled, eased gestures* (a hop with anticipation and a
/// landing, a shiver burst, a sigh) rather than continuous sines, so the pet reads as
/// an animal doing things instead of a shape oscillating.
public struct LiveMotion: Equatable, Sendable {
    /// 0…1 how far into an inhale the chest is.
    public var breath: Double = 0
    /// Vertical lift in canvas units (positive = up).
    public var hop: Double = 0
    /// Vertical scale about the feet; the painter compensates horizontally.
    public var squash: Double = 1
    /// Whole-body lean in degrees, added to the rig's lean.
    public var lean: Double = 0
    /// -1…1 tail swing.
    public var tailWag: Double = 0
    /// -1…1 arm / flipper swing.
    public var armSwing: Double = 0
    /// Horizontal shiver offset in canvas units.
    public var shiverX: Double = 0
    /// 0…1 momentary ear flick.
    public var earTwitch: Double = 0
    /// Extra head drop (nodding off, sighing). Canvas units, positive = lower.
    public var headBob: Double = 0

    public static let still = LiveMotion()
}

public enum PetAnimator {

    /// Applies idle behaviour to `rig` for the given time. Returns the adjusted rig and motion extras.
    public static func animate(rig base: PetRig, motion: PetMotionProfile, time: TimeInterval?) -> (rig: PetRig, live: LiveMotion) {
        guard let t = time else { return (base, .still) }
        var rig = base
        var live = LiveMotion()

        // Breathing – a quick, eased inhale and a slow exhale. Lifts the head a touch.
        let breathPhase = (t * motion.breathRate).truncatingRemainder(dividingBy: 1)
        live.breath = breathPhase < 0.42 ? smoothstep(breathPhase / 0.42) : 1 - smoothstep((breathPhase - 0.42) / 0.58)
        live.squash = 1 + motion.breathAmount * live.breath
        live.headBob = -live.breath * 0.8

        // Weight shift – hold a lean, then ease to the next one. Never a metronome.
        if motion.swayAmount > 0 {
            let cycle = floor(t / motion.swayPeriod)
            let phase = t - cycle * motion.swayPeriod
            let prev = swayTarget(cycle - 1), next = swayTarget(cycle)
            let e = smoothstep(min(phase / 1.4, 1))
            live.lean = (prev + (next - prev) * e) * motion.swayAmount
        }

        // Hop – anticipation squash, parabolic flight, landing squash with a tiny rebound.
        if motion.hopHeight > 0, let (phase, _) = gesture(t, interval: motion.hopInterval, duration: 0.62, seed: 11) {
            let anticipate = 0.22, flight = 0.5
            if phase < anticipate {
                let k = smoothstep(phase / anticipate)
                live.squash *= 1 - 0.07 * sin(k * .pi)
            } else if phase < anticipate + flight {
                let u = (phase - anticipate) / flight
                live.hop = motion.hopHeight * 4 * u * (1 - u)
                live.squash *= 1 + 0.05 * (1 - u) * (1 - u)
                live.armSwing = sin(u * .pi)
            } else {
                let u = (phase - anticipate - flight) / (1 - anticipate - flight)
                live.squash *= 1 - 0.09 * sin(u * .pi) * (1 - u) + 0.015 * sin(u * .pi * 2) * u
            }
        }

        // Tail wag / flipper flap – wag has a slight pause at each extreme.
        if motion.tailWagRate > 0, motion.tailWagAmount > 0 {
            let w = sin(t * motion.tailWagRate * 2 * .pi)
            live.tailWag = (w * abs(w)).clamped(-1, 1) * motion.tailWagAmount
        }
        if live.armSwing == 0 { live.armSwing = live.tailWag * 0.5 }

        // Shiver – comes in short bursts, not a constant buzz.
        if motion.shiver > 0, let (phase, _) = gesture(t, interval: 2.4, duration: 0.7, seed: 23) {
            let envelope = sin(phase * .pi)
            live.shiverX = sin(t * 2 * .pi * 9) * motion.shiver * envelope
        }

        // Nodding off – slow droop with an occasional jerk awake.
        if motion.nod > 0 {
            let droop = 0.5 - 0.5 * cos(t * 2 * .pi / 5.5)
            var bob = motion.nod * droop
            if let (phase, _) = gesture(t, interval: 9, duration: 0.5, seed: 31) {
                bob -= motion.nod * 0.8 * sin(phase * .pi)
            }
            live.headBob += bob
        }

        // Sigh – one deep breath: chest swells, head rises, then everything settles lower.
        if motion.sigh > 0, let (phase, _) = gesture(t, interval: 8, duration: 2.4, seed: 41) {
            let inhale = phase < 0.35 ? smoothstep(phase / 0.35) : 1 - smoothstep((phase - 0.35) / 0.65)
            live.squash *= 1 + motion.sigh * 0.035 * inhale
            live.headBob += -motion.sigh * 2.5 * inhale + motion.sigh * 1.5 * sin(phase * .pi) * (phase > 0.35 ? 1 : 0)
        }

        // Blink – deterministic pseudo-random schedule with an eased close and open.
        if motion.blinkInterval.isFinite, rig.eyeOpen > 0.05 {
            let cycle = floor(t / motion.blinkInterval)
            let jitter = hash01(cycle) * 0.6 + 0.7 // 0.7…1.3 × interval
            let phase = t - cycle * motion.blinkInterval
            let blinkAt = motion.blinkInterval * (jitter - 0.5)
            let d = phase - blinkAt
            if d >= 0 && d < 0.16 {
                let k = d < 0.06 ? smoothstep(d / 0.06) : 1 - smoothstep((d - 0.06) / 0.1)
                rig.eyeOpen *= (1 - 0.97 * k)
            }
            // Occasional double blink on higher-energy moods.
            if motion.blinkInterval < 2.2 && d >= 0.22 && d < 0.36 {
                let dd = d - 0.22
                let k = dd < 0.05 ? smoothstep(dd / 0.05) : 1 - smoothstep((dd - 0.05) / 0.09)
                rig.eyeOpen *= (1 - 0.9 * k)
            }
        }

        // Gaze – glance somewhere every few seconds; the head follows a little.
        if motion.gazeInterval.isFinite {
            let cycle = floor(t / motion.gazeInterval)
            let phase = t - cycle * motion.gazeInterval
            let prev = gazeTarget(cycle - 1)
            let next = gazeTarget(cycle)
            let e = smoothstep(min(phase / 0.32, 1))
            let gx = prev.x + (next.x - prev.x) * e
            let gy = prev.y + (next.y - prev.y) * e
            rig.gazeX = rig.gazeX * 0.4 + gx * 0.6
            rig.gazeY = rig.gazeY * 0.6 + gy * 0.4
            rig.headTurn = (rig.headTurn + gx * 0.3).clamped(-1, 1)
        }

        // Ear twitch – short, rare.
        if motion.earTwitch > 0 {
            let cycle = floor(t / 6)
            let phase = t - cycle * 6
            let at = 1 + hash01(cycle + 17) * 4
            let d = phase - at
            if d >= 0, d < 0.25, hash01(cycle + 3) < motion.earTwitch {
                live.earTwitch = sin(d / 0.25 * .pi)
            }
        }

        return (rig, live)
    }

    // MARK: - Helpers

    /// Phase (0…1) of a gesture that fires once per `interval` at a jittered moment and lasts `duration`.
    static func gesture(_ t: Double, interval: Double, duration: Double, seed: Double) -> (phase: Double, cycle: Double)? {
        let cycle = floor(t / interval)
        let phase = t - cycle * interval
        let at = (interval - duration) * hash01(cycle + seed)
        let d = phase - at
        guard d >= 0, d < duration else { return nil }
        return (d / duration, cycle)
    }

    private static func swayTarget(_ cycle: Double) -> Double {
        let r = hash01(cycle + 53)
        return r < 0.33 ? -1 : (r < 0.66 ? 0 : 1)
    }

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

    static func smoothstep(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}
