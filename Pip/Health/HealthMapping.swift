import Foundation
import HealthKit

/// Pure mapping from Pip's mood model to HealthKit State of Mind. Unit-tested.
enum HealthMapping {

    static func label(for mood: Mood) -> HKStateOfMind.Label {
        switch mood {
        case .happy: .happy
        case .excited: .excited
        case .calm: .calm
        case .neutral: .indifferent
        case .tired: .drained
        case .stressed: .stressed
        case .sad: .sad
        case .frustrated: .frustrated
        }
    }

    static func association(for context: MoodContext) -> HKStateOfMind.Association? {
        switch context {
        case .work: .work
        case .friends: .friends
        case .family: .family
        case .health: .health
        case .money: .money
        case .social: .community
        case .relationship: .partner
        case .school: .education
        case .travel: .travel
        case .random: nil
        }
    }

    /// Valence in -1…1. Intensity pushes the value further from neutral.
    static func valence(for mood: Mood, intensity: MoodIntensity) -> Double {
        let factor: Double = switch intensity {
        case .slight: 0.6
        case .moderate: 1.0
        case .strong: 1.3
        }
        return (mood.valence * factor).clamped(-1, 1)
    }

    static func sample(for entry: MoodEntry) -> HKStateOfMind {
        HKStateOfMind(
            date: entry.timestamp,
            kind: .momentaryEmotion,
            valence: valence(for: entry.mood, intensity: entry.intensity),
            labels: [label(for: entry.mood)],
            associations: entry.contexts.compactMap(association(for:)),
            metadata: [HKMetadataKeyExternalUUID: entry.id.uuidString])
    }
}
