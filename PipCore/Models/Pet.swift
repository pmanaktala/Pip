import CoreGraphics
import Foundation

/// The companions. Three distinct silhouettes, each finished to the same standard
/// (see `Docs/Pets/Bible.md` §2). Earlier builds also offered a capybara and a red panda; those
/// choices decode as the penguin.
public enum PetSpecies: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case penguin, cat, dog

    public var id: String { rawValue }

    /// Tolerates retired species so old profiles, snapshots and watch messages still decode.
    public init?(rawValue: String) {
        switch rawValue {
        case "penguin", "capybara", "redPanda": self = .penguin
        case "cat": self = .cat
        case "dog": self = .dog
        default: return nil
        }
    }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PetSpecies(rawValue: raw) ?? .penguin
    }

    public var displayName: String {
        switch self {
        case .cat: "Cat"
        case .dog: "Dog"
        case .penguin: "Penguin"
        }
    }

    public var defaultName: String {
        switch self {
        case .cat: "Mochi"
        case .dog: "Biscuit"
        case .penguin: "Pebble"
        }
    }

    public var defaultPersonality: PetPersonality {
        switch self {
        case .cat: .independent
        case .dog: .wholehearted
        case .penguin: .earnest
        }
    }

    /// One-line personality blurb shown in the pet selector.
    public var blurb: String {
        switch self {
        case .penguin: "Earnest and a little clumsy. Flaps when it’s happy for you."
        case .cat: "Independent, secretly devoted. Slow-blinks when you’re around."
        case .dog: "Wholehearted. The whole back end wags when you show up."
        }
    }
}

/// Subtle behavioural flavour. Same mood, slightly different reaction.
public enum PetPersonality: String, Codable, CaseIterable, Sendable, Hashable {
    case earnest, independent, wholehearted

    /// Maps personalities from earlier builds onto the current three.
    public init?(rawValue: String) {
        switch rawValue {
        case "earnest", "chaotic", "serene": self = .earnest
        case "independent", "dramatic", "sleepy": self = .independent
        case "wholehearted", "optimistic": self = .wholehearted
        default: return nil
        }
    }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = PetPersonality(rawValue: raw) ?? .earnest
    }

    public var displayName: String { rawValue.capitalized }
}

/// Everything needed to identify and render a specific pet.
public struct PetIdentity: Codable, Hashable, Sendable {
    public var species: PetSpecies
    public var name: String
    public var personality: PetPersonality

    public init(species: PetSpecies, name: String? = nil, personality: PetPersonality? = nil) {
        self.species = species
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.name = trimmed.isEmpty ? species.defaultName : trimmed
        self.personality = personality ?? species.defaultPersonality
    }

    public static let placeholder = PetIdentity(species: .penguin)
}
