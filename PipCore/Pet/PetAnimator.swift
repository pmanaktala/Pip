import Foundation

/// Time-derived idle motion layered on top of a resolved rig.
///
/// Everything is a pure function of `time`, so the same instant renders identically
/// in the app and in a static widget snapshot, and Reduce Motion simply passes `nil`.
/// Motion is built from *scheduled, eased gestures* (a hop with anticipation and a
/// landing, a shiver burst, a sigh) rather than continuous sines, so the pet reads as
/// an animal doing things instead of a shape oscillating.
///
/// Body language rules (v2, see `Legacy/Animation-v1/README.md` for what changed):
/// - The body never tips over as a rigid piece. `lean` is a weight shift over planted feet
///   (`PetDraw.bodyTransform` shears it) and stays under ±24°; slumping comes from `lying`,
///   `headDrop` and `tilt`.
/// - Arms say what the pet is doing: a wave is one paw, a cheer or a stretch is both
///   (`armSymmetric`), typing reaches forward, a book is held, a tear is wiped (`armToFace`).
/// - One bit plays per `bitInterval`, in one slot (`bitWindow`), whichever bit was chosen.
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
    /// 0…1 state of a held prop: how high the umbrella is held, or 1 − page-turn progress.
    public var prop: Double = 1
    /// Head tilt in degrees that lags the body's lean, so the head follows through instead of
    /// moving as one rigid piece with the torso.
    public var headLag: Double = 0

    public static let still = LiveMotion()
}

public enum PetAnimator {

    /// The most a bit or a hop may lean the body, in degrees.
    public static let maxLean: Double = 24
    /// The highest the body may lift off the floor, in canvas units.
    public static let maxHop: Double = 22

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
        live.lean = sway(t, motion)

        // Hop – anticipation squash, stretch on the way up, parabolic flight, landing squash
        // with a small rebound. Both paws come up in the air, the way a happy animal jumps.
        if motion.hopHeight > 0, let (phase, _) = gesture(t, interval: motion.hopInterval, duration: 0.62, seed: 11) {
            let anticipate = 0.22, flight = 0.5
            let size = min(1, motion.hopHeight / 10)
            if phase < anticipate {
                let k = smoothstep(phase / anticipate)
                live.squash *= 1 - 0.12 * size * sin(k * .pi)
            } else if phase < anticipate + flight {
                let u = (phase - anticipate) / flight
                let air = sin(u * .pi)
                live.hop = motion.hopHeight * 4 * u * (1 - u)
                live.squash *= 1 + 0.10 * size * (1 - u) * (1 - u) - 0.04 * size * u * u
                live.armSwing = air
                if rig.armForward < 0.5, rig.armHold < 0.5 {
                    rig.armRaise = max(rig.armRaise, 0.7 * air * size)
                    rig.armSymmetric = max(rig.armSymmetric, air)
                }
            } else {
                let u = (phase - anticipate - flight) / (1 - anticipate - flight)
                live.squash *= 1 - 0.16 * size * sin(u * .pi) * (1 - u) + 0.03 * size * sin(u * .pi * 2) * u
            }
        }

        // Tail wag / flipper flap – wag has a slight pause at each extreme.
        if motion.tailWagRate > 0, motion.tailWagAmount > 0 {
            let w = sin(t * motion.tailWagRate * 2 * .pi)
            live.tailWag = (w * abs(w)).clamped(-1, 1) * motion.tailWagAmount
        }
        if live.armSwing == 0 { live.armSwing = live.tailWag * 0.35 }

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

        // The mood's bit, in this cycle's slot.
        if motion.bit == .meditate {
            performBit(.meditate, phase: 0, cycle: 0, t: t, rig: &rig, live: &live)
        } else if let window = bitWindow(motion, t: t) {
            performBit(window.bit, phase: window.phase, cycle: window.cycle, t: t, rig: &rig, live: &live)
        }

        // A hop and a bit can coincide; keep the head inside the 200pt canvas regardless.
        live.hop = min(live.hop, maxHop)
        live.lean = live.lean.clamped(-maxLean, maxLean)

        // Follow-through: the head lags the body's lean by a few frames, then catches up.
        let earlier = sway(t - 0.09, motion) + bitLean(motion, t: t - 0.09)
        let now = live.lean
        live.headLag = ((earlier - now) * 0.55).clamped(-8, 8)

        return (rig, live)
    }

    static func sway(_ t: Double, _ motion: PetMotionProfile) -> Double {
        guard motion.swayAmount > 0 else { return 0 }
        let cycle = floor(t / motion.swayPeriod)
        let phase = t - cycle * motion.swayPeriod
        let prev = swayTarget(cycle - 1), next = swayTarget(cycle)
        let e = smoothstep(min(phase / 1.4, 1))
        return (prev + (next - prev) * e) * motion.swayAmount
    }

    // MARK: - Bit scheduling

    /// The bits a profile can play, signature first.
    static func bitOptions(_ motion: PetMotionProfile) -> [PetBit] {
        guard motion.bit != .none, motion.bit != .meditate else { return [] }
        return [motion.bit] + motion.alternateBits.filter { $0 != .none && $0 != .meditate }
    }

    /// The length of one bit cycle: never shorter than the longest bit that could play in it.
    static func bitCycleLength(_ motion: PetMotionProfile) -> Double {
        let longest = bitOptions(motion).map(\.duration).max() ?? 0
        return max(motion.bitInterval, longest + 0.2)
    }

    /// Which bit plays in `cycle`: the signature one, or one of the alternates, chosen by cycle.
    static func chosenBit(_ motion: PetMotionProfile, cycle: Double) -> PetBit {
        let options = bitOptions(motion)
        guard !options.isEmpty else { return .none }
        return options[Int(hash01(cycle + 191) * Double(options.count)) % options.count]
    }

    /// Every cycle has exactly one slot at a jittered moment; the chosen bit fills it. This is
    /// the only place a bit is scheduled, so what plays and when it plays can never disagree.
    public static func bitWindow(_ motion: PetMotionProfile, t: Double) -> (bit: PetBit, phase: Double, cycle: Double)? {
        let length = bitCycleLength(motion)
        guard length > 0, motion.bit != .none, motion.bit != .meditate else { return nil }
        let cycle = floor(t / length)
        let bit = chosenBit(motion, cycle: cycle)
        guard bit != .none else { return nil }
        let start = bitStart(motion, cycle: cycle)
        let d = t - start
        guard d >= 0, d < bit.duration else { return nil }
        return (bit, d / bit.duration, cycle)
    }

    /// When the bit of `cycle` starts, in absolute time.
    public static func bitStart(_ motion: PetMotionProfile, cycle: Double) -> Double {
        let length = bitCycleLength(motion)
        let bit = chosenBit(motion, cycle: cycle)
        let slack = max(0, length - bit.duration)
        return cycle * length + slack * hash01(cycle + 191 + 0.5)
    }

    /// The first bit to start at or after `from`, for filmstrips and tests.
    public static func nextBit(_ motion: PetMotionProfile, from: Double) -> (bit: PetBit, start: Double)? {
        let length = bitCycleLength(motion)
        guard length > 0, !bitOptions(motion).isEmpty else { return nil }
        var cycle = floor(from / length)
        for _ in 0..<8 {
            let start = bitStart(motion, cycle: cycle)
            if start >= from { return (chosenBit(motion, cycle: cycle), start) }
            cycle += 1
        }
        return nil
    }

    /// The lean a bit contributes at `t`, for follow-through. Cheap: it re-runs the bit on a scratch rig.
    static func bitLean(_ motion: PetMotionProfile, t: Double) -> Double {
        guard let window = bitWindow(motion, t: t) else { return 0 }
        var rig = PetRig()
        var live = LiveMotion()
        performBit(window.bit, phase: window.phase, cycle: window.cycle, t: t, rig: &rig, live: &live)
        return live.lean
    }

    /// The breathing curve: a quick, eased inhale (42% of the cycle) and a slow exhale.
    public static func breath(phase: Double) -> Double {
        let p = phase - floor(phase)
        return p < 0.42 ? smoothstep(p / 0.42) : 1 - smoothstep((p - 0.42) / 0.58)
    }

    // MARK: - Bits

    /// Signature business per mood, as a function of the bit's own phase (0…1). Big, eased, and
    /// rare enough to be a treat. Every bit keeps the feet planted: hips swing (a sheared lean),
    /// the head counters, the arms do the talking.
    static func performBit(_ bit: PetBit, phase p: Double, cycle: Double, t: Double, rig: inout PetRig, live: inout LiveMotion) {
        switch bit {
        case .none:
            break

        case .wiggle:
            // A little dance: four hip swings, the head countering, arms out and swinging, a bounce on each beat.
            let env = sin(p * .pi)
            let beat = sin(p * .pi * 4)
            live.lean += beat * 9 * env
            rig.tilt += -beat * 5 * env
            live.armSwing = beat * env
            live.squash *= 1 + 0.05 * abs(sin(p * .pi * 8)) * env
            live.hop += 2.5 * max(0, sin(p * .pi * 8)) * env
            rig.armOut = max(rig.armOut, 0.9 * env)
            rig.armCross *= 1 - env
            rig.eyeArc = max(rig.eyeArc, env)
            rig.mouthOpen = max(rig.mouthOpen, 0.3 * env)
            rig.blush = max(rig.blush, 0.8 * env)

        case .zoomies:
            // Two big bounces with a full-body twist, both paws in the air.
            let dir: Double = hash01(cycle + 5) < 0.5 ? -1 : 1
            let bounce = abs(sin(p * .pi * 2))
            let landing = max(0, -cos(p * .pi * 4)) * (1 - bounce)
            live.hop += 11 * bounce
            live.squash *= 1 + 0.10 * bounce - 0.14 * landing
            live.lean += sin(p * .pi * 2) * 10 * dir
            live.armSwing = bounce
            rig.armRaise = max(rig.armRaise, bounce)
            rig.armSymmetric = max(rig.armSymmetric, bounce)
            rig.armOut = max(rig.armOut, 0.3 * bounce)
            rig.armCross *= 1 - bounce
            rig.headTurn = (rig.headTurn + sin(p * .pi * 2) * 0.9 * dir).clamped(-1, 1)
            rig.eyeScale *= 1 + 0.15 * sin(p * .pi)
            rig.mouthOpen = max(rig.mouthOpen, 0.8 * sin(p * .pi))

        case .stretch:
            // A long slow stretch: both paws up, up on tiptoe, a yawn — then melt down and shake it off.
            let k = p < 0.4 ? smoothstep(p / 0.4) : 1 - smoothstep((p - 0.4) / 0.6)
            live.squash *= 1 + 0.12 * k
            live.headBob -= 5 * k
            rig.armRaise = max(rig.armRaise, k)
            rig.armSymmetric = max(rig.armSymmetric, k)
            rig.armCross *= 1 - k
            rig.armHold *= 1 - k
            rig.armForward *= 1 - k
            rig.armToFace *= 1 - k
            rig.eyeOpen *= 1 - 0.95 * k
            rig.mouthOpen = max(rig.mouthOpen, 0.7 * k)
            rig.mouthCurve = max(rig.mouthCurve, 0.5 * k)
            rig.headDrop *= 1 - k
            rig.tilt += 5 * k
            if p > 0.86 {
                let u = (p - 0.86) / 0.14
                live.shiverX += sin(t * 2 * .pi * 11) * 1.6 * sin(u * .pi)
                live.earTwitch = max(live.earTwitch, sin(u * .pi))
            }

        case .curious:
            // Something over there: a big head tilt, ears up, a small lean toward it, a tiny hop.
            let side: Double = hash01(cycle + 9) < 0.5 ? -1 : 1
            let k = p < 0.25 ? smoothstep(p / 0.25) : (p < 0.75 ? 1 : 1 - smoothstep((p - 0.75) / 0.25))
            rig.tilt += 22 * side * k
            live.lean += 5 * side * k
            rig.gazeX = (rig.gazeX + 0.6 * side * k).clamped(-1, 1)
            rig.headTurn = (rig.headTurn + 0.5 * side * k).clamped(-1, 1)
            rig.eyeScale *= 1 + 0.12 * k
            rig.earLift = max(rig.earLift, k)
            if p < 0.3 { live.earTwitch = max(live.earTwitch, sin(p / 0.3 * .pi)); live.hop += 3 * sin(p / 0.3 * .pi) }

        case .flop:
            // Nod, nod… slump over sideways into a heap, snore, then jerk awake with a startled hop.
            let side: Double = hash01(cycle + 13) < 0.5 ? -1 : 1
            let baseLying = rig.lying
            func slump(_ k: Double) {
                rig.lying = baseLying + (0.9 - baseLying) * k
                rig.headDrop = max(rig.headDrop, k)
                rig.tilt += 18 * side * k
                live.lean += 8 * side * k
                live.headBob += 3 * k
                rig.armCross = max(rig.armCross, 0.4 * k)
            }
            if p < 0.35 {
                let u = p / 0.35
                let nods = max(0, sin(u * .pi * 3))
                live.headBob += 3.5 * nods
                rig.eyeOpen *= 1 - 0.85 * smoothstep(u)
                rig.tilt += 4 * side * u
            } else if p < 0.5 {
                let k = smoothstep((p - 0.35) / 0.15)
                slump(k)
                rig.eyeOpen *= 1 - 0.97 * max(k, 0.85)
            } else if p < 0.82 {
                let snore = sin((p - 0.5) / 0.32 * .pi * 4)
                slump(1)
                live.squash *= 1 + 0.03 * snore
                rig.eyeOpen *= 0.03
                rig.mouthOpen = max(rig.mouthOpen, 0.25 + 0.15 * snore)
            } else {
                let u = (p - 0.82) / 0.18
                let snap = 1 - smoothstep(u * 2.2)
                slump(snap)
                live.lean += sin(min(u * 2.2, 1) * .pi) * 4 * -side
                live.hop += 6 * sin(min(u * 2, 1) * .pi)
                live.squash *= 1 + 0.07 * sin(min(u * 2, 1) * .pi)
                rig.eyeOpen = max(rig.eyeOpen, 1 - smoothstep((u - 0.55) * 2.2))
                rig.eyeScale *= 1 + 0.3 * (1 - u)
                rig.lidHeaviness *= u
                rig.headDrop *= u
                rig.mouthOpen = max(rig.mouthOpen, 0.5 * (1 - u))
            }

        case .fidget:
            // Pace in place: quick looks left and right, hugging itself, a nervous shuffle, sweat.
            let env = sin(p * .pi)
            let look = sin(p * .pi * 3) * env
            rig.headTurn = (look * 0.9).clamped(-1, 1)
            rig.gazeX = look
            rig.sweat = max(rig.sweat, env)
            rig.eyeScale *= 1 + 0.12 * env
            rig.armCross = max(rig.armCross, env)
            live.lean += look * 5
            live.hop += 1.5 * abs(sin(p * .pi * 6)) * env
            live.earTwitch = max(live.earTwitch, env)

        case .stomp:
            // A tantrum: two stomps (fists up, leap, slam, shake), then arms crossed and face turned away. Hmph.
            if p < 0.55 {
                let u = p / 0.55
                let beat = sin(u * .pi * 4)
                let up = max(0, beat), slam = max(0, -beat)
                live.hop += 9 * up
                live.squash *= 1 + 0.06 * up - 0.18 * slam
                live.shiverX += sin(t * 2 * .pi * 18) * 2.5 * slam
                live.lean += sin(u * .pi * 2) * 4
                rig.armRaise = max(rig.armRaise, 0.9 * up)
                rig.armSymmetric = max(rig.armSymmetric, 1)
                rig.armCross *= 1 - up
                rig.browInnerUp = min(rig.browInnerUp, -1)
                rig.mouthOpen = max(rig.mouthOpen, 0.7 * slam)
                rig.eyeSquint = max(rig.eyeSquint, 0.7)
                rig.earLift = min(rig.earLift, 0.1)
            } else {
                let u = (p - 0.55) / 0.45
                let k = u < 0.2 ? smoothstep(u / 0.2) : (u < 0.8 ? 1 : 1 - smoothstep((u - 0.8) / 0.2))
                rig.armCross = max(rig.armCross, k)
                rig.headTurn = (rig.headTurn + 0.9 * k).clamped(-1, 1)
                rig.eyeOpen *= 1 - 0.9 * k
                rig.tilt -= 8 * k
                live.headBob -= 2 * k
            }

        case .sniffle:
            // Two sniffs, a slow shake of the head under the umbrella, then the free paw wipes an eye.
            if p < 0.25 {
                let k = sin(p / 0.25 * .pi * 2)
                live.squash *= 1 + 0.04 * abs(k)
                live.headBob -= 2.5 * abs(k)
                rig.mouthWobble = max(rig.mouthWobble, 0.8)
                rig.browInnerUp = max(rig.browInnerUp, 1)
            } else if p < 0.6 {
                let u = (p - 0.25) / 0.35
                let env = sin(u * .pi)
                rig.headTurn = (sin(u * .pi * 3) * 0.6 * env).clamped(-1, 1)
                live.prop = 1 - 0.25 * env
            } else {
                let u = (p - 0.6) / 0.4
                let env = sin(u * .pi)
                rig.armToFace = max(rig.armToFace, env)
                rig.eyeOpen *= 1 - 0.85 * env
                rig.tilt += 5 * env
                rig.headTurn = (rig.headTurn + sin(u * .pi * 6) * 0.08 * env).clamped(-1, 1)
            }

        case .tada:
            // Both paws flung up and wide, a hop, a huge grin; a little wobble side to side while up there.
            let env = sin(p * .pi)
            let up = p < 0.3 ? smoothstep(p / 0.3) : (p < 0.7 ? 1 : 1 - smoothstep((p - 0.7) / 0.3))
            rig.armOut = max(rig.armOut, up)
            rig.armRaise = max(rig.armRaise, 0.6 * up)
            rig.armSymmetric = max(rig.armSymmetric, up)
            rig.armCross *= 1 - up
            rig.eyeArc = max(rig.eyeArc, up)
            rig.mouthOpen = max(rig.mouthOpen, 0.6 * up)
            rig.mouthCurve = max(rig.mouthCurve, 1)
            rig.blush = max(rig.blush, up)
            live.hop += 8 * sin(min(p / 0.35, 1) * .pi) * (p < 0.35 ? 1 : 0)
            live.squash *= 1 + 0.06 * up
            live.lean += sin(p * .pi * 3) * 4 * env
            rig.tilt += -sin(p * .pi * 3) * 3 * env

        case .typing:
            // A burst of typing — paws alternating on the keys, head down at the screen — then a
            // lean back, a paw to the chin, a look at the ceiling, and back to it.
            if p < 0.6 {
                let env = sin(p / 0.6 * .pi)
                live.armSwing = sin(t * 2 * .pi * 7) * env
                rig.armForward = max(rig.armForward, 0.9)
                live.headBob += 1.2 * abs(sin(t * 2 * .pi * 3.5)) * env
                rig.gazeY = max(rig.gazeY, 0.5)
                rig.eyeSquint = max(rig.eyeSquint, 0.25 * env)
            } else {
                let u = (p - 0.6) / 0.4
                let k = sin(u * .pi)
                live.squash *= 1 + 0.05 * k
                live.headBob -= 4 * k
                rig.gazeY = rig.gazeY * (1 - k) - 0.6 * k
                rig.headDrop *= 1 - k
                rig.armForward *= 1 - k
                rig.armToFace = max(rig.armToFace, 0.9 * k)
                rig.mouthOpen = max(rig.mouthOpen, 0.2 * k)
                rig.tilt += 8 * k
            }

        case .pageTurn:
            // The right paw climbs to the top corner of the page and flicks it over, a glance up as
            // if something landed, back down to the book.
            if p < 0.5 {
                let k = sin(p / 0.5 * .pi)
                rig.armRaise = max(rig.armRaise, 0.9 * k)
                rig.armSymmetric = 0
                live.prop = 1 - k
            } else {
                let u = (p - 0.5) / 0.5
                let k = sin(u * .pi)
                rig.gazeY = rig.gazeY * (1 - k) - 0.3 * k
                rig.headDrop *= 1 - 0.8 * k
                rig.eyeScale *= 1 + 0.08 * k
                rig.tilt += 6 * k
            }

        case .snore:
            // Chest swells, a little whistle of the mouth, a twitch of the ear, lips smack.
            if p < 0.5 {
                let k = sin(p / 0.5 * .pi)
                live.squash *= 1 + 0.05 * k
                rig.mouthOpen = max(rig.mouthOpen, 0.35 * k)
                rig.mouthWidth *= 1 - 0.3 * k
                live.headBob -= 1.5 * k
            } else {
                let u = (p - 0.5) / 0.5
                live.earTwitch = max(live.earTwitch, sin(min(u * 2, 1) * .pi))
                rig.mouthCurve = max(rig.mouthCurve, 0.6 * sin(u * .pi))
                rig.mouthOpen = max(rig.mouthOpen, 0.15 * abs(sin(u * .pi * 3)) * (1 - u))
            }

        case .meditate:
            // Continuous: a slow float, eyes closed, a soft mouth, paws together.
            live.hop += 5 + 3 * sin(t * 0.7)
            live.lean *= 0.25
            rig.eyeOpen = 0
            rig.eyeArc = 0
            rig.mouthCurve = 0.5
            rig.mouthOpen = 0
            rig.armCross = 0.7
            rig.armRaise = 0
            rig.armOut = 0
            rig.armForward = 0
            rig.armHold = 0
            rig.armToFace = 0
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
        let at = max(0, interval - duration) * hash01(cycle + seed)
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
