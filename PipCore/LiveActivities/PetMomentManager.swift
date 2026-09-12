import ActivityKit
import Foundation
import OSLog

/// Starts and ends pet-moment Live Activities. Never more than one at a time.
///
/// A moment stays *active* for its duration so it lives in the Dynamic Island as well as on
/// the Lock Screen (an ended activity is dropped from the island at once). It is ended by
/// a timer while the app is running, by `endExpired()` whenever the app comes back, and by
/// the system's stale date otherwise.
@MainActor
public final class PetMomentManager {
    public static let shared = PetMomentManager()
    private let log = Logger(subsystem: "com.pmanaktala.Pip", category: "LiveActivity")
    private var expiry: Task<Void, Never>?

    public var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    public func start(kind: PetMomentAttributes.Kind, mood: Mood, intensity: MoodIntensity, message: String, identity: PetIdentity, now: Date = .now) {
        guard isAvailable else { return }
        endAll()
        let endsAt = now.addingTimeInterval(kind.duration)
        let state = PetMomentAttributes.ContentState(kind: kind, mood: mood, intensity: intensity, message: message, endsAt: endsAt)
        let content = ActivityContent(state: state, staleDate: endsAt, relevanceScore: kind == .celebration ? 100 : 50)
        do {
            let activity = try Activity.request(attributes: PetMomentAttributes(identity: identity), content: content, pushType: nil)
            log.info("Started pet moment \(kind.rawValue)")
            expiry = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(1, endsAt.timeIntervalSince(now))))
                guard !Task.isCancelled else { return }
                await activity.end(content, dismissalPolicy: .immediate)
                self?.log.info("Ended pet moment \(kind.rawValue) on schedule")
            }
        } catch {
            log.error("Could not start Live Activity: \(error.localizedDescription)")
        }
    }

    /// Ends any moment whose time has passed — call when the app becomes active.
    public func endExpired(now: Date = .now) {
        for activity in Activity<PetMomentAttributes>.activities where activity.content.state.endsAt <= now {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    public func endAll() {
        expiry?.cancel()
        for activity in Activity<PetMomentAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}

/// Decides when a pet moment happens. Rate-limited via the App Group so every process agrees.
public struct PetMomentScheduler {
    public struct Decision: Equatable, Sendable {
        public var kind: PetMomentAttributes.Kind
        public var mood: Mood
        public var intensity: MoodIntensity
        public var message: String
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    public init(defaults: UserDefaults = SharedStateStore.shared.defaultsSuite, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    // MARK: Triggers

    /// Right after a log.
    public func moodLogged(_ mood: Mood, intensity: MoodIntensity, identity: PetIdentity, liveActivitiesEnabled: Bool, now: Date = .now) -> Decision? {
        guard liveActivitiesEnabled else { return nil }
        let name = identity.name
        let kind: PetMomentAttributes.Kind
        let message: String
        switch mood {
        case .excited where intensity >= .moderate, .happy where intensity == .strong:
            kind = .celebration
            message = ["\(name) is thrilled.", "\(name) can’t sit still.", "Good day for \(name) too."].randomElement()!
        case .stressed, .sad:
            kind = .breather
            message = ["\(name) is sitting with you.", "\(name) is here.", "No rush. \(name) is staying put."].randomElement()!
        default:
            kind = .moodChange
            message = "\(name) \(mood.petDescription)."
        }
        record(kind, at: now)
        // The breather shows the pet settled and present, not re-enacting the stress.
        if kind == .breather { return Decision(kind: kind, mood: .calm, intensity: .slight, message: message) }
        return Decision(kind: kind, mood: mood, intensity: intensity, message: message)
    }

    /// On foreground: occasional moments, at most one per kind per day and three per day.
    public func foreground(snapshot: PetSnapshot, petMomentsEnabled: Bool, now: Date = .now) -> Decision? {
        guard petMomentsEnabled, momentsToday(now) < 3 else { return nil }
        let name = snapshot.identity.name
        let hour = calendar.component(.hour, from: now)
        let daySeed = Double(calendar.ordinality(of: .day, in: .era, for: now) ?? 0)

        if (20...22).contains(hour), !shownToday(.windDown, now), PetAnimator.hash01(daySeed + 1) < 0.5 {
            record(.windDown, at: now)
            return Decision(kind: .windDown, mood: .tired, intensity: .slight,
                            message: ["\(name) is getting sleepy.", "\(name) is winding down.", "\(name) found a spot by the window."].randomElement()!)
        }

        let sinceLog = snapshot.loggedAt.map { now.timeIntervalSince($0) } ?? .infinity
        if sinceLog > 6 * 3600, (10...19).contains(hour), !shownToday(.company, now), PetAnimator.hash01(daySeed + 2) < 0.35 {
            record(.company, at: now)
            return Decision(kind: .company, mood: .calm, intensity: .slight,
                            message: ["\(name) wants some company.", "\(name) saved you a spot.", "\(name) is hanging out."].randomElement()!)
        }

        if !shownToday(.random, now), PetAnimator.hash01(daySeed + 3 + Double(hour)) < 0.06 {
            record(.random, at: now)
            return Decision(kind: .random, mood: .neutral, intensity: .slight,
                            message: ["\(name) is watching something out the window.", "\(name) is demanding absolutely nothing.", "\(name) stretched, then sat back down."].randomElement()!)
        }
        return nil
    }

    // MARK: Rate limiting

    private func key(_ kind: PetMomentAttributes.Kind) -> String { "moment.last.\(kind.rawValue)" }

    private func shownToday(_ kind: PetMomentAttributes.Kind, _ now: Date) -> Bool {
        guard let last = defaults.object(forKey: key(kind)) as? Date else { return false }
        return calendar.isDate(last, inSameDayAs: now)
    }

    private func momentsToday(_ now: Date) -> Int {
        let dates = defaults.array(forKey: "moment.dates") as? [Date] ?? []
        return dates.filter { calendar.isDate($0, inSameDayAs: now) }.count
    }

    private func record(_ kind: PetMomentAttributes.Kind, at now: Date) {
        defaults.set(now, forKey: key(kind))
        var dates = (defaults.array(forKey: "moment.dates") as? [Date] ?? []).filter { now.timeIntervalSince($0) < 2 * 86400 }
        dates.append(now)
        defaults.set(dates, forKey: "moment.dates")
    }
}

/// Side effect registered by the app: a mood-change moment after each log.
public struct LiveActivityMoodSideEffect: MoodLogSideEffect {
    public var preferences: Preferences
    public init(preferences: Preferences) { self.preferences = preferences }

    public func moodLogged(_ entry: MoodEntry, identity: PetIdentity, snapshot: PetSnapshot) {
        let scheduler = PetMomentScheduler()
        guard let d = scheduler.moodLogged(entry.mood, intensity: entry.intensity, identity: identity, liveActivitiesEnabled: preferences.liveActivitiesEnabled) else { return }
        PetMomentManager.shared.start(kind: d.kind, mood: d.mood, intensity: d.intensity, message: d.message, identity: identity)
    }
}
