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

        public init(kind: Kind, mood: Mood, intensity: MoodIntensity, message: String, endsAt: Date) {
            self.kind = kind
            self.mood = mood
            self.intensity = intensity
            self.message = message
            self.endsAt = endsAt
        }
    }

    public var identity: PetIdentity

    public init(identity: PetIdentity) {
        self.identity = identity
    }
}
