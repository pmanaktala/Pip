import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Everything Pip knows, as one readable JSON file the user owns.
///
/// Data portability is part of the privacy promise: what lives on the device can leave with
/// the user at any time, in a format other tools can read. Health sample IDs are omitted; they
/// mean nothing outside this install.
public struct MoodExport: Codable, Sendable, Equatable {
    public struct Pet: Codable, Sendable, Equatable {
        public var name: String
        public var species: String
        public var personality: String
    }

    public struct Entry: Codable, Sendable, Equatable {
        public var id: UUID
        public var timestamp: Date
        public var mood: String
        public var intensity: String
        public var contexts: [String]
        public var note: String?
    }

    public var app = "Pip"
    public var format = 1
    public var exportedAt: Date
    public var pet: Pet?
    public var entries: [Entry]

    public init(exportedAt: Date = .now, pet: Pet?, entries: [Entry]) {
        self.exportedAt = exportedAt
        self.pet = pet
        self.entries = entries
    }

    @MainActor
    public init(context: ModelContext, now: Date = .now) {
        let profile = PipQueries.petProfile(in: context, createIfMissing: false)
        self.init(
            exportedAt: now,
            pet: profile.map { Pet(name: $0.name, species: $0.species.rawValue, personality: $0.personality.rawValue) },
            entries: PipQueries.allEntries(in: context)
                .sorted { $0.timestamp < $1.timestamp }
                .map { Entry(id: $0.id, timestamp: $0.timestamp, mood: $0.mood.rawValue, intensity: Self.intensityName($0.intensity), contexts: $0.contexts.map(\.rawValue), note: $0.note) })
    }

    static func intensityName(_ intensity: MoodIntensity) -> String {
        switch intensity {
        case .slight: "slight"
        case .moderate: "moderate"
        case .strong: "strong"
        }
    }

    public func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public var suggestedFileName: String {
        "Pip moods \(exportedAt.formatted(.iso8601.year().month().day())).json"
    }
}

extension MoodExport: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { try $0.data() }
            .suggestedFileName { $0.suggestedFileName }
    }
}
