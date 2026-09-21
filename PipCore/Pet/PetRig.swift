import Foundation
import SwiftUI

/// A flat, fully numeric description of how the pet is posed and what its face is doing.
///
/// Every field is a `Double` so the whole rig can be interpolated by SwiftUI: a mood
/// change becomes ears lowering and a mouth curving, not a crossfade between two pictures.
/// Species painters read the rig; they never decide what a mood looks like.
public struct PetRig: Equatable, Sendable {
    // MARK: Body
    /// Vertical squash. 1 = neutral, < 1 flatter/wider (tired, sad), > 1 taller (alert).
    public var squash: Double = 1
    /// Body tilt in degrees. Positive tilts to the pet's right.
    public var tilt: Double = 0
    /// 0 = sitting up, 1 = curled up / lying down.
    public var lying: Double = 0
    /// Vertical offset in canvas units (200pt canvas). Negative lifts the pet.
    public var lift: Double = 0
    /// Whole-body lean in degrees about the feet. Positive leans to the pet's right.
    public var lean: Double = 0
    /// -1…1 head turn; shifts the face toward one side of the head.
    public var headTurn: Double = 0
    /// 0 = head held up, 1 = head sunk into the shoulders (tired, sad, stressed).
    public var headDrop: Double = 0
    /// 0 = arms/flippers/paws resting, 1 = raised.
    public var armRaise: Double = 0
    /// 0 = arms at the sides, 1 = folded across the chest (frustrated) or hugging (stressed).
    public var armCross: Double = 0
    /// 0 = arms at the sides, 1 = spread wide and open (happy, "ta-da").
    public var armOut: Double = 0

    // MARK: Ears & tail
    /// 0 = flat back / drooping, 1 = perked up.
    public var earLift: Double = 0.8
    /// 0 = tucked, 1 = raised high.
    public var tailLift: Double = 0.5

    // MARK: Eyes
    /// 0 = closed, 1 = open.
    public var eyeOpen: Double = 1
    /// 0 = round eye, 1 = happy upward arc (^ ^).
    public var eyeArc: Double = 0
    /// 0 = relaxed, 1 = narrowed / squinting (annoyed, sleepy).
    public var eyeSquint: Double = 0
    /// Scale of the eye; > 1 for wide-eyed excitement.
    public var eyeScale: Double = 1
    /// Scale of the pupil highlight; larger = more sparkle.
    public var pupilScale: Double = 1
    /// Where the pupils look, in fractions of the eye radius.
    public var gazeX: Double = 0
    public var gazeY: Double = 0

    // MARK: Brows
    /// -1 = inner ends down (angry), 0 = neutral, 1 = inner ends up (worried/sad).
    public var browInnerUp: Double = 0
    /// 0 = hidden, 1 = fully drawn. Neutral pets have no visible brows.
    public var browWeight: Double = 0

    // MARK: Mouth
    /// -1 = frown, 0 = flat, 1 = smile.
    public var mouthCurve: Double = 0.35
    /// 0 = closed, 1 = fully open.
    public var mouthOpen: Double = 0
    /// Relative width, 1 = default.
    public var mouthWidth: Double = 1
    /// 0 = smooth, 1 = wobbly (stressed / about to cry).
    public var mouthWobble: Double = 0
    /// 0 = none, 1 = tongue out (dogs mostly).
    public var tongue: Double = 0

    // MARK: Face details
    public var blush: Double = 0.2
    public var sweat: Double = 0
    /// 0 = none, 1 = eyelids heavy (tired).
    public var lidHeaviness: Double = 0

    public init() {}

    /// Linear interpolation between two rigs; used for previews and manual blending.
    public static func lerp(_ a: PetRig, _ b: PetRig, _ t: Double) -> PetRig {
        var out = PetRig()
        out.vector = a.vector.mixed(with: b.vector, t)
        return out
    }
}

// MARK: - VectorArithmetic bridge

extension PetRig {
    /// Fixed-size vector backing `Animatable` conformance for views that render a rig.
    public struct Vector: VectorArithmetic, Sendable {
        public var values: [Double]

        public init(values: [Double]) { self.values = values }

        public static var zero: Vector { Vector(values: Array(repeating: 0, count: PetRig.fieldCount)) }

        public static func + (lhs: Vector, rhs: Vector) -> Vector {
            Vector(values: zip(lhs.values, rhs.values).map(+))
        }

        public static func - (lhs: Vector, rhs: Vector) -> Vector {
            Vector(values: zip(lhs.values, rhs.values).map(-))
        }

        public static func += (lhs: inout Vector, rhs: Vector) { lhs = lhs + rhs }
        public static func -= (lhs: inout Vector, rhs: Vector) { lhs = lhs - rhs }

        public mutating func scale(by rhs: Double) {
            values = values.map { $0 * rhs }
        }

        public var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }

        public func mixed(with other: Vector, _ t: Double) -> Vector {
            Vector(values: zip(values, other.values).map { $0 + ($1 - $0) * t })
        }
    }

    static let fieldCount = 29

    public var vector: Vector {
        get {
            Vector(values: [
                squash, tilt, lying, lift,
                earLift, tailLift,
                eyeOpen, eyeArc, eyeSquint, eyeScale, pupilScale, gazeX, gazeY,
                browInnerUp, browWeight,
                mouthCurve, mouthOpen, mouthWidth, mouthWobble, tongue,
                blush, sweat, lidHeaviness,
                lean, headTurn, headDrop, armRaise,
                armCross, armOut,
            ])
        }
        set {
            let v = newValue.values
            guard v.count == Self.fieldCount else { return }
            squash = v[0]; tilt = v[1]; lying = v[2]; lift = v[3]
            earLift = v[4]; tailLift = v[5]
            eyeOpen = v[6]; eyeArc = v[7]; eyeSquint = v[8]; eyeScale = v[9]; pupilScale = v[10]; gazeX = v[11]; gazeY = v[12]
            browInnerUp = v[13]; browWeight = v[14]
            mouthCurve = v[15]; mouthOpen = v[16]; mouthWidth = v[17]; mouthWobble = v[18]; tongue = v[19]
            blush = v[20]; sweat = v[21]; lidHeaviness = v[22]
            lean = v[23]; headTurn = v[24]; headDrop = v[25]; armRaise = v[26]
            armCross = v[27]; armOut = v[28]
        }
    }
}

/// Idle-motion parameters. These are *rates and amplitudes* for scheduled gestures,
/// applied on top of the rig by `PetAnimator`; they are not interpolated field-by-field.
public struct PetMotionProfile: Equatable, Sendable {
    /// Breaths per second.
    public var breathRate: Double = 0.26
    /// Breathing scale amplitude (0.03 = 3%).
    public var breathAmount: Double = 0.03
    /// Hop height in canvas units (0 = never hops).
    public var hopHeight: Double = 0
    /// Average seconds between hops.
    public var hopInterval: Double = 3
    /// Tail wags per second (0 = still).
    public var tailWagRate: Double = 0
    /// Tail wag amplitude 0…1.
    public var tailWagAmount: Double = 0
    /// Shiver amplitude in canvas units (stress). Shivers come in short bursts.
    public var shiver: Double = 0
    /// Slow weight-shift lean amplitude in degrees.
    public var swayAmount: Double = 2
    /// Seconds per weight shift.
    public var swayPeriod: Double = 7
    /// Average seconds between blinks. `.infinity` disables blinking (eyes closed).
    public var blinkInterval: Double = 4.2
    /// Average seconds between gaze changes.
    public var gazeInterval: Double = 3.5
    /// Occasional ear twitch probability weight.
    public var earTwitch: Double = 0.3
    /// Slow nodding-off head bob amplitude (tired).
    public var nod: Double = 0
    /// Occasional deep sigh amplitude (sad, calm).
    public var sigh: Double = 0
    /// The mood's signature bit of theatre, performed now and then (see `PetBit`).
    public var bit: PetBit = .none
    /// Average seconds between bits.
    public var bitInterval: Double = 10
    /// Other bits the pet may pick instead, one per cycle, so a mood has more than one trick.
    public var alternateBits: [PetBit] = []

    public init() {}
}

/// A signature piece of business the pet performs every so often: bigger and more theatrical
/// than idle motion, so the mood has a personality and not just a face. Each bit is a pure,
/// eased function of time in `PetAnimator`; `meditate` runs continuously.
public enum PetBit: String, Codable, Sendable, Hashable {
    case none
    /// Happy: a little dance, leaning side to side with the arms swinging.
    case wiggle
    /// Excited: two big hops with a full-body twist.
    case zoomies
    /// Calm: a long slow stretch, eyes closed, then settle.
    case stretch
    /// Neutral: a curious head tilt with an ear flick.
    case curious
    /// Tired: nod off, keel over, jerk awake.
    case flop
    /// Stressed: a darting look left and right, sweat.
    case fidget
    /// Frustrated: two stomps and a huff.
    case stomp
    /// Sad: a sniffle and a slow shake of the head under the umbrella.
    case sniffle
    /// Sitting together: float a little, eyes closed, breathing slow and deep.
    case meditate
    /// Happy, the other one: arms flung wide, a hop, a big grin. Ta-da.
    case tada
    /// Working: a burst of typing, then a lean back and a look at the ceiling.
    case typing
    /// Reading: a page turned with a flick, a glance up, back to the book.
    case pageTurn
    /// Asleep: a snore that swells the chest, a twitch, a smack of the lips.
    case snore

    /// How long one performance lasts, in seconds (`meditate` is continuous).
    public var duration: Double {
        switch self {
        case .none: 0
        case .wiggle: 1.8
        case .zoomies: 1.3
        case .stretch: 3.4
        case .curious: 2.2
        case .flop: 5.0
        case .fidget: 1.4
        case .stomp: 2.2
        case .sniffle: 3.0
        case .meditate: .infinity
        case .tada: 1.6
        case .typing: 2.6
        case .pageTurn: 1.2
        case .snore: 2.4
        }
    }

    /// The deterministic seed each bit schedules itself with.
    var seed: Double {
        switch self {
        case .none: 0
        case .wiggle: 71
        case .zoomies: 73
        case .stretch: 79
        case .curious: 83
        case .flop: 89
        case .fidget: 97
        case .stomp: 101
        case .sniffle: 103
        case .meditate: 0
        case .tada: 107
        case .typing: 109
        case .pageTurn: 113
        case .snore: 127
        }
    }
}

/// Small, optional visual additions around the pet. Rendered by the scene, not the painter.
public enum PetAccessory: String, Codable, Sendable, Hashable {
    case sparkles, zzz, stressLines, heart, rainCloud, steam
    /// A rain cloud *and* the umbrella the pet holds up under it.
    case umbrella
    /// Asleep: a nightcap on the head, and zzz.
    case nightcap
    /// At work: a small open laptop on the floor, its screen lighting the face.
    case laptop
    /// Reading: an open book held at the chest.
    case book
}

/// Ambient scene changes driven by mood.
public struct PetEnvironment: Equatable, Sendable {
    /// 0…1 strength of the ambient mood tint behind the pet.
    public var tintStrength: Double = 0.4
    /// 0…1 how dim the scene is (night / tired).
    public var dimness: Double = 0
    /// Floor shadow softness multiplier.
    public var shadowSpread: Double = 1

    public init() {}
}

/// The complete resolved state for a pet at a moment in time.
public struct PetMoodState: Equatable, Sendable {
    public var mood: Mood
    public var intensity: MoodIntensity
    public var rig: PetRig
    public var motion: PetMotionProfile
    public var accessory: PetAccessory?
    public var environment: PetEnvironment

    public init(mood: Mood, intensity: MoodIntensity, rig: PetRig, motion: PetMotionProfile, accessory: PetAccessory?, environment: PetEnvironment) {
        self.mood = mood
        self.intensity = intensity
        self.rig = rig
        self.motion = motion
        self.accessory = accessory
        self.environment = environment
    }
}
