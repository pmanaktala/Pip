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
    /// What the phone quietly tells us while the app is in front (see `PetContext`).
    public private(set) var context = PetContext()

    public init(snapshot: PetSnapshot, now: Date = .now) {
        self.snapshot = snapshot
        self.identity = snapshot.identity
        let stance = snapshot.stance(at: now)
        self.scene = PetScene(species: snapshot.identity.species, stance: stance,
                              dressing: PetDressing.choose(for: stance, at: now, adoptedAt: snapshot.adoptedAt))
        self.scene.gentle = snapshot.greetsGently
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
        (scene.preview.map { PetStance.mood($0, .moderate) } ?? scene.stance).phrase(identity.name)
    }

    // MARK: State

    /// Call whenever the snapshot changes (a log here or on the other device, a new pet).
    /// A mood logged in the last few seconds that this device has not reacted to yet plays its
    /// reaction here too.
    public func update(_ snapshot: PetSnapshot, now: Date = .now) {
        self.snapshot = snapshot
        identity = snapshot.identity
        scene.species = snapshot.identity.species
        if scene.gentle != snapshot.greetsGently { scene.gentle = snapshot.greetsGently }
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
        let dressing = PetDressing.choose(for: stance, at: now, context: context, adoptedAt: snapshot.adoptedAt)
        if dressing != scene.dressing { scene.dressing = dressing }
        guard stance != scene.stance else { return }
        scene.previous = scene.stance
        scene.stance = stance
        scene.stanceSince = now
    }

    /// You're listening to something: the pet puts its headphones on (and takes them off).
    public func setMusic(_ playing: Bool, now: Date = .now) {
        var c = context
        c.audioPlaying = playing
        setContext(c, now: now)
    }

    /// New context from the phone: the pet re-dresses (headphones, pillow, suitcase, battery).
    public func setContext(_ new: PetContext, now: Date = .now) {
        guard new != context else { return }
        context = new
        setStance(scene.stance, now: now)
    }

    /// The toy you play with most (see `PetToy.favourite`); now and then it brings it to you.
    public func setFavourite(_ toy: PetToy?) {
        guard scene.favourite != toy else { return }
        scene.favourite = toy
    }

    // MARK: Things that happen

    /// You arrived (the app came forward, the wrist came up).
    public func arrive(now: Date = .now) {
        // Don't greet twice in a row.
        if let last = scene.events.last(where: { $0.kind == .arrive || $0.kind == .missedYou }), now.timeIntervalSince(last.at) < 20 { return }
        add(PetEvent(context.missedYou ? .missedYou : .arrive, at: now), share: false)
    }

    /// A mood was logged on this device. The stance changes at once; the reaction plays over it.
    public func logged(_ mood: Mood, intensity: MoodIntensity, snapshot: PetSnapshot, now: Date = .now) {
        self.snapshot = snapshot
        lastLoggedAt = snapshot.loggedAt
        scene.preview = nil
        scene.gentle = false
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

    /// You're typing a note: it leans in now and then (at most every couple of seconds).
    public func listen(now: Date = .now) {
        if let last = scene.events.last(where: { $0.kind == .listening }), now.timeIntervalSince(last.at) < 2.2 { return }
        add(PetEvent(.listening, at: now), share: false)
    }

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
    ///
    /// Mood gates everything (Bible §4): after a hard feeling (sad, stressed, tired, frustrated)
    /// the pet only keeps you company. After a good or neutral one it can get on with its day in
    /// that mood — working at its laptop in work hours, getting ready for bed late in the evening.
    /// Late at night, an hour after you last told it something, it dozes off beside you.
    func stance(at date: Date = .now, calendar: Calendar = .current) -> PetStance {
        let day = PetDay.activity(at: date, calendar: calendar)
        guard let mood, let loggedAt, date.timeIntervalSince(loggedAt) <= Self.freshness, date >= loggedAt.addingTimeInterval(-60) else {
            return .life(day)
        }
        let intensity = intensity ?? .moderate
        if day == .sleeping, date.timeIntervalSince(loggedAt) > 3600 { return .life(.sleeping) }
        let easy: Set<Mood> = [.happy, .excited, .calm, .neutral]
        guard easy.contains(mood), date.timeIntervalSince(loggedAt) > 90 else { return .mood(mood, intensity) }
        switch day {
        case .working: return .busy(.working, mood, intensity)
        case .windingDown: return mood == .excited ? .mood(mood, intensity) : .busy(.windingDown, mood, intensity)
        default: return .mood(mood, intensity)
        }
    }
}
