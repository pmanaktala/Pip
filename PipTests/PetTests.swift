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
        let scene = PetScene(species: .dog, stance: .mood(.sad, .moderate), pettingSince: base)
        let pose = PetDirector.pose(scene, at: base.addingTimeInterval(1))
        #expect(pose.smileEyes > 0.9 && pose.hearts > 0.5 && pose.blush > 0.5)
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
        let presence = PetPresence(snapshot: PetSnapshot(identity: PetIdentity(species: .dog)))
        var sent: [PetEvent.Kind] = []
        presence.broadcast = { sent.append($0.kind) }
        let now = Date.now
        for i in 0..<5 { presence.tap(onHead: true, now: now.addingTimeInterval(Double(i) * 0.3)) }
        #expect(sent.last == .flustered)
        #expect(sent.first == .boop)
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

enum PetTestSupport {
    static var allStances: [PetStance] {
        Mood.allCases.flatMap { m in MoodIntensity.allCases.map { PetStance.mood(m, $0) } } + PetActivity.allCases.map { .life($0) } + [.meditating]
    }

    static func allClips(_ s: PetSpecies) -> [PetClip] {
        PetVignette.allCases.map { PetClips.vignette($0, s) } + Mood.allCases.map { PetClips.reaction(to: $0, s) }
            + [PetClips.arrive(.mood(.happy, .moderate), s), PetClips.arrive(.mood(.sad, .moderate), s), PetClips.boop(s), PetClips.tickle(s),
               PetClips.flustered(s), PetClips.afterPetting(s), PetClips.wave(s)]
    }
}

extension PetPose {
    var hasNaN: Bool { PetPose.channels.contains { self[keyPath: $0].isNaN || self[keyPath: $0].isInfinite } }
}
