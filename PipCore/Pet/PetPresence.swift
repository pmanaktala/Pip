import CoreGraphics
import Foundation
import Observation

/// The live pet on a device: which stance it is in, what just happened to it, and whether a
/// finger is on it. The phone's `AppState` and the watch's `WatchState` each own one; both
/// derive the stance from the same snapshot and clock, and pass their events to each other, so
/// the pet on your wrist does what the pet on your phone does (Bible §6).
@MainActor
@Observable
public final class PetPresence {
    public private(set) var scene: PetScene
    public private(set) var identity: PetIdentity
    /// Called for events worth playing on the other device too.
    @ObservationIgnored public var broadcast: ((PetEvent) -> Void)?

    @ObservationIgnored private var lastLoggedAt: Date?
    @ObservationIgnored private var tapStreak = 0
    @ObservationIgnored private var lastTapAt = Date.distantPast
    @ObservationIgnored private var clock: Task<Void, Never>?
    @ObservationIgnored private var snapshot: PetSnapshot

    public init(snapshot: PetSnapshot, now: Date = .now) {
        self.snapshot = snapshot
        self.identity = snapshot.identity
        self.scene = PetScene(species: snapshot.identity.species, stance: snapshot.stance(at: now))
        self.lastLoggedAt = snapshot.loggedAt
    }

    public var stance: PetStance { scene.stance }

    /// "Pebble is reading", always matching what is on screen.
    public var statusLine: String {
        if let preview = scene.preview { return PetStance.mood(preview, .moderate).describe(identity.name) }
        return scene.stance.describe(identity.name)
    }

    /// The same without the name ("Reading"), for places where the name is right above it.
    public var statusPhrase: String {
        let line = statusLine
        let prefix = identity.name + " is "
        guard line.hasPrefix(prefix) else { return line }
        let rest = line.dropFirst(prefix.count)
        return rest.prefix(1).uppercased() + rest.dropFirst()
    }

    // MARK: State

    /// Call whenever the snapshot changes (a log here or on the other device, a new pet).
    /// A mood logged in the last few seconds that this device has not reacted to yet plays its
    /// reaction here too.
    public func update(_ snapshot: PetSnapshot, now: Date = .now) {
        self.snapshot = snapshot
        identity = snapshot.identity
        scene.species = snapshot.identity.species
        if let at = snapshot.loggedAt, let mood = snapshot.mood, at != lastLoggedAt {
            lastLoggedAt = at
            if now.timeIntervalSince(at) < 20 { add(PetEvent(.logged(mood, snapshot.intensity ?? .moderate), at: now), share: false) }
        }
        setStance(snapshot.stance(at: now), now: now)
    }

    /// Re-checks the stance every minute (moods fade, the day moves on) while the pet is shown.
    public func startClock() {
        clock?.cancel()
        clock = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60 - Double(Calendar.current.component(.second, from: .now))))
                guard let self, !Task.isCancelled else { return }
                self.setStance(self.snapshot.stance(at: .now), now: .now)
                self.prune(.now)
            }
        }
    }

    public func stopClock() {
        clock?.cancel()
        clock = nil
    }

    private func setStance(_ stance: PetStance, now: Date) {
        guard stance != scene.stance else { return }
        scene.previous = scene.stance
        scene.stance = stance
        scene.stanceSince = now
    }

    // MARK: Things that happen

    /// You arrived (the app came forward, the wrist came up).
    public func arrive(now: Date = .now) {
        // Don't greet twice in a row.
        if let last = scene.events.last(where: { $0.kind == .arrive }), now.timeIntervalSince(last.at) < 20 { return }
        add(PetEvent(.arrive, at: now), share: false)
    }

    /// A mood was logged on this device. The stance changes at once; the reaction plays over it.
    public func logged(_ mood: Mood, intensity: MoodIntensity, snapshot: PetSnapshot, now: Date = .now) {
        self.snapshot = snapshot
        lastLoggedAt = snapshot.loggedAt
        scene.preview = nil
        add(PetEvent(.logged(mood, intensity), at: now), share: false)
        setStance(.mood(mood, intensity), now: now)
    }

    /// A tap on the pet. Head taps boop, body taps tickle; a flurry gets a flustered peek.
    public func tap(onHead: Bool, now: Date = .now) {
        tapStreak = now.timeIntervalSince(lastTapAt) < 1.6 ? tapStreak + 1 : 1
        lastTapAt = now
        if tapStreak >= 5 {
            tapStreak = 0
            add(PetEvent(.flustered, at: now))
        } else {
            add(PetEvent(onHead ? .boop : .tickle, at: now))
        }
    }

    public func wave(now: Date = .now) { add(PetEvent(.wave, at: now)) }

    public var isPetting: Bool { scene.pettingSince != nil }

    public func beginPetting(now: Date = .now) {
        guard scene.pettingSince == nil else { return }
        scene.pettingSince = now
    }

    public func endPetting(now: Date = .now) {
        guard let since = scene.pettingSince else { return }
        scene.pettingSince = nil
        add(PetEvent(.petted, at: now), share: now.timeIntervalSince(since) > 0.6)
    }

    /// Where a finger is, in −1…1 around the head; `nil` when it lifts.
    public func look(at point: CGPoint?) { scene.look = point }

    /// The mood picker's current choice; `nil` when it closes.
    public func preview(_ mood: Mood?) {
        guard scene.preview != mood else { return }
        scene.preview = mood
    }

    /// An event from the other device.
    public func receive(_ event: PetEvent, now: Date = .now) {
        // Messages can arrive late; play it from now if it is still recent.
        guard now.timeIntervalSince(event.at) < 6 else { return }
        add(PetEvent(event.kind, at: now), share: false)
    }

    private func add(_ event: PetEvent, share: Bool = true) {
        prune(event.at)
        scene.events.append(event)
        if share { broadcast?(event) }
    }

    private func prune(_ now: Date) {
        scene.events.removeAll { now.timeIntervalSince($0.at) > 8 }
    }
}

public extension PetSnapshot {
    /// The stance the pet is in at `date`: a fresh mood is always the mood (company in it);
    /// otherwise the pet is getting on with its day.
    func stance(at date: Date = .now, calendar: Calendar = .current) -> PetStance {
        if let mood, let loggedAt, date.timeIntervalSince(loggedAt) <= Self.freshness, date >= loggedAt.addingTimeInterval(-60) {
            return .mood(mood, intensity ?? .moderate)
        }
        return .life(PetDay.activity(at: date, calendar: calendar))
    }
}
