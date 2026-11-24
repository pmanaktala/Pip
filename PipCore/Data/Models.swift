import Foundation
import SwiftData

/// One logged mood. Lives locally in SwiftData and mirrors to the user's private CloudKit database.
///
/// CloudKit rules: every attribute has a default or is optional, no `@Attribute(.unique)`.
/// `id` is a stable UUID used for de-duplication across devices and reinstalls.
@Model
public final class MoodEntry {
    public var id: UUID = UUID()
    public var timestamp: Date = Date.now
    public var moodRaw: String = Mood.neutral.rawValue
    public var intensityRaw: Int = MoodIntensity.moderate.rawValue
    /// Comma-separated `MoodContext` raw values. Kept flat for CloudKit friendliness.
    public var contextsRaw: String = ""
    public var note: String?
    /// `HKObject.uuid` of the State of Mind sample written for this entry, if any.
    public var healthKitSampleID: String?
    /// When the Health sample was last written; if `modifiedAt` is later, the sample is stale.
    public var healthKitSyncedAt: Date?
    public var createdAt: Date = Date.now
    public var modifiedAt: Date = Date.now

    public init(mood: Mood, intensity: MoodIntensity = .moderate, contexts: [MoodContext] = [], note: String? = nil, timestamp: Date = .now) {
        self.id = UUID()
        self.timestamp = timestamp
        self.moodRaw = mood.rawValue
        self.intensityRaw = intensity.rawValue
        self.contextsRaw = contexts.map(\.rawValue).joined(separator: ",")
        self.note = note
        self.createdAt = .now
        self.modifiedAt = .now
    }

    public var mood: Mood {
        get { Mood(rawValue: moodRaw) ?? .neutral }
        set { moodRaw = newValue.rawValue }
    }

    public var intensity: MoodIntensity {
        get { MoodIntensity(rawValue: intensityRaw) ?? .moderate }
        set { intensityRaw = newValue.rawValue }
    }

    public var contexts: [MoodContext] {
        get { contextsRaw.split(separator: ",").compactMap { MoodContext(rawValue: String($0)) } }
        set { contextsRaw = newValue.map(\.rawValue).joined(separator: ",") }
    }

    /// True when the entry has been written to Health and not modified since.
    public var isHealthSyncCurrent: Bool {
        guard healthKitSampleID != nil, let synced = healthKitSyncedAt else { return false }
        return synced >= modifiedAt
    }

    public func touch() { modifiedAt = .now }
}

/// Leaves a deletion marker across restarts and iCloud sync, without retaining mood content.
@Model
final class MoodDeletion {
    var entryID: UUID = UUID()

    init(entryID: UUID) { self.entryID = entryID }

    static func contains(_ id: UUID, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<MoodDeletion>(predicate: #Predicate { $0.entryID == id })
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    /// Deletion always wins for a UUID. Logging a new mood generates a fresh UUID.
    static func record(_ id: UUID, in context: ModelContext) throws -> Bool {
        let entries = try context.fetch(FetchDescriptor<MoodEntry>(predicate: #Predicate { $0.id == id }))
        let isNew = try !contains(id, in: context)
        if isNew { context.insert(MoodDeletion(entryID: id)) }
        for entry in entries { context.delete(entry) }
        return isNew || !entries.isEmpty
    }
}

/// The user's pet. There should be exactly one; duplicates from multi-device setup are
/// reconciled by keeping the most recently modified profile.
@Model
public final class PetProfile {
    public var id: UUID = UUID()
    public var speciesRaw: String = PetSpecies.penguin.rawValue
    public var name: String = PetSpecies.penguin.defaultName
    public var personalityRaw: String = PetPersonality.earnest.rawValue
    /// Comma-separated accessory identifiers for future customisation.
    public var accessoriesRaw: String = ""
    public var createdAt: Date = Date.now
    public var modifiedAt: Date = Date.now

    public init(identity: PetIdentity) {
        self.id = UUID()
        self.speciesRaw = identity.species.rawValue
        self.name = identity.name
        self.personalityRaw = identity.personality.rawValue
        self.createdAt = .now
        self.modifiedAt = .now
    }

    public var species: PetSpecies {
        get { PetSpecies(rawValue: speciesRaw) ?? .penguin }
        set { speciesRaw = newValue.rawValue }
    }

    public var personality: PetPersonality {
        get { PetPersonality(rawValue: personalityRaw) ?? species.defaultPersonality }
        set { personalityRaw = newValue.rawValue }
    }

    public var identity: PetIdentity {
        get { PetIdentity(species: species, name: name, personality: personality) }
        set {
            species = newValue.species
            name = newValue.name
            personality = newValue.personality
            modifiedAt = .now
        }
    }
}
