import ActivityKit
import Foundation

/// A temporary "pet moment" shown as a Live Activity. Widgets are where the pet lives;
/// this is when it has a moment.
public struct PetMomentAttributes: ActivityAttributes {
    public enum Kind: String, Codable, Sendable, Hashable {
        /// Right after logging: the pet reacting.
        case moodChange
        /// A particularly positive mood: a small celebration.
        case celebration
        /// After a stressed or sad mood: the pet just sits with you.
        case breather
        /// "Mochi wants some company."
        case company
        /// Evening: getting sleepy.
        case windDown
        /// A random small delight.
        case random

        /// How long the moment stays on the Lock Screen.
        public var duration: TimeInterval {
            switch self {
            case .moodChange: 12 * 60
            case .celebration: 15 * 60
            case .breather: 25 * 60
            case .company: 30 * 60
            case .windDown: 30 * 60
            case .random: 15 * 60
            }
        }
    }

    public struct ContentState: Codable, Hashable, Sendable {
        public var kind: Kind
        public var mood: Mood
        public var intensity: MoodIntensity
        public var message: String
        public var endsAt: Date
        /// When the moment began; drives the live "with you for…" timer.
        public var startedAt: Date
        /// Small pose variation (see `PetPose`). Live Activities can't animate continuously,
        /// so the app pushes a new pose now and then and the system animates the change.
        public var pose: Int

        public init(kind: Kind, mood: Mood, intensity: MoodIntensity, message: String, endsAt: Date, startedAt: Date = .now, pose: Int = 0) {
            self.kind = kind
            self.mood = mood
            self.intensity = intensity
            self.message = message
            self.endsAt = endsAt
            self.startedAt = startedAt
            self.pose = pose
        }

        /// The moment's resolved pet state with the pose variation applied.
        public func petState(identity: PetIdentity) -> PetMoodState {
            PetPose.apply(pose, to: PetStateResolver.resolve(mood: mood, intensity: intensity, identity: identity))
        }
    }

    public var identity: PetIdentity

    public init(identity: PetIdentity) {
        self.identity = identity
    }
}


/// Static pose variations for surfaces that cannot animate (Live Activities, widgets).
/// Each is a small, believable moment: a blink, a glance, a wave, a hop.
public enum PetPose {
    public static let count = 6
    public static let wave = 4

    public static func apply(_ pose: Int, to state: PetMoodState) -> PetMoodState {
        var s = state
        switch pose % count {
        case 1: // blink
            s.rig.eyeOpen = 0
        case 2: // glance left
            s.rig.gazeX = -0.7; s.rig.headTurn = -0.6; s.rig.tilt += 2
        case 3: // glance right
            s.rig.gazeX = 0.7; s.rig.headTurn = 0.6; s.rig.tilt -= 2
        case 4: // wave
            s.rig.armRaise = 1; s.rig.tilt += 4; s.rig.mouthCurve = max(s.rig.mouthCurve, 0.6); s.rig.eyeArc = max(s.rig.eyeArc, 0.3)
        case 5: // little hop
            s.rig.lift -= 8; s.rig.squash = min(1.08, s.rig.squash + 0.05); s.rig.armRaise = max(s.rig.armRaise, 0.5)
        default:
            break
        }
        return s
    }

    /// A different pose from `current`, chosen deterministically from `seed`.
    public static func next(after current: Int, seed: Double) -> Int {
        let candidates = (0..<count).filter { $0 != current && $0 != wave }
        return candidates[Int(PetAnimator.hash01(seed) * Double(candidates.count)) % candidates.count]
    }
}
