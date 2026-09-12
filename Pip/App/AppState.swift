import CoreData
import Foundation
import Observation
import SwiftData
import SwiftUI

/// The app's single source of truth for what the pet is and how it feels right now.
///
/// Reads and writes go through the main `ModelContext`; widgets get the same truth via
/// the App Group snapshot that `MoodLogger` refreshes after every change.
@MainActor
@Observable
final class AppState {
    let container: ModelContainer
    let preferences: Preferences
    private(set) var identity: PetIdentity = .placeholder
    private(set) var latestEntry: MoodEntry?
    private(set) var todayEntries: [MoodEntry] = []
    /// Set while the user is choosing a mood so the pet previews it.
    var preview: (mood: Mood, intensity: MoodIntensity)?
    /// A transient reaction (the user poked the pet).
    private(set) var poke: PetMoodState?

    var context: ModelContext { container.mainContext }
    private(set) var logger: MoodLogger
    private var remoteChangeObserver: (any NSObjectProtocol)?

    init(container: ModelContainer = PipModelContainer.shared, preferences: Preferences = .shared, sideEffects: [any MoodLogSideEffect] = []) {
        self.container = container
        self.preferences = preferences
        self.logger = MoodLogger(context: container.mainContext, sideEffects: sideEffects)
        Haptics.isEnabled = { [preferences] in preferences.hapticsEnabled }
        refresh()
        observeRemoteChanges()
    }

    // MARK: Derived state

    /// What the pet should look like right now.
    var displayedState: PetMoodState {
        if let poke { return poke }
        if let preview { return PetStateResolver.resolve(mood: preview.mood, intensity: preview.intensity, identity: identity) }
        return snapshot.state()
    }

    var snapshot: PetSnapshot {
        PetSnapshot(identity: identity,
                    mood: latestEntry?.mood,
                    intensity: latestEntry?.intensity,
                    loggedAt: latestEntry?.timestamp,
                    today: todayEntries.map { MoodStamp(id: $0.id, mood: $0.mood, intensity: $0.intensity, time: $0.timestamp) })
    }

    /// True if the latest entry is recent enough to still "be" the current mood.
    var hasFreshMood: Bool {
        guard let t = latestEntry?.timestamp else { return false }
        return Date.now.timeIntervalSince(t) < PetSnapshot.freshness
    }

    // MARK: Loading

    func refresh() {
        identity = PipQueries.petProfile(in: context)?.identity ?? .placeholder
        latestEntry = PipQueries.latestEntry(in: context)
        todayEntries = PipQueries.entries(on: .now, in: context)
        logger.refreshSnapshot()
    }

    private func observeRemoteChanges() {
        remoteChangeObserver = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: Mood

    @discardableResult
    func log(mood: Mood, intensity: MoodIntensity = .moderate, contexts: [MoodContext] = [], note: String? = nil) -> MoodEntry {
        preview = nil
        let entry = logger.log(mood: mood, intensity: intensity, contexts: contexts, note: note)
        latestEntry = entry
        todayEntries = PipQueries.entries(on: .now, in: context)
        return entry
    }

    func update(_ entry: MoodEntry, intensity: MoodIntensity? = nil, contexts: [MoodContext]? = nil, note: String?? = nil) {
        logger.update(entry, intensity: intensity, contexts: contexts, note: note)
        todayEntries = PipQueries.entries(on: .now, in: context)
    }

    func delete(_ entry: MoodEntry) {
        logger.delete(entry)
        refresh()
    }

    // MARK: Pet

    func selectPet(_ species: PetSpecies, name: String? = nil) {
        guard let profile = PipQueries.petProfile(in: context) else { return }
        let keepName = name ?? (profile.name == profile.species.defaultName ? nil : profile.name)
        profile.identity = PetIdentity(species: species, name: keepName, personality: species.defaultPersonality)
        try? context.save()
        refresh()
        Haptics.success()
    }

    func rename(_ name: String) {
        guard let profile = PipQueries.petProfile(in: context) else { return }
        profile.identity = PetIdentity(species: profile.species, name: name, personality: profile.personality)
        try? context.save()
        refresh()
    }

    /// A tiny reaction when the pet is tapped: a quick happy blink, then back to normal.
    func pokePet() {
        var state = displayedState
        state.rig.eyeArc = max(state.rig.eyeArc, 0.8)
        state.rig.mouthCurve = max(state.rig.mouthCurve, 0.6)
        state.rig.lift -= 6
        state.rig.squash = min(1.12, state.rig.squash + 0.08)
        state.rig.earLift = 1
        state.motion.bounceAmount = 0
        poke = state
        Haptics.soft()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { poke = nil }
        }
    }

    // MARK: Deletion

    /// Deletes every local record. CloudKit mirrors the deletion through SwiftData.
    func deleteAllData() {
        try? context.delete(model: MoodEntry.self)
        try? context.delete(model: PetProfile.self)
        try? context.save()
        SharedStateStore.shared.clear()
        preferences.reset()
        refresh()
    }
}
