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
    /// 0…1 how far a held prop (the umbrella) is raised. Props follow `hop`, `lean` and `shiverX`.
    public var prop: Double = 1

    public static let still = LiveMotion()
}

public enum PetAnimator {

    /// Applies idle behaviour to `rig` for the given time. Returns the adjusted rig and motion extras.
    public static func animate(rig base: PetRig, motion: PetMotionProfile, time: TimeInterval?) -> (rig: PetRig, live: LiveMotion) {
        guard let t = time else { return (base, .still) }
        var rig = base
        var live = LiveMotion()

        // Breathing – a quick, eased inhale and a slow exhale. Lifts the head a touch.
        live.breath = breath(phase: t * motion.breathRate)
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

        performBit(motion.bit, interval: motion.bitInterval, t: t, rig: &rig, live: &live)
        // A hop and a bit can coincide; keep the head inside the 200pt canvas regardless.
        live.hop = min(live.hop, 26)
        live.lean = live.lean.clamped(-16, 16)

        return (rig, live)
    }

    /// The breathing curve: a quick, eased inhale (42% of the cycle) and a slow exhale.
    public static func breath(phase: Double) -> Double {
        let p = phase - floor(phase)
        return p < 0.42 ? smoothstep(p / 0.42) : 1 - smoothstep((p - 0.42) / 0.58)
    }

    // MARK: - Bits

    /// Signature business per mood. Big, eased, and rare enough to be a treat.
    static func performBit(_ bit: PetBit, interval: Double, t: Double, rig: inout PetRig, live: inout LiveMotion) {
        switch bit {
        case .none:
            break

        case .wiggle:
            guard let (p, _) = gesture(t, interval: interval, duration: 1.6, seed: 71) else { return }
            let env = sin(p * .pi)
            live.lean += sin(p * .pi * 4) * 9 * env
            live.armSwing = sin(p * .pi * 4) * env
            live.squash *= 1 + 0.03 * sin(p * .pi * 8) * env
            rig.eyeArc = max(rig.eyeArc, env)
            rig.mouthOpen = max(rig.mouthOpen, 0.3 * env)
            rig.tilt += sin(p * .pi * 2) * 6 * env

        case .zoomies:
            guard let (p, cycle) = gesture(t, interval: interval, duration: 1.3, seed: 73) else { return }
            let dir: Double = hash01(cycle + 5) < 0.5 ? -1 : 1
            let bounce = abs(sin(p * .pi * 2))
            live.hop += 16 * bounce
            live.squash *= 1 + 0.06 * bounce - 0.08 * max(0, cos(p * .pi * 4)) * (1 - bounce)
            live.lean += sin(p * .pi * 2) * 12 * dir
            live.armSwing = 1
            rig.headTurn = (rig.headTurn + sin(p * .pi * 2) * 0.9 * dir).clamped(-1, 1)
            rig.eyeScale *= 1 + 0.15 * sin(p * .pi)
            rig.mouthOpen = max(rig.mouthOpen, 0.8 * sin(p * .pi))

        case .stretch:
            guard let (p, _) = gesture(t, interval: interval, duration: 3.2, seed: 79) else { return }
            let k = p < 0.4 ? smoothstep(p / 0.4) : 1 - smoothstep((p - 0.4) / 0.6)
            live.squash *= 1 + 0.09 * k
            live.headBob -= 4 * k
            rig.armRaise = max(rig.armRaise, 0.75 * k)
            rig.eyeOpen *= 1 - 0.92 * k
            rig.mouthOpen = max(rig.mouthOpen, 0.35 * k)
            rig.mouthCurve = max(rig.mouthCurve, 0.5 * k)
            rig.headDrop = min(rig.headDrop, rig.headDrop * (1 - k))

        case .curious:
            guard let (p, cycle) = gesture(t, interval: interval, duration: 2.0, seed: 83) else { return }
            let side: Double = hash01(cycle + 9) < 0.5 ? -1 : 1
            let k = p < 0.25 ? smoothstep(p / 0.25) : (p < 0.75 ? 1 : 1 - smoothstep((p - 0.75) / 0.25))
            rig.tilt += 14 * side * k
            rig.gazeX = (rig.gazeX + 0.45 * side * k).clamped(-1, 1)
            rig.eyeScale *= 1 + 0.08 * k
            rig.earLift = max(rig.earLift, k)
            if p < 0.3 { live.earTwitch = max(live.earTwitch, sin(p / 0.3 * .pi)) }

        case .flop:
            guard let (p, cycle) = gesture(t, interval: interval, duration: 4.5, seed: 89) else { return }
            let side: Double = hash01(cycle + 13) < 0.5 ? -1 : 1
            if p < 0.45 {
                // Nodding off: the body slowly keels over and the eyes give up.
                let k = smoothstep(p / 0.45)
                rig.lying = min(1, rig.lying + 0.6 * k)
                rig.eyeOpen *= 1 - 0.95 * k
                rig.headDrop = max(rig.headDrop, k)
                live.lean += 9 * side * k
                live.headBob += 3 * k
            } else if p < 0.82 {
                rig.lying = min(1, rig.lying + 0.6)
                rig.eyeOpen *= 0.05
                rig.headDrop = 1
                live.lean += 9 * side
                live.headBob += 3
            } else {
                // Jerk awake: snap upright, eyes wide, a startled little hop, then blink back down.
                let u = (p - 0.82) / 0.18
                let snap = 1 - smoothstep(u * 2.5)
                rig.lying = min(1, rig.lying + 0.6 * snap)
                live.lean += 9 * side * snap
                live.hop += 5 * sin(min(u * 2, 1) * .pi)
                rig.eyeOpen = max(rig.eyeOpen, 1 - smoothstep((u - 0.5) * 2))
                rig.eyeScale *= 1 + 0.25 * (1 - u)
                rig.lidHeaviness *= u
                rig.headDrop *= u
            }

        case .fidget:
            guard let (p, _) = gesture(t, interval: interval, duration: 1.1, seed: 97) else { return }
            let env = sin(p * .pi)
            let look = sin(p * .pi * 3) * env
            rig.headTurn = (look * 0.9).clamped(-1, 1)
            rig.gazeX = look
            rig.sweat = max(rig.sweat, env)
            rig.eyeScale *= 1 + 0.1 * env
            live.earTwitch = max(live.earTwitch, env)

        case .stomp:
            guard let (p, _) = gesture(t, interval: interval, duration: 1.4, seed: 101) else { return }
            let env = sin(p * .pi)
            // Two stomps: lift, then slam (squash), with a lean into each one.
            let beat = sin(p * .pi * 4)
            live.hop += 5 * max(0, beat)
            live.squash *= 1 - 0.14 * max(0, -beat)
            live.lean += sin(p * .pi * 2) * 5 * env
            rig.armRaise = max(rig.armRaise, 0.9 * env)
            rig.browInnerUp = min(rig.browInnerUp, -1)
            rig.mouthOpen = max(rig.mouthOpen, 0.5 * max(0, -beat))
            rig.eyeSquint = max(rig.eyeSquint, 0.7 * env)

        case .sniffle:
            guard let (p, _) = gesture(t, interval: interval, duration: 2.6, seed: 103) else { return }
            if p < 0.3 {
                // Two quick sniffs.
                let k = sin(p / 0.3 * .pi * 2)
                live.squash *= 1 + 0.025 * abs(k)
                live.headBob -= 1.5 * abs(k)
                rig.mouthWobble = max(rig.mouthWobble, 0.8)
            } else {
                // A slow shake of the head, and the umbrella dips with it.
                let u = (p - 0.3) / 0.7
                let env = sin(u * .pi)
                rig.headTurn = (sin(u * .pi * 3) * 0.6 * env).clamped(-1, 1)
                live.prop = 1 - 0.25 * env
            }

        case .meditate:
            // Continuous: a slow float, eyes closed, a soft mouth, paws together (arms half raised).
            live.hop += 4 + 2.5 * sin(t * 0.7)
            live.lean *= 0.3
            rig.eyeOpen = 0
            rig.eyeArc = 0
            rig.mouthCurve = 0.5
            rig.mouthOpen = 0
            rig.armRaise = 0.45
            rig.headDrop = 0.05
            rig.tilt = 0
            rig.gazeX = 0
            rig.gazeY = 0
            rig.headTurn = 0
        }
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
