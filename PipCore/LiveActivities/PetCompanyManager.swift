import ActivityKit
import Foundation
import OSLog

/// Starts, updates and ends the "keeping you company" Live Activity. Never more than one.
///
/// The activity stays *active* so it lives in the Dynamic Island too. Two thirds of the way
/// through it goes stale and the view shows the pet dozing — a change with no update needed.
/// It ends on the next log (replaced), when the app finds it expired, or after the system's limit.
@MainActor
public final class PetCompanyManager {
    public static let shared = PetCompanyManager()
    private let log = Logger(subsystem: "com.pmanaktala.Pip", category: "LiveActivity")
    private var expiry: Task<Void, Never>?

    public var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    public func start(mood: Mood, intensity: MoodIntensity, identity: PetIdentity, now: Date = .now) {
        guard isAvailable else { return }
        endAll()
        let seed = Int(now.timeIntervalSince1970 / 60)
        let state = PetCompanyAttributes.ContentState(mood: mood, intensity: intensity,
                                                      line: PetCompanyWords.line(for: mood, name: identity.name, seed: seed), startedAt: now)
        let duration = PetCompanyWords.duration(for: mood)
        let content = ActivityContent(state: state, staleDate: now.addingTimeInterval(duration * 0.67), relevanceScore: 50)
        do {
            let activity = try Activity.request(attributes: PetCompanyAttributes(identity: identity), content: content, pushType: nil)
            log.info("Started company for \(mood.rawValue, privacy: .public)")
            expiry = Task {
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        } catch {
            log.error("Could not start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Ends company that has outstayed its time — call when the app comes forward.
    public func endExpired(now: Date = .now) {
        for activity in Activity<PetCompanyAttributes>.activities {
            let state = activity.content.state
            if now.timeIntervalSince(state.startedAt) >= PetCompanyWords.duration(for: state.mood) {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
        }
    }

    /// Petting from the Lock Screen or the Dynamic Island: the pet leans in, then settles on a
    /// different still pose so the moment leaves a trace.
    public func pet(name: String) async {
        guard let activity = Activity<PetCompanyAttributes>.activities.first else { return }
        let original = activity.content
        var state = original.state
        let calm = state.line
        state.petted = true
        state.line = PetCompanyWords.petted(name)
        await activity.update(ActivityContent(state: state, staleDate: original.staleDate, relevanceScore: 60))
        try? await Task.sleep(for: .seconds(3.2))
        state.petted = false
        state.line = calm
        state.hold += 1
        await activity.update(ActivityContent(state: state, staleDate: original.staleDate, relevanceScore: 50))
    }

    public func endAll() {
        expiry?.cancel()
        for activity in Activity<PetCompanyAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}

/// Registered by the app: company after each log.
public struct LiveActivityMoodSideEffect: MoodLogSideEffect {
    public var preferences: Preferences
    public init(preferences: Preferences) { self.preferences = preferences }

    public func moodLogged(_ entry: MoodEntry, identity: PetIdentity, snapshot: PetSnapshot) {
        guard preferences.liveActivitiesEnabled else { return }
        PetCompanyManager.shared.start(mood: entry.mood, intensity: entry.intensity, identity: identity)
    }
}
