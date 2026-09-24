import Foundation
import SwiftUI
import Testing
@testable import Pip

/// The pet's behaviour, checked as rules (Docs/Pets/Bible.md §8).
@Suite struct PetPoseTests {
    @Test func everyStanceRestsInRange() {
        for species in PetSpecies.allCases {
            for stance in PetTestSupport.allStances {
                let rest = stance.rest(species)
                #expect(rest == rest.clamped() || rest.clamped().armL >= -130, "\(stance) \(species)")
                for hold in stance.holds(species) { #expect(!hold.hasNaN) }
            }
        }
    }

    @Test func poseVectorRoundTrips() {
        var p = PetPose()
        p.armR = 120; p.smile = 0.5; p.blink = 0.3
        var q = PetPose()
        q.vector = p.vector
        #expect(q == p)
    }
}

@Suite struct PetClipTests {
    /// Every clip starts and ends where it began, so nothing snaps when it finishes.
    @Test func clipsReturnToRest() {
        for species in PetSpecies.allCases {
            for clip in PetTestSupport.allClips(species) {
                let base = PetStance.mood(.neutral, .moderate).rest(species)
                let end = clip.apply(to: base, at: clip.duration)
                let start = clip.apply(to: base, at: 0)
                for k in PetPose.channels {
                    #expect(abs(end[keyPath: k] - base[keyPath: k]) < 0.02, "\(clip.name) ends off rest on \(k)")
                    #expect(abs(start[keyPath: k] - base[keyPath: k]) < 0.02, "\(clip.name) starts off rest on \(k)")
                }
            }
        }
    }

    @Test func clipsStayFiniteAndInRange() {
        for species in PetSpecies.allCases {
            for clip in PetTestSupport.allClips(species) {
                for step in 0...60 {
                    let pose = clip.apply(to: PetPose(), at: clip.duration * Double(step) / 60).clamped()
                    #expect(!pose.hasNaN, "\(clip.name)")
                    #expect(pose.lift <= 30 && abs(pose.lean) <= 22)
                }
            }
        }
    }
}

@Suite struct PetDirectorTests {
    let base = Date(timeIntervalSince1970: 1_800_000_000)

    /// The phone and the watch compute the same pet for the same scene and clock.
    @Test func directorIsDeterministic() {
        let scene = PetScene(species: .cat, stance: .mood(.happy, .moderate), events: [PetEvent(.boop, at: base.addingTimeInterval(3))])
        for i in 0..<200 {
            let t = base.addingTimeInterval(Double(i) * 0.37)
            #expect(PetDirector.pose(scene, at: t) == PetDirector.pose(scene, at: t))
        }
    }

    @Test func vignettesNeverRepeatBackToBack() {
        for stance in PetTestSupport.allStances {
            let list = stance.repertoire(.dog)
            guard Set(list).count > 1 else { continue }
            var previous: PetVignette?
            for slot in 0..<300 {
                let v = PetDirector.choice(list, slot: slot)
                #expect(v != previous, "\(stance) slot \(slot)")
                previous = v
            }
        }
    }

    @Test func eventsPlayAndEnd() {
        let log = PetEvent(.logged(.excited, .strong), at: base)
        let scene = PetScene(species: .penguin, stance: .mood(.excited, .strong), events: [log])
        let quiet = PetScene(species: .penguin, stance: .mood(.excited, .strong))
        let during = PetDirector.pose(scene, at: base.addingTimeInterval(0.5))
        #expect(during.lift > PetDirector.pose(quiet, at: base.addingTimeInterval(0.5)).lift + 5, "the excited reaction jumps")
        let after = base.addingTimeInterval(PetClips.reaction(to: .excited, .penguin).duration + 0.1)
        #expect(PetDirector.pose(scene, at: after) == PetDirector.pose(quiet, at: after), "and is gone once it has played")
    }

    @Test func pettingClosesEyesHappily() {
        let happy = PetDirector.pose(PetScene(species: .dog, stance: .mood(.happy, .moderate), pettingSince: base), at: base.addingTimeInterval(1))
        #expect(happy.smileEyes > 0.9 && happy.hearts > 0.5 && happy.blush > 0.5)
        // A hard feeling: leans in quietly, a heart or two.
        let sad = PetDirector.pose(PetScene(species: .dog, stance: .mood(.sad, .moderate), pettingSince: base), at: base.addingTimeInterval(1))
        #expect(sad.smileEyes > 0.9 && sad.hearts > 0.2 && sad.hearts < happy.hearts)
        // Asleep: smiles in its sleep, eyes stay shut.
        let asleep = PetDirector.pose(PetScene(species: .dog, stance: .life(.sleeping), pettingSince: base), at: base.addingTimeInterval(1))
        #expect(asleep.lidL > 0.9 && asleep.smile > 0.3)
    }

    @Test func stanceChangesBlend() {
        let scene = PetScene(species: .cat, stance: .mood(.happy, .moderate), previous: .mood(.sad, .moderate), stanceSince: base)
        let mid = PetDirector.primary(scene, t: base.timeIntervalSince1970 + PetDirector.stanceBlend / 2)
        let sad = PetStance.mood(.sad, .moderate).rest(.cat).slump, happy = PetStance.mood(.happy, .moderate).rest(.cat).slump
        #expect(mid.slump < sad && mid.slump > happy - 0.2)
    }
}

@MainActor
@Suite struct PetPresenceTests {
    @Test func loggingChangesStanceAndReacts() {
        let presence = PetPresence(snapshot: PetSnapshot(identity: PetIdentity(species: .penguin)))
        let now = Date.now
        presence.logged(.sad, intensity: .moderate, snapshot: PetSnapshot(identity: PetIdentity(species: .penguin), mood: .sad, intensity: .moderate, loggedAt: now), now: now)
        #expect(presence.stance == .mood(.sad, .moderate))
        #expect(presence.scene.events.contains { $0.kind == .logged(.sad, .moderate) })
        #expect(presence.statusLine == "Pebble is sitting close")
        #expect(presence.statusPhrase == "Sitting close")
    }

    /// A log arriving from the other device plays the reaction here too, once.
    @Test func remoteLogReactsOnce() {
        let presence = PetPresence(snapshot: PetSnapshot(identity: PetIdentity(species: .cat)))
        let now = Date.now
        let snap = PetSnapshot(identity: PetIdentity(species: .cat), mood: .happy, intensity: .moderate, loggedAt: now.addingTimeInterval(-2))
        presence.update(snap, now: now)
        presence.update(snap, now: now.addingTimeInterval(1))
        #expect(presence.scene.events.filter { if case .logged = $0.kind { true } else { false } }.count == 1)
    }

    @Test func tapFlurryGetsFlustered() {
        let presence = PetPresence(snapshot: PetSnapshot(identity: PetIdentity(species: .dog), mood: .happy, intensity: .moderate, loggedAt: .now))
        var sent: [PetEvent.Kind] = []
        presence.broadcast = { sent.append($0.kind) }
        let now = Date.now
        for i in 0..<5 { presence.tap(onHead: true, now: now.addingTimeInterval(Double(i) * 0.3)) }
        #expect(sent.last == .flustered)
        guard case .poke(head: true, _) = sent.first else { Issue.record("a tap should poke"); return }
    }

    /// Taps never answer the same way twice running, and the answer fits the stance.
    @Test func tapsVaryAndFitTheStance() {
        let presence = PetPresence(snapshot: PetSnapshot(identity: PetIdentity(species: .cat), mood: .happy, intensity: .moderate, loggedAt: .now))
        var variants: [Int] = []
        presence.broadcast = { if case .poke(_, let v) = $0.kind { variants.append(v) } }
        let now = Date.now
        for i in 0..<30 { presence.tap(onHead: true, now: now.addingTimeInterval(Double(i) * 2)) }
        #expect(variants.count == 30)
        for (a, b) in zip(variants, variants.dropFirst()) { #expect(a != b, "same poke twice in a row") }
        #expect(Set(variants).count > 2, "uses its range")

        #expect(PetPokes.clip(for: .life(.sleeping), species: .cat, onHead: true, variant: 0).name == "poke.grumpyPeek")
        #expect(PetPokes.clip(for: .mood(.sad, .moderate), species: .cat, onHead: true, variant: 0).name == "poke.leanIn")
        #expect(PetPokes.clip(for: .life(.working), species: .cat, onHead: true, variant: 0).name == "poke.lookUpWave")
        // Nothing giggly for a hard feeling.
        for mood in [Mood.sad, .stressed, .frustrated, .tired] {
            for v in 0..<5 {
                let name = PetPokes.clip(for: .mood(mood, .moderate), species: .dog, onHead: v.isMultiple(of: 2), variant: v).name
                #expect(!["boop", "tickle", "poke.hop", "poke.surprisedLaugh", "poke.wink"].contains(name), "\(mood): \(name)")
            }
        }
    }

    @Test func aSleepingPetTappedAwakeIsGrumpy() {
        let night = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: .now)!
        let presence = PetPresence(snapshot: PetSnapshot(identity: PetIdentity(species: .penguin)), now: night)
        #expect(presence.scene.stance.isAsleep)
        var sent: [PetEvent.Kind] = []
        presence.broadcast = { sent.append($0.kind) }
        for i in 0..<3 { presence.tap(onHead: true, now: night.addingTimeInterval(Double(i) * 0.4)) }
        if case .poke(true, let v) = sent.first { #expect(v >= 0) } else { Issue.record("first tap pokes") }
        #expect(sent.last == .poke(head: true, variant: -1))
    }

    @Test func staleRemoteEventsAreIgnored() {
        let presence = PetPresence(snapshot: PetSnapshot(identity: PetIdentity(species: .dog)))
        presence.receive(PetEvent(.wave, at: .now.addingTimeInterval(-30)))
        #expect(presence.scene.events.isEmpty)
    }
}

@Suite struct PetDayTests {
    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 23; c.hour = hour; c.minute = minute
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    @Test func scheduleFollowsTheClock() {
        let cal = Calendar(identifier: .gregorian)
        #expect(PetDay.activity(at: at(23), calendar: cal) == .sleeping)
        #expect(PetDay.activity(at: at(3), calendar: cal) == .sleeping)
        #expect(PetDay.activity(at: at(7), calendar: cal) == .waking)
        #expect(PetDay.activity(at: at(5, 50), calendar: cal) == .sleeping)
        #expect(PetDay.activity(at: at(6, 5), calendar: cal) == .waking, "wakes at 6")
        #expect(PetDay.activity(at: at(8, 50), calendar: cal) == .waking, "still waking up until 9")
        #expect(!PetDay.isBedtime(at(6, 5), calendar: cal), "nightcap off at 6")
        #expect(PetDay.activity(at: at(20), calendar: cal) == .reading)
        #expect(PetDay.activity(at: at(22), calendar: cal) == .windingDown)
        #expect(PetDay.activity(at: at(10, 30), calendar: cal) == .working, "weekday work hours")
        let saturday = at(10, 30).addingTimeInterval(3 * 86400)
        #expect([.daydreaming, .playing, .reading].contains(PetDay.activity(at: saturday, calendar: cal)), "no work at the weekend")
    }

    @Test func freshMoodWinsThenFades() {
        let logged = at(10)
        let snap = PetSnapshot(identity: .placeholder, mood: .tired, intensity: .strong, loggedAt: logged)
        #expect(snap.stance(at: logged.addingTimeInterval(3600)) == .mood(.tired, .strong))
        if case .life = snap.stance(at: logged.addingTimeInterval(PetSnapshot.freshness + 60)) {} else { Issue.record("mood should fade") }
    }

    /// Mood gates what the pet does: never cheerful work after a hard feeling.
    @Test func moodGatesActivities() {
        let cal = Calendar(identifier: .gregorian)
        let workday = at(10, 30)   // a Wednesday
        #expect(PetDay.activity(at: workday, calendar: cal) == .working)
        let logged = workday.addingTimeInterval(-1800)
        for mood in [Mood.sad, .stressed, .tired, .frustrated] {
            let snap = PetSnapshot(identity: .placeholder, mood: mood, intensity: .moderate, loggedAt: logged)
            #expect(snap.stance(at: workday, calendar: cal) == .mood(mood, .moderate), "\(mood) keeps you company")
        }
        for mood in [Mood.happy, .calm, .neutral, .excited] {
            let snap = PetSnapshot(identity: .placeholder, mood: mood, intensity: .moderate, loggedAt: logged)
            #expect(snap.stance(at: workday, calendar: cal) == .busy(.working, mood, .moderate), "\(mood) gets on with work")
        }
        // Right after a log the pet is with you in the mood, not busy.
        let fresh = PetSnapshot(identity: .placeholder, mood: .happy, intensity: .moderate, loggedAt: workday.addingTimeInterval(-20))
        #expect(fresh.stance(at: workday, calendar: cal) == .mood(.happy, .moderate))
    }

    @Test func nightDozesAndWearsTheNightcap() {
        let cal = Calendar(identifier: .gregorian)
        let late = at(23, 30)
        let sad = PetSnapshot(identity: .placeholder, mood: .sad, intensity: .moderate, loggedAt: late.addingTimeInterval(-600))
        #expect(sad.stance(at: late, calendar: cal) == .mood(.sad, .moderate), "stays up with you")
        #expect(PetWear.choose(for: sad.stance(at: late, calendar: cal), at: late, music: false, calendar: cal) == .nightcap)
        let later = PetSnapshot(identity: .placeholder, mood: .sad, intensity: .moderate, loggedAt: late.addingTimeInterval(-5400))
        #expect(later.stance(at: late, calendar: cal) == .life(.sleeping), "then dozes off beside you")
        #expect(PetWear.choose(for: .mood(.happy, .moderate), at: at(15), music: true, calendar: cal) == .headphones)
        #expect(PetWear.choose(for: .life(.sleeping), at: late, music: true, calendar: cal) == .nightcap, "asleep, it never wears headphones")
    }

    @Test func widgetTimelineIsOrderedAndCyclesPoses() {
        let moments = PetWidgetMoment.timeline(for: PetSnapshot(identity: .placeholder), from: at(9, 10))
        #expect(moments.count >= 16)
        #expect(zip(moments, moments.dropFirst()).allSatisfy { $0.date < $1.date })
        #expect(Set(moments.map(\.hold)).count > 1)
        // The pet shifts on every entry: no two neighbouring entries share a pose.
        for (a, b) in zip(moments.dropFirst(), moments.dropFirst(2)) where a.stance == b.stance {
            #expect(a.hold != b.hold, "\(a.date) → \(b.date)")
        }
        let watch = PetWidgetMoment.timeline(for: PetSnapshot(identity: .placeholder), from: at(9, 10), step: 5)
        #expect(watch.count >= 90, "every five minutes on the watch")
    }
}

@Suite struct PetSpeciesTests {
    @Test func retiredSpeciesDecodeAsPenguin() throws {
        let data = #"{"species":"capybara","name":"Juniper","personality":"serene"}"#.data(using: .utf8)!
        let identity = try JSONDecoder().decode(PetIdentity.self, from: data)
        #expect(identity.species == .penguin)
        #expect(identity.personality == .earnest)
        #expect(PetSpecies(rawValue: "redPanda") == .penguin)
    }

    @Test func companyWordsAreDescriptive() {
        for mood in Mood.allCases {
            for seed in 0..<3 {
                let line = PetCompanyWords.line(for: mood, name: "Pebble", seed: seed)
                #expect(line.hasPrefix("Pebble"))
                #expect(!line.lowercased().contains("should"))
            }
        }
    }
}

@Suite struct PetOccasionTests {
    func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, zone: String = "UTC") -> (Date, Calendar) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: zone)!
        return (cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!, cal)
    }

    @Test func festivalsFollowTheRegion() {
        let (diwali, ist) = day(2026, 11, 8, zone: "Asia/Kolkata")
        #expect(PetHoliday.at(diwali, calendar: ist, region: "IN") == .diwali)
        #expect(PetHoliday.at(diwali, calendar: ist, region: "FR") == nil)
        let (diwali28, _) = day(2028, 10, 17, zone: "Asia/Kolkata")
        #expect(PetHoliday.at(diwali28, calendar: ist, region: "IN") == .diwali)
        let (notDiwali, _) = day(2026, 10, 10, zone: "Asia/Kolkata")
        #expect(PetHoliday.at(notDiwali, calendar: ist, region: "IN") == nil)
        let (cny, cst) = day(2027, 2, 6, zone: "Asia/Shanghai")
        #expect(PetHoliday.at(cny, calendar: cst, region: "CN") == .lunarNewYear)
        let (halloween, utc) = day(2026, 10, 31)
        #expect(PetHoliday.at(halloween, calendar: utc, region: "US") == .halloween)
        #expect(PetHoliday.at(halloween, calendar: utc, region: "JP") == nil)
        let (christmas, _) = day(2026, 12, 25)
        #expect(PetHoliday.at(christmas, calendar: utc, region: "GB") == .christmas)
        #expect(PetHoliday.at(day(2026, 7, 1).0, calendar: utc, region: "US") == nil)
    }

    @Test func festivalsWaitForAGoodMoodAndGiveWayToTheSuitcase() {
        let (christmas, utc) = day(2026, 12, 25)
        #expect(PetDressing.choose(for: .mood(.happy, .moderate), at: christmas, calendar: utc, region: "GB").extra == .tree)
        #expect(PetDressing.choose(for: .mood(.sad, .moderate), at: christmas, calendar: utc, region: "GB").extra == nil)
        var away = PetContext()
        away.travelling = true
        #expect(PetDressing.choose(for: .mood(.happy, .moderate), at: christmas, context: away, calendar: utc, region: "GB").extra == .suitcase)
    }

    @Test func weekendsStartSlower() {
        // 3 Oct 2026 is a Saturday, 5 Oct a Monday, 9 Oct a Friday.
        let (sat7, utc) = day(2026, 10, 3, 7)
        #expect(PetDay.activity(at: sat7, calendar: utc) == .sleeping)
        #expect(PetDay.activity(at: day(2026, 10, 3, 10).0, calendar: utc) == .waking)
        #expect(PetDay.activity(at: day(2026, 10, 5, 7).0, calendar: utc) == .waking)
        #expect(PetDay.activity(at: day(2026, 10, 5, 10).0, calendar: utc) == .working)
        #expect(PetDay.weekVignettes(at: day(2026, 10, 5, 8).0, calendar: utc) == [.mondayStretch])
        #expect(PetDay.weekVignettes(at: day(2026, 10, 9, 19).0, calendar: utc) == [.fridayWiggle])
        #expect(PetDay.weekVignettes(at: day(2026, 10, 7, 19).0, calendar: utc).isEmpty)
    }

    @Test func favouriteToyNeedsAClearLead() throws {
        let suite = "PetToyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(PetToy.favourite(defaults: defaults) == nil)
        for _ in 0..<5 { PetToy.played(.ball, defaults: defaults) }
        for _ in 0..<4 { PetToy.played(.treat, defaults: defaults) }
        #expect(PetToy.favourite(defaults: defaults) == nil, "not clearly ahead")
        PetToy.played(.ball, defaults: defaults)
        #expect(PetToy.favourite(defaults: defaults) == .ball)
    }

    @Test func favouriteJoinsOnlyEasyAwakeStances() {
        var scene = PetScene(species: .dog, stance: .mood(.happy, .moderate))
        scene.favourite = .ball
        let t = 1_800_000_000.0
        #expect(PetDirector.extras(scene, stance: scene.stance, t: t).contains(.offerBall))
        scene.stance = .mood(.sad, .moderate)
        #expect(PetDirector.extras(scene, stance: scene.stance, t: t).isEmpty)
        scene.stance = .life(.sleeping)
        #expect(PetDirector.extras(scene, stance: scene.stance, t: t).isEmpty)
        // Its paws hold the ball while it offers it.
        var pose = PetPose()
        pose.holdToy = 1
        #expect(PetScene(species: .dog, stance: .mood(.happy, .moderate)).prop(for: pose) == .heldBall)
        #expect(PetScene(species: .dog, stance: .mood(.calm, .moderate)).prop(for: pose) == .mug)
    }

    @MainActor @Test func aRoughYesterdayGetsAGentleHello() {
        #expect(PetSnapshot.wasRough([.happy, .sad]))
        #expect(PetSnapshot.wasRough([.stressed, .tired, .happy, .calm]))
        #expect(!PetSnapshot.wasRough([.sad, .happy, .calm]))
        #expect(!PetSnapshot.wasRough([]))
        let snapshot = PetSnapshot(identity: PetIdentity(species: .penguin), roughYesterday: true)
        let pet = PetPresence(snapshot: snapshot)
        #expect(pet.scene.gentle)
        let clip = PetDirector.clip(for: .arrive, stance: .mood(.happy, .moderate), species: .penguin, gentle: true)
        #expect(clip?.name == "gentleHello")
        // Gentle days leave out the bouncy tricks.
        for slot in 0..<40 {
            if let (c, _) = PetDirector.vignette(stance: .mood(.excited, .moderate), species: .penguin, t: Double(slot) * 9 + 3, gentle: true) {
                #expect(!["bounce", "fistPump", "dance", "wiggle", "clap"].contains(c.name))
            }
        }
        pet.logged(.happy, intensity: .moderate, snapshot: snapshot)
        #expect(!pet.scene.gentle)
    }

    @Test func itDancesToMusicButOnlySwaysWhenItsHard() {
        let t = Date(timeIntervalSince1970: 1_800_000_000.3)
        var happy = PetScene(species: .cat, stance: .mood(.happy, .moderate))
        happy.dancing = true
        let still = PetDirector.pose(PetScene(species: .cat, stance: .mood(.happy, .moderate)), at: t)
        let dancing = PetDirector.pose(happy, at: t)
        #expect(dancing.armL + dancing.armR > still.armL + still.armR + 60)
        #expect(dancing.notes > 0.5)
        var sad = PetScene(species: .cat, stance: .mood(.sad, .moderate))
        sad.dancing = true
        let swaying = PetDirector.pose(sad, at: t)
        #expect(swaying.armL < 40 && swaying.notes < 0.1)
    }
}

enum PetTestSupport {
    static var allStances: [PetStance] {
        Mood.allCases.flatMap { m in MoodIntensity.allCases.map { PetStance.mood(m, $0) } } + PetActivity.allCases.map { .life($0) } + [.meditating]
    }

    static func allClips(_ s: PetSpecies) -> [PetClip] {
        PetVignette.allCases.map { PetClips.vignette($0, s) } + Mood.allCases.map { PetClips.reaction(to: $0, s) }
            + [PetClips.arrive(.mood(.happy, .moderate), s), PetClips.arrive(.mood(.sad, .moderate), s), PetClips.boop(s), PetClips.tickle(s),
               PetClips.flustered(s), PetClips.afterPetting(s), PetClips.wave(s), PetClips.gentleHello(s), PetClips.swat(s), PetPokes.wokenUp(s)]
            + [PetStance.life(.sleeping), .life(.waking), .mood(.sad, .moderate), .mood(.stressed, .moderate), .mood(.frustrated, .moderate),
               .mood(.calm, .moderate), .meditating, .life(.working), .life(.reading), .mood(.happy, .moderate), .mood(.neutral, .moderate)]
                .flatMap { st in (0..<6).flatMap { v in [true, false].map { PetPokes.clip(for: st, species: s, onHead: $0, variant: v) } } }
    }
}

extension PetPose {
    var hasNaN: Bool { PetPose.channels.contains { self[keyPath: $0].isNaN || self[keyPath: $0].isInfinite } }
}
