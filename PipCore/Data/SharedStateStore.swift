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

    public init(identity: PetIdentity, mood: Mood? = nil, intensity: MoodIntensity? = nil, loggedAt: Date? = nil, today: [MoodStamp] = [], updatedAt: Date = .now) {
        self.identity = identity
        self.mood = mood
        self.intensity = intensity
        self.loggedAt = loggedAt
        self.today = today
        self.updatedAt = updatedAt
    }

    public static let placeholder = PetSnapshot(identity: .placeholder, mood: .calm, intensity: .moderate, loggedAt: .now)

    /// The resolved pet state. Falls back to a resting pose when nothing has been logged.
    public var state: PetMoodState {
        if let mood { return PetStateResolver.resolve(mood: mood, intensity: intensity ?? .moderate, identity: identity) }
        return PetStateResolver.resting(identity: identity)
    }

    /// Moods older than this are treated as "faded": the pet drifts back toward resting.
    public static let freshness: TimeInterval = 8 * 60 * 60

    /// State adjusted for the passage of time. A fresh mood is the mood; once it has faded the
    /// pet gets on with its own day (`PetLife`): asleep at night, at work, reading, lounging.
    public func state(at date: Date = .now, calendar: Calendar = .current) -> PetMoodState {
        guard let mood, let loggedAt, date.timeIntervalSince(loggedAt) <= Self.freshness else {
            return PetLife.activity(at: date, calendar: calendar).state(identity: identity)
        }
        return PetStateResolver.resolve(mood: mood, intensity: intensity ?? .moderate, identity: identity)
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
