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

    /// State adjusted for the passage of time: an old mood softens rather than persisting forever.
    public func state(at date: Date = .now, calendar: Calendar = .current) -> PetMoodState {
        let hour = calendar.component(.hour, from: date)
        let isNight = hour >= 23 || hour < 6
        guard let mood, let loggedAt else {
            return isNight ? PetStateResolver.resolve(mood: .tired, intensity: .slight, identity: identity)
                           : PetStateResolver.resting(identity: identity)
        }
        let age = date.timeIntervalSince(loggedAt)
        if age > Self.freshness {
            // The feeling has faded; late at night the pet is simply asleep.
            if isNight { return PetStateResolver.resolve(mood: .tired, intensity: .moderate, identity: identity) }
            return PetStateResolver.resolve(mood: mood, intensity: .slight, identity: identity)
        }
        return PetStateResolver.resolve(mood: mood, intensity: intensity ?? .moderate, identity: identity)
    }
}

/// App Group backed store for the snapshot and small cross-process flags.
public struct SharedStateStore: Sendable {
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
