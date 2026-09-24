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
    private(set) var adoptedAt: Date?
    private(set) var roughYesterday = false
    /// The same live pet as the phone's: same stance, same clock, reactions shared both ways.
    let pet: PetPresence
    private let logger: MoodLogger
    private var remoteChangeObserver: (any NSObjectProtocol)?
    private static var remoteChangeHandler: (@MainActor () -> Void)?

    var context: ModelContext { container.mainContext }

    init(container: ModelContainer = PipModelContainer.shared, preferences: Preferences? = nil) {
        self.container = container
        let preferences = preferences ?? Preferences.shared
        self.preferences = preferences
        self.logger = MoodLogger(context: container.mainContext, sideEffects: [DeviceSyncSideEffect()])
        self.pet = PetPresence(snapshot: PipQueries.buildSnapshot(in: container.mainContext))
        Haptics.isEnabled = { [preferences] in preferences.hapticsEnabled }
        refresh()
        // Straight to the phone over WatchConnectivity; iCloud catches up on its own.
        DeviceSync.shared.start(container: container)
        DeviceSync.shared.onRemoteChange = { [weak self] in self?.refresh() }
        DeviceSync.shared.onPetEvent = { [weak self] event in self?.pet.receive(event) }
        pet.broadcast = { event in DeviceSync.shared.send(event) }
        remoteChangeObserver = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { _ in
            Task { @MainActor in WatchState.remoteChangeHandler?() }
        }
        WatchState.remoteChangeHandler = { [weak self] in self?.refresh() }
    }

    func refresh() {
        let profile = PipQueries.petProfile(in: context)
        identity = profile?.identity ?? .placeholder
        adoptedAt = profile?.createdAt
        roughYesterday = PipQueries.roughYesterday(in: context)
        latestEntry = PipQueries.latestEntry(in: context)
        todayEntries = PipQueries.entries(on: .now, in: context)
        logger.refreshSnapshot()
        pet.update(snapshot)
    }

    var snapshot: PetSnapshot {
        PetSnapshot(identity: identity, mood: latestEntry?.mood, intensity: latestEntry?.intensity, loggedAt: latestEntry?.timestamp,
                    today: todayEntries.map { MoodStamp(id: $0.id, mood: $0.mood, intensity: $0.intensity, time: $0.timestamp) },
                    adoptedAt: adoptedAt, roughYesterday: roughYesterday)
    }

    var hasFreshMood: Bool {
        guard let t = latestEntry?.timestamp else { return false }
        return Date.now.timeIntervalSince(t) < PetSnapshot.freshness
    }

    // MARK: Actions

    @discardableResult
    func log(mood: Mood, intensity: MoodIntensity = .moderate) -> MoodEntry {
        let entry = logger.log(mood: mood, intensity: intensity)
        latestEntry = entry
        todayEntries = PipQueries.entries(on: .now, in: context)
        Haptics.success()
        pet.logged(mood, intensity: intensity, snapshot: snapshot)
        return entry
    }
}
