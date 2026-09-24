import Foundation
import WidgetKit

/// A tiny mood stamp used for "today's progression" in widgets and recaps.
public struct MoodStamp: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var mood: Mood
    public var intensity: MoodIntensity
    public var time: Date

    public init(id: UUID = UUID(), mood: Mood, intensity: MoodIntensity, time: Date) {
        self.id = id
        self.mood = mood
        self.intensity = intensity
        self.time = time
    }
}

/// Lightweight current-state representation shared with widgets and Live Activities.
///
/// Extensions render from this and never open the SwiftData store for display.
public struct PetSnapshot: Codable, Equatable, Sendable {
    public var identity: PetIdentity
    public var mood: Mood?
    public var intensity: MoodIntensity?
    public var loggedAt: Date?
    public var today: [MoodStamp]
    public var updatedAt: Date
    /// When you met your pet: its birthday comes round once a year.
    public var adoptedAt: Date?
    /// Yesterday was a rough day (see `PetSnapshot.wasRough`); today it greets you gently until
    /// you log something.
    public var roughYesterday: Bool?

    public init(identity: PetIdentity, mood: Mood? = nil, intensity: MoodIntensity? = nil, loggedAt: Date? = nil, today: [MoodStamp] = [], updatedAt: Date = .now,
                adoptedAt: Date? = nil, roughYesterday: Bool? = nil) {
        self.adoptedAt = adoptedAt
        self.roughYesterday = roughYesterday
        self.identity = identity
        self.mood = mood
        self.intensity = intensity
        self.loggedAt = loggedAt
        self.today = today
        self.updatedAt = updatedAt
    }

    public static let placeholder = PetSnapshot(identity: .placeholder, mood: .calm, intensity: .moderate, loggedAt: .now)

    /// Moods older than this are treated as "faded": the pet gets on with its own day.
    public static let freshness: TimeInterval = 8 * 60 * 60

    /// A day was rough if it ended on a hard feeling, or at least half of it was hard.
    public static func wasRough(_ moods: [Mood]) -> Bool {
        let hard: Set<Mood> = [.sad, .stressed, .tired, .frustrated]
        guard let last = moods.last else { return false }
        return hard.contains(last) || moods.filter(hard.contains).count * 2 >= moods.count
    }

    /// Greet gently: yesterday was rough and nothing is logged yet today.
    public var greetsGently: Bool { roughYesterday == true && today.isEmpty }

    /// The fresh mood at `date`, if there is one.
    public func freshMood(at date: Date = .now) -> Mood? {
        guard let mood, let loggedAt, date.timeIntervalSince(loggedAt) <= Self.freshness else { return nil }
        return mood
    }
}

/// App Group backed store for the snapshot and small cross-process flags.
/// `UserDefaults` is thread-safe; the conformance is unchecked only because the type is not annotated.
public struct SharedStateStore: @unchecked Sendable {
    public static let shared = SharedStateStore()

    private let defaults: UserDefaults
    private let snapshotKey = "petSnapshot.v1"

    public init(suiteName: String = PipModelContainer.appGroupID) {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    public var snapshot: PetSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(PetSnapshot.self, from: data)
    }

    /// Persists the snapshot and asks WidgetKit to refresh.
    public func save(_ snapshot: PetSnapshot, reloadWidgets: Bool = true) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
        if reloadWidgets { WidgetCenter.shared.reloadAllTimelines() }
    }

    public func clear() {
        defaults.removeObject(forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Small flags readable by every process

    public var defaultsSuite: UserDefaults { defaults }
}
