import CoreGraphics
import Foundation

/// The pets available in v1. Kept deliberately small.
public enum PetSpecies: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    case cat, dog, capybara, penguin, redPanda

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cat: "Cat"
        case .dog: "Dog"
        case .capybara: "Capybara"
        case .penguin: "Penguin"
        case .redPanda: "Red Panda"
        }
    }

    public var defaultName: String {
        switch self {
        case .cat: "Mochi"
        case .dog: "Biscuit"
        case .capybara: "Juniper"
        case .penguin: "Pebble"
        case .redPanda: "Rusty"
        }
    }

    public var defaultPersonality: PetPersonality {
        switch self {
        case .cat: .dramatic
        case .dog: .optimistic
        case .capybara: .serene
        case .penguin: .chaotic
        case .redPanda: .sleepy
        }
    }

    /// Base body proportions in the 200×200 design space.
    public var bodySize: CGSize {
        switch self {
        case .cat: CGSize(width: 118, height: 106)
        case .dog: CGSize(width: 116, height: 108)
        case .capybara: CGSize(width: 134, height: 96)
        case .penguin: CGSize(width: 104, height: 118)
        case .redPanda: CGSize(width: 116, height: 104)
        }
    }

    /// One-line personality blurb shown in the pet selector.
    public var blurb: String {
        switch self {
        case .cat: "A little dramatic. Feels everything at full volume."
        case .dog: "Relentlessly optimistic. Even bad days have a tail wag."
        case .capybara: "Deeply unbothered. Sits with you through anything."
        case .penguin: "Chaotic and enthusiastic. Waddles into every feeling."
        case .redPanda: "Sleepy and soft. Most moods are a reason for a nap."
        }
    }
}

/// Subtle behavioural flavour. Same mood, slightly different reaction.
public enum PetPersonality: String, Codable, CaseIterable, Sendable, Hashable {
    case dramatic, optimistic, serene, chaotic, sleepy

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

    public static let placeholder = PetIdentity(species: .cat)
}
