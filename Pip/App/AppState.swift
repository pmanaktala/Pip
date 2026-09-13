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
    private static var remoteChangeHandler: (@MainActor () -> Void)?

    init(container: ModelContainer = PipModelContainer.shared, preferences: Preferences? = nil, sideEffects: [any MoodLogSideEffect] = []) {
        self.container = container
        let preferences = preferences ?? Preferences.shared
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
        #if DEBUG
        // Screenshot automation: `PIP_MOOD=excited` forces the displayed mood.
        if let forced = ProcessInfo.processInfo.environment["PIP_MOOD"], let mood = Mood(rawValue: forced) {
            return PetStateResolver.resolve(mood: mood, intensity: .moderate, identity: identity)
        }
        #endif
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
        #if DEBUG
        // Screenshot automation: `PIP_SPECIES=penguin` overrides the stored pet.
        if let forced = ProcessInfo.processInfo.environment["PIP_SPECIES"], let species = PetSpecies(rawValue: forced) {
            identity = PetIdentity(species: species)
        }
        #endif
        latestEntry = PipQueries.latestEntry(in: context)
        todayEntries = PipQueries.entries(on: .now, in: context)
        logger.refreshSnapshot()
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
        preview = nil
        let entry = logger.log(mood: mood, intensity: intensity, contexts: contexts, note: note)
        latestEntry = entry
        todayEntries = PipQueries.entries(on: .now, in: context)
        react(to: entry)
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

    /// Tap reaction: a quick hop with a heart, then a happy settle, then back to normal.
    func pokePet() {
        var hop = displayedState
        hop.rig.eyeArc = max(hop.rig.eyeArc, 0.8)
        hop.rig.mouthCurve = max(hop.rig.mouthCurve, 0.6)
        hop.rig.mouthOpen = max(hop.rig.mouthOpen, 0.2)
        hop.rig.lift -= 16
        hop.rig.squash = min(1.1, hop.rig.squash + 0.07)
        hop.rig.earLift = 1
        hop.rig.armRaise = 1
        hop.rig.headDrop = 0
        hop.rig.lying = 0
        hop.rig.tilt = 6
        hop.motion.hopHeight = 0
        hop.accessory = .heart
        var settle = hop
        settle.rig.lift = displayedState.rig.lift
        settle.rig.squash = displayedState.rig.squash
        settle.rig.armRaise = 0.3
        settle.rig.mouthOpen = 0
        Haptics.soft()
        withAnimation(.spring(duration: 0.35, bounce: 0.45)) { poke = hop }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.32))
            withAnimation(.spring(duration: 0.45, bounce: 0.35)) { poke = settle }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.smooth(duration: 0.5)) { poke = nil }
        }
    }

    /// Reaction to a freshly logged mood, visible on the Pet tab behind the sheet: the pet jumps
    /// into the new mood (positive) or sinks into it (negative), then settles into the resolved state.
    func react(to entry: MoodEntry) {
        let target = PetStateResolver.resolve(mood: entry.mood, intensity: entry.intensity, identity: identity)
        var burst = target
        if entry.mood.valence >= 0 {
            burst.rig.lift -= 14
            burst.rig.squash = min(1.1, burst.rig.squash + 0.06)
            burst.rig.armRaise = 1
            burst.rig.eyeArc = max(burst.rig.eyeArc, 0.6)
            burst.accessory = entry.mood == .calm ? .heart : .sparkles
        } else {
            burst.rig.squash = max(0.9, burst.rig.squash - 0.05)
            burst.rig.headDrop = min(1, burst.rig.headDrop + 0.2)
        }
        burst.motion.hopHeight = 0
        withAnimation(.spring(duration: 0.4, bounce: 0.4)) { poke = burst }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(.smooth(duration: 0.6)) { poke = nil }
        }
    }

    #if DEBUG
    /// Fills two weeks of plausible entries for screenshots and previews.
    func seedDemoData() {
        guard PipQueries.allEntries(in: context).isEmpty else { return }
        let cal = Calendar.current
        let moods: [Mood] = [.calm, .happy, .tired, .stressed, .excited, .neutral, .sad, .frustrated, .happy, .calm]
        for dayOffset in 0..<14 {
            let day = cal.date(byAdding: .day, value: -dayOffset, to: .now)!
            let count = Int(PetAnimator.hash01(Double(dayOffset)) * 3) + (dayOffset % 4 == 3 ? 0 : 1)
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
    enum Route: Equatable { case sit, home }

    func handle(url: URL) {
        switch url.host() {
        case "sit": pendingRoute = .sit
        default: pendingRoute = .home
        }
    }

    /// Occasional foreground moments (wind-down, company, random). Rate-limited by the scheduler.
    func evaluatePetMoments() {
        PetMomentManager.shared.endExpired()
        guard preferences.hasCompletedOnboarding else { return }
        let scheduler = PetMomentScheduler()
        guard let d = scheduler.foreground(snapshot: snapshot, petMomentsEnabled: preferences.petMomentsEnabled) else { return }
        PetMomentManager.shared.start(kind: d.kind, mood: d.mood, intensity: d.intensity, message: d.message, identity: identity)
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
