import CoreData
import Foundation
import Observation
import SwiftData
import SwiftUI

/// The watch's view of the shared truth: the pet, the latest mood, today's moments, and the
/// short reaction the pet performs after a tap or a log. A slimmer cousin of the phone's
/// `AppState`; the store, snapshot and complications are the same PipCore plumbing.
@MainActor
@Observable
final class WatchState {
    let container: ModelContainer
    let preferences: Preferences
    private(set) var identity: PetIdentity = .placeholder
    private(set) var latestEntry: MoodEntry?
    private(set) var todayEntries: [MoodEntry] = []
    private(set) var reaction: PetMoodState?
    private var reactionTask: Task<Void, Never>?
    private let logger: MoodLogger
    private var remoteChangeObserver: (any NSObjectProtocol)?
    private static var remoteChangeHandler: (@MainActor () -> Void)?

    var context: ModelContext { container.mainContext }

    init(container: ModelContainer = PipModelContainer.shared, preferences: Preferences? = nil) {
        self.container = container
        let preferences = preferences ?? Preferences.shared
        self.preferences = preferences
        self.logger = MoodLogger(context: container.mainContext, sideEffects: [DeviceSyncSideEffect()])
        Haptics.isEnabled = { [preferences] in preferences.hapticsEnabled }
        refresh()
        // Straight to the phone over WatchConnectivity; iCloud catches up on its own.
        DeviceSync.shared.start(container: container)
        DeviceSync.shared.onRemoteChange = { [weak self] in self?.refresh() }
        remoteChangeObserver = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { _ in
            Task { @MainActor in WatchState.remoteChangeHandler?() }
        }
        WatchState.remoteChangeHandler = { [weak self] in self?.refresh() }
    }

    func refresh() {
        identity = PipQueries.petProfile(in: context)?.identity ?? .placeholder
        latestEntry = PipQueries.latestEntry(in: context)
        todayEntries = PipQueries.entries(on: .now, in: context)
        logger.refreshSnapshot()
    }

    var snapshot: PetSnapshot {
        PetSnapshot(identity: identity, mood: latestEntry?.mood, intensity: latestEntry?.intensity, loggedAt: latestEntry?.timestamp,
                    today: todayEntries.map { MoodStamp(id: $0.id, mood: $0.mood, intensity: $0.intensity, time: $0.timestamp) })
    }

    var hasFreshMood: Bool {
        guard let t = latestEntry?.timestamp else { return false }
        return Date.now.timeIntervalSince(t) < PetSnapshot.freshness
    }

    var displayedState: PetMoodState { reaction ?? snapshot.state() }

    // MARK: Actions

    @discardableResult
    func log(mood: Mood, intensity: MoodIntensity = .moderate) -> MoodEntry {
        let entry = logger.log(mood: mood, intensity: intensity)
        latestEntry = entry
        todayEntries = PipQueries.entries(on: .now, in: context)
        Haptics.success()
        // The new mood's signature bit, straight away, so the log is a performance.
        var encore = PetStateResolver.resolve(mood: mood, intensity: intensity, identity: identity)
        encore.motion.bitInterval = max(encore.motion.bit.duration, 0.1)
        show(encore, for: min(encore.motion.bit.duration * 1.5, 5))
        return entry
    }

    /// A tap on the pet: the same hello the phone gives, in character.
    func poke() {
        let reaction = PetReaction.tap(on: snapshot.state(), streak: 1)
        Haptics.soft()
        reactionTask?.cancel()
        withAnimation(.spring(duration: 0.35, bounce: 0.4)) { self.reaction = reaction.first }
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(reaction.hold))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) { self.reaction = reaction.second }
            try? await Task.sleep(for: .seconds(reaction.settle))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.5)) { self.reaction = nil }
        }
    }

    private func show(_ state: PetMoodState, for seconds: Double) {
        reactionTask?.cancel()
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) { reaction = state }
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.6)) { reaction = nil }
        }
    }
}
