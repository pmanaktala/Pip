import ActivityKit
import Foundation

/// "Keeping you company": after you log a mood, the pet stays on your Lock Screen, in the
/// Dynamic Island and in the watch Smart Stack for a while, in its company stance for that
/// mood (Bible §7). It is not a timer: nothing counts, nothing ticks. It changes when you pet it,
/// dozes off on its own once it has been there a while (the stale view), and ends by itself.
public struct PetCompanyAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var mood: Mood
        public var intensity: MoodIntensity
        public var line: String
        /// Which of the stance's still poses to show; the system animates a change between them.
        public var hold: Int
        /// True for a moment after you pet it from the Lock Screen.
        public var petted: Bool
        public var startedAt: Date

        public init(mood: Mood, intensity: MoodIntensity, line: String, hold: Int = 0, petted: Bool = false, startedAt: Date = .now) {
            self.mood = mood
            self.intensity = intensity
            self.line = line
            self.hold = hold
            self.petted = petted
            self.startedAt = startedAt
        }

        public var stance: PetStance { .mood(mood, intensity) }
    }

    public var identity: PetIdentity

    public init(identity: PetIdentity) {
        self.identity = identity
    }
}

/// The words, in the pet's voice. Descriptive, never advice (Principles › Care).
public enum PetCompanyWords {
    public static func line(for mood: Mood, name n: String, seed: Int) -> String {
        let options: [String] = switch mood {
        case .happy: ["\(n) is happy for you.", "\(n) is humming your tune."]
        case .excited: ["\(n) can’t sit still either.", "\(n) is bouncing with you."]
        case .calm: ["\(n) made two cocoas.", "\(n) is sipping quietly beside you."]
        case .neutral: ["\(n) is right here.", "\(n) is keeping you company."]
        case .tired: ["\(n) brought the blanket.", "\(n) is tucked in with you."]
        case .stressed: ["\(n) is breathing slowly. Join in?", "\(n) is taking slow breaths with you."]
        case .sad: ["\(n) is sitting close.", "\(n) saved you a spot."]
        case .frustrated: ["\(n) is huffing along with you.", "\(n) gets it."]
        }
        return options[abs(seed) % options.count]
    }

    public static func petted(_ n: String) -> String { "\(n) leans into your hand." }
    public static func dozed(_ n: String) -> String { "\(n) dozed off beside you." }

    /// How long the pet stays: longer for the harder feelings.
    public static func duration(for mood: Mood) -> TimeInterval {
        switch mood {
        case .sad, .stressed, .tired, .frustrated: 60 * 60
        default: 20 * 60
        }
    }
}
