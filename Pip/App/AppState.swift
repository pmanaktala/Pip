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
    /// The live pet: its stance, what just happened to it, a finger on it (Docs/Pets/Bible.md).
    let pet: PetPresence
    /// The mood sheet is up (presented from the tab bar accessory; the Pet tab tilts its camera).
    var isPickingMood = false

    var context: ModelContext { container.mainContext }
    private(set) var logger: MoodLogger
    private var remoteChangeObserver: (any NSObjectProtocol)?
    private static var remoteChangeHandler: (@MainActor () -> Void)?

    init(container: ModelContainer = PipModelContainer.shared, preferences: Preferences? = nil, sideEffects: [any MoodLogSideEffect] = []) {
        self.container = container
        let preferences = preferences ?? Preferences.shared
        self.preferences = preferences
        self.logger = MoodLogger(context: container.mainContext, sideEffects: sideEffects)
        self.pet = PetPresence(snapshot: PipQueries.buildSnapshot(in: container.mainContext))
        Haptics.isEnabled = { [preferences] in preferences.hapticsEnabled }
        refresh()
        observeRemoteChanges()
        // Reactions played here are played on the watch too, if it is showing the pet.
        pet.broadcast = { event in DeviceSync.shared.send(event) }
    }

    // MARK: Derived state

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
        #if DEBUG
        // Screenshot automation: `PIP_SPECIES=penguin` overrides the stored pet.
        if let forced = ProcessInfo.processInfo.environment["PIP_SPECIES"], let species = PetSpecies(rawValue: forced) {
            identity = PetIdentity(species: species)
        }
        #endif
        latestEntry = PipQueries.latestEntry(in: context)
        todayEntries = PipQueries.entries(on: .now, in: context)
        logger.refreshSnapshot()
        pet.update(petSnapshot)
    }

    /// The snapshot the pet is drawn from (honours the DEBUG `PIP_MOOD` override).
    var petSnapshot: PetSnapshot {
        var s = snapshot
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["PIP_MOOD"], let mood = Mood(rawValue: forced) {
            s.mood = mood; s.intensity = .moderate; s.loggedAt = Date.now.addingTimeInterval(-600)
        }
        #endif
        return s
    }

    private func observeRemoteChanges() {
        remoteChangeObserver = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { _ in
            Task { @MainActor in AppState.remoteChangeHandler?() }
        }
        AppState.remoteChangeHandler = { [weak self] in self?.refresh() }
    }

    // MARK: Mood

    @discardableResult
    func log(mood: Mood, intensity: MoodIntensity = .moderate, contexts: [MoodContext] = [], note: String? = nil) -> MoodEntry {
        let entry = logger.log(mood: mood, intensity: intensity, contexts: contexts, note: note)
        latestEntry = entry
        todayEntries = PipQueries.entries(on: .now, in: context)
        pet.logged(mood, intensity: intensity, snapshot: snapshot)
        return entry
    }

    func update(_ entry: MoodEntry, intensity: MoodIntensity? = nil, contexts: [MoodContext]? = nil, note: String?? = nil) {
        logger.update(entry, intensity: intensity, contexts: contexts, note: note)
        todayEntries = PipQueries.entries(on: .now, in: context)
        pet.update(petSnapshot)
        DeviceSync.shared.send(entry)
    }

    func delete(_ entry: MoodEntry) {
        let id = entry.id
        logger.delete(entry)
        refresh()
        DeviceSync.shared.sendDeletion(of: id)
    }

    // MARK: Pet

    func selectPet(_ species: PetSpecies, name: String? = nil) {
        guard let profile = PipQueries.petProfile(in: context) else { return }
        let keepName = name ?? (profile.name == profile.species.defaultName ? nil : profile.name)
        profile.identity = PetIdentity(species: species, name: keepName, personality: species.defaultPersonality)
        try? context.save()
        refresh()
        Haptics.success()
        DeviceSync.shared.send(identity: identity)
    }

    func rename(_ name: String) {
        guard let profile = PipQueries.petProfile(in: context) else { return }
        profile.identity = PetIdentity(species: profile.species, name: name, personality: profile.personality)
        try? context.save()
        refresh()
        DeviceSync.shared.send(identity: identity)
    }

    #if DEBUG
    /// Fills two weeks of plausible entries for screenshots and previews.
    func seedDemoData() {
        guard PipQueries.allEntries(in: context).isEmpty else { return }
        let cal = Calendar.current
        let moods: [Mood] = [.calm, .happy, .tired, .stressed, .excited, .neutral, .sad, .frustrated, .happy, .calm]
        for dayOffset in 0..<14 {
            let day = cal.date(byAdding: .day, value: -dayOffset, to: .now)!
            let count = Int(PetMath.hash01(Double(dayOffset)) * 3) + (dayOffset % 4 == 3 ? 0 : 1)
            for i in 0..<count {
                let hour = [9, 14, 20][i % 3]
                let mood = moods[(dayOffset * 3 + i) % moods.count]
                let t = cal.date(bySettingHour: hour, minute: 12 * i, second: 0, of: day)!
                let note = (dayOffset == 0 && i == 1) ? "Deployment broke again." : nil
                let contexts: [MoodContext] = mood == .stressed ? [.work] : (mood == .happy ? [.friends] : [])
                context.insert(MoodEntry(mood: mood, intensity: MoodIntensity(rawValue: 1 + (i + dayOffset) % 3)!, contexts: contexts, note: note, timestamp: t))
            }
        }
        try? context.save()
        refresh()
    }
    #endif

    // MARK: Moments & deep links

    /// Requested by a Live Activity or notification tap.
    var pendingRoute: Route?
    var presentSit = false
    enum Route: Equatable { case sit, home }

    func handle(url: URL) {
        switch url.host() {
        case "sit": pendingRoute = .sit
        default: pendingRoute = .home
        }
    }

    /// Company that has outstayed its time leaves the Lock Screen when the app comes back.
    func tidyLiveActivities() {
        PetCompanyManager.shared.endExpired()
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
