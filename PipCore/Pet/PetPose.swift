import SwiftUI

/// Every drawable degree of freedom of a pet, as plain numbers.
///
/// A pose is what the renderer draws. Stances define a resting pose, clips add offsets to it,
/// and the director layers idle motion on top (see `Docs/Pets/Bible.md` §5). Because every
/// channel is a `Double`, poses add, scale and interpolate channel by channel, and SwiftUI can
/// animate between two of them on surfaces that cannot run a clock (widgets, Live Activities).
///
/// Units: lengths are in the 200 × 200 design space, angles in degrees, everything else 0…1
/// or −1…1 as noted. Paired channels are left/right *from the viewer's side*.
public struct PetPose: Equatable, Sendable {
    // MARK: Body
    /// Sideways shift of the whole pet.
    public var x = 0.0
    /// Height off the floor (a hop). Positive is up.
    public var lift = 0.0
    /// Positive squashes (wider, shorter), negative stretches. −1…1.
    public var squash = 0.0
    /// Lean in degrees, positive to the viewer's right. Sheared over the feet, never a rigid tip.
    public var lean = 0.0
    /// Chest expansion from breathing. 0…1.
    public var breath = 0.0
    /// Shoulders forward, head low, body a little shorter. 0…1.
    public var slump = 0.0
    /// Body yaw: the belly and feet slide toward the side it turns to. −1…1.
    public var turn = 0.0

    // MARK: Head
    public var headTilt = 0.0
    /// Head yaw, −1…1: features slide and the far eye narrows.
    public var headTurn = 0.0
    /// Head pitch, −1 (looking up) … 1 (chin down).
    public var headNod = 0.0
    /// Vertical head offset (positive is down).
    public var headBob = 0.0

    // MARK: Eyes
    /// Upper lids, 0 open … 1 closed.
    public var lidL = 0.0
    public var lidR = 0.0
    /// A blink: the eye squashes shut and opens again, 0…1. Separate from the lids so a blink
    /// never reads as an expression halfway through.
    public var blink = 0.0
    /// Lid slant: −1 sad (outer corners low), +1 cross (inner corners low).
    public var lidSlant = 0.0
    /// Lower lid rising into smiling eyes, 0…1. At 1 the eye is a `^` crescent.
    public var smileEyes = 0.0
    /// Eyes squeezed shut in a `> <` (a boop, a giggle). 0…1.
    public var squeeze = 0.0
    public var gazeX = 0.0
    public var gazeY = 0.0
    /// Eye size multiplier offset (0 is normal, 0.25 is wide).
    public var eyeWide = 0.0

    // MARK: Brows
    /// How much of the brows shows, 0…1.
    public var browShow = 0.0
    /// −1 worried (inner ends up) … +1 cross (inner ends down).
    public var browSlant = 0.0
    public var browRaise = 0.0

    // MARK: Mouth
    /// −1 frown … +1 smile.
    public var smile = 0.0
    /// 0 closed … 1 wide open.
    public var mouthOpen = 0.0
    /// Rounds an open mouth into an "o" (a yawn, a gasp, a hum). 0…1.
    public var mouthRound = 0.0
    public var cheekPuff = 0.0
    public var blush = 0.0

    // MARK: Ears, arms, feet, tail
    /// −1 flat back … 0 rest … 1 perked.
    public var earL = 0.0
    public var earR = 0.0
    /// Arm angle in degrees from resting at the side. Positive swings out and up (90 is level,
    /// 160 overhead); negative folds across the body (−60 paw at the chest, −110 paw at the face).
    public var armL = 0.0
    public var armR = 0.0
    /// Sitting cross-legged (meditation): feet tuck in and overlap, haunches spread. 0…1.
    public var crossLegs = 0.0
    /// Feet off the floor, for steps and stomps.
    public var stepL = 0.0
    public var stepR = 0.0
    /// Tail swing −1…1 and height −1 (tucked) … 1 (high).
    public var tail = 0.0
    public var tailUp = 0.0

    // MARK: Props and effects (intensities 0…1)
    /// Raises a held prop toward the mouth (a sip), 0…1.
    public var propLift = 0.0
    public var tears = 0.0
    public var sweat = 0.0
    public var zzz = 0.0
    public var notes = 0.0
    public var hearts = 0.0
    public var sparkles = 0.0
    public var steam = 0.0
    public var question = 0.0
    /// A little thought cloud (daydreaming).
    public var thought = 0.0
    public var exclaim = 0.0
    /// Bubbles rising from its mouth (it blows them), 0…1.
    public var bubble = 0.0
    /// Holding its favourite ball out to you, 0 … 1 (drawn from 0.5).
    public var holdToy = 0.0
    /// How much of the snack in its paws is eaten: 0 whole … 1 gone.
    public var bite = 0.0

    public init() {}

    /// Every channel, in a fixed order. Arithmetic, interpolation and animation go through this.
    public static let channels: [WritableKeyPath<PetPose, Double>] = [
        \.x, \.lift, \.squash, \.lean, \.breath, \.slump, \.turn,
        \.headTilt, \.headTurn, \.headNod, \.headBob,
        \.lidL, \.lidR, \.blink, \.lidSlant, \.smileEyes, \.squeeze, \.gazeX, \.gazeY, \.eyeWide,
        \.browShow, \.browSlant, \.browRaise,
        \.smile, \.mouthOpen, \.mouthRound, \.cheekPuff, \.blush,
        \.earL, \.earR, \.armL, \.armR, \.crossLegs, \.stepL, \.stepR, \.tail, \.tailUp,
        \.propLift, \.tears, \.sweat, \.zzz, \.notes, \.hearts, \.sparkles, \.steam, \.question, \.exclaim, \.thought, \.bubble, \.holdToy, \.bite,
    ]

    /// A pose with every channel at zero — the identity for additive layers.
    public static let zero = PetPose()

    public static func + (a: PetPose, b: PetPose) -> PetPose {
        var r = a
        for k in channels { r[keyPath: k] += b[keyPath: k] }
        return r
    }

    public static func * (a: PetPose, s: Double) -> PetPose {
        var r = a
        for k in channels { r[keyPath: k] *= s }
        return r
    }

    /// Linear interpolation, channel by channel.
    public static func mix(_ a: PetPose, _ b: PetPose, _ t: Double) -> PetPose {
        var r = a
        for k in channels { r[keyPath: k] += (b[keyPath: k] - a[keyPath: k]) * t }
        return r
    }

    /// Adds `layer` scaled by `weight`.
    public func adding(_ layer: PetPose, weight: Double = 1) -> PetPose {
        guard weight != 0 else { return self }
        var r = self
        for k in Self.channels { r[keyPath: k] += layer[keyPath: k] * weight }
        return r
    }

    /// Keeps every channel inside the range the renderer is designed for.
    public func clamped() -> PetPose {
        var p = self
        p.lift = p.lift.clamped(-6, 30)
        p.squash = p.squash.clamped(-0.6, 0.6)
        p.lean = p.lean.clamped(-22, 22)
        p.breath = p.breath.clamped(-0.5, 1.5)
        p.slump = p.slump.clamped(0, 1)
        p.turn = p.turn.clamped(-1, 1)
        p.headTilt = p.headTilt.clamped(-28, 28)
        p.headTurn = p.headTurn.clamped(-1, 1)
        p.headNod = p.headNod.clamped(-1, 1)
        p.headBob = p.headBob.clamped(-12, 16)
        for k in [\PetPose.lidL, \.lidR, \.blink, \.smileEyes, \.squeeze, \.browShow, \.mouthOpen, \.mouthRound, \.cheekPuff, \.blush, \.slump,
                  \.propLift, \.tears, \.sweat, \.zzz, \.notes, \.hearts, \.sparkles, \.steam, \.question, \.exclaim, \.thought, \.bubble, \.holdToy, \.bite] {
            p[keyPath: k] = p[keyPath: k].clamped(0, 1)
        }
        for k in [\PetPose.lidSlant, \.browSlant, \.browRaise, \.smile, \.gazeX, \.gazeY, \.earL, \.earR, \.tail, \.tailUp] {
            p[keyPath: k] = p[keyPath: k].clamped(-1, 1)
        }
        p.eyeWide = p.eyeWide.clamped(-0.3, 0.4)
        p.armL = p.armL.clamped(-130, 175)
        p.armR = p.armR.clamped(-130, 175)
        p.stepL = p.stepL.clamped(0, 14)
        p.stepR = p.stepR.clamped(0, 14)
        return p
    }
}

// MARK: - Animation support

extension PetPose {
    /// The pose as a vector so SwiftUI can interpolate it.
    public struct Vector: VectorArithmetic, Sendable {
        public var values: [Double]

        public init(_ values: [Double]) { self.values = values }

        public static var zero: Vector { Vector(Array(repeating: 0, count: PetPose.channels.count)) }

        public static func + (a: Vector, b: Vector) -> Vector { Vector(zip(a.padded, b.padded).map(+)) }
        public static func - (a: Vector, b: Vector) -> Vector { Vector(zip(a.padded, b.padded).map(-)) }
        public mutating func scale(by rhs: Double) { values = padded.map { $0 * rhs } }
        public var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }

        private var padded: [Double] { values.isEmpty ? Array(repeating: 0, count: PetPose.channels.count) : values }
    }

    public var vector: Vector {
        get { Vector(Self.channels.map { self[keyPath: $0] }) }
        set {
            guard newValue.values.count == Self.channels.count else { return }
            for (i, k) in Self.channels.enumerated() { self[keyPath: k] = newValue.values[i] }
        }
    }
}

// MARK: - Small maths shared by the pet code

public extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(Swift.max(self, lo), hi) }
}

/// Deterministic noise and easing. Everything the pet does is a pure function of time, so the
/// same pet on two devices, or in a test, does the same thing at the same moment.
public enum PetMath {
    /// A stable pseudo-random number in 0..<1 for any input.
    public static func hash01(_ x: Double) -> Double {
        let s = sin(x * 127.1 + 311.7) * 43758.5453123
        return s - floor(s)
    }

    /// Smooth value noise in −1…1, one "feature" per unit of `x`.
    public static func noise(_ x: Double, seed: Double = 0) -> Double {
        let i = floor(x), f = x - i
        let a = hash01(i + seed * 57.3), b = hash01(i + 1 + seed * 57.3)
        let u = f * f * (3 - 2 * f)
        return (a + (b - a) * u) * 2 - 1
    }

    public static func smoothstep(_ t: Double) -> Double {
        let x = t.clamped(0, 1)
        return x * x * (3 - 2 * x)
    }

    /// Ease in-out that lingers at both ends (slow in, slow out).
    public static func easeInOut(_ t: Double) -> Double {
        let x = t.clamped(0, 1)
        return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    public static func easeOut(_ t: Double) -> Double {
        let x = t.clamped(0, 1)
        return 1 - pow(1 - x, 3)
    }

    public static func easeIn(_ t: Double) -> Double {
        let x = t.clamped(0, 1)
        return x * x * x
    }

    /// Overshoots and settles — for ears, tails and landings, never for the body itself.
    public static func easeOutBack(_ t: Double, overshoot: Double = 1.4) -> Double {
        let x = t.clamped(0, 1)
        let c3 = overshoot + 1
        return 1 + c3 * pow(x - 1, 3) + overshoot * pow(x - 1, 2)
    }

    /// 0 → 1 → 0 over `t` in 0…1, eased at both ends.
    public static func bump(_ t: Double) -> Double {
        guard t > 0, t < 1 else { return 0 }
        return sin(t * .pi) * sin(t * .pi)
    }
}
