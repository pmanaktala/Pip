import Foundation

/// The moods a user can log. Order is the order shown in the picker.
public enum Mood: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case happy, excited, calm, neutral, tired, stressed, sad, frustrated

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .happy: "Happy"
        case .excited: "Excited"
        case .calm: "Calm"
        case .neutral: "Neutral"
        case .tired: "Tired"
        case .stressed: "Stressed"
        case .sad: "Sad"
        case .frustrated: "Frustrated"
        }
    }

    /// Pleasantness from -1 (unpleasant) to +1 (pleasant). Mirrors HealthKit's valence axis.
    public var valence: Double {
        switch self {
        case .happy: 0.7
        case .excited: 0.8
        case .calm: 0.5
        case .neutral: 0.0
        case .tired: -0.2
        case .stressed: -0.6
        case .sad: -0.7
        case .frustrated: -0.6
        }
    }

    /// Energy from 0 (still) to 1 (bouncing off the walls). Drives animation amplitude.
    public var energy: Double {
        switch self {
        case .happy: 0.65
        case .excited: 1.0
        case .calm: 0.25
        case .neutral: 0.4
        case .tired: 0.08
        case .stressed: 0.8
        case .sad: 0.15
        case .frustrated: 0.7
        }
    }

    /// SF Symbol used where a tiny glyph is needed (inline Lock Screen widget, accessibility).
    public var symbolName: String {
        switch self {
        case .happy: "sun.max"
        case .excited: "sparkles"
        case .calm: "leaf"
        case .neutral: "minus"
        case .tired: "moon.zzz"
        case .stressed: "bolt"
        case .sad: "cloud.rain"
        case .frustrated: "flame"
        }
    }

    /// How the pet "looks" — used for VoiceOver so mood is never colour-only.
    public var petDescription: String {
        switch self {
        case .happy: "looks happy"
        case .excited: "is bouncing with excitement"
        case .calm: "looks calm and relaxed"
        case .neutral: "looks content"
        case .tired: "looks sleepy"
        case .stressed: "looks a little frazzled"
        case .sad: "looks a bit down"
        case .frustrated: "looks frustrated"
        }
    }
}

/// How strongly the mood is felt. Changes the pet's behaviour, never shown as a number.
public enum MoodIntensity: Int, Codable, CaseIterable, Sendable, Identifiable, Hashable, Comparable {
    case slight = 1
    case moderate = 2
    case strong = 3

    public var id: Int { rawValue }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Adverb prefix used in copy: "slightly stressed", "stressed", "very stressed".
    public var adverb: String? {
        switch self {
        case .slight: "slightly"
        case .moderate: nil
        case .strong: "very"
        }
    }

    /// 0.5 … 1.0 … 1.5 multiplier for expression strength and animation amplitude.
    public var scale: Double {
        switch self {
        case .slight: 0.55
        case .moderate: 1.0
        case .strong: 1.4
        }
    }

    public func phrase(for mood: Mood) -> String {
        if let adverb { return "\(adverb) \(mood.displayName.lowercased())" }
        return mood.displayName.lowercased()
    }
}

/// Optional "why" — never required.
public enum MoodContext: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case work, friends, family, health, money, social, relationship, school, travel, random

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .work: "Work"
        case .friends: "Friends"
        case .family: "Family"
        case .health: "Health"
        case .money: "Money"
        case .social: "Social"
        case .relationship: "Relationship"
        case .school: "School"
        case .travel: "Travel"
        case .random: "Random"
        }
    }

    public var symbolName: String {
        switch self {
        case .work: "briefcase"
        case .friends: "person.2"
        case .family: "house"
        case .health: "heart"
        case .money: "creditcard"
        case .social: "bubble.left.and.bubble.right"
        case .relationship: "heart.circle"
        case .school: "book"
        case .travel: "airplane"
        case .random: "dice"
        }
    }
}
