import Foundation
import Testing
@testable import Pip

struct PetAnimatorTests {
    @Test func nilTimeIsStill() {
        let id = PetIdentity(species: .penguin)
        let state = PetStateResolver.resolve(mood: .excited, intensity: .strong, identity: id)
        let (rig, live) = PetAnimator.animate(rig: state.rig, motion: state.motion, time: nil)
        #expect(rig == state.rig)
        #expect(live == .still)
    }

    @Test func motionIsDeterministicAndBounded() {
        for species in PetSpecies.allCases {
            for mood in Mood.allCases {
                let state = PetStateResolver.resolve(mood: mood, intensity: .strong, identity: PetIdentity(species: species))
                for step in 0..<600 {
                    let t = Double(step) * 0.05
                    let a = PetAnimator.animate(rig: state.rig, motion: state.motion, time: t)
                    let b = PetAnimator.animate(rig: state.rig, motion: state.motion, time: t)
                    #expect(a.rig == b.rig && a.live == b.live)
                    // Idle motion plus the mood's signature bit: bigger than idle, still on the canvas.
                    #expect(a.live.hop >= 0 && a.live.hop <= 22)
                    #expect(a.live.squash > 0.72 && a.live.squash < 1.3)
                    #expect(abs(a.live.lean) <= 36)
                    #expect(abs(a.live.headLag) <= 8)
                    #expect((0...1).contains(a.rig.eyeOpen))
                }
            }
        }
    }

    @Test func hopHasAnticipationFlightAndLanding() {
        var motion = PetMotionProfile()
        motion.hopHeight = 10
        motion.hopInterval = 2
        var sawSquash = false, sawAir = false
        for step in 0..<400 {
            let live = PetAnimator.animate(rig: PetRig(), motion: motion, time: Double(step) * 0.01).live
            if live.hop > 5 { sawAir = true }
            if live.hop == 0 && live.squash < 0.99 { sawSquash = true }
        }
        #expect(sawAir && sawSquash)
    }
}

@Suite struct PetBitTests {
    /// Every bit, sampled through several of its cycles, must keep the rig drawable:
    /// finite, inside the clamps the painters assume, and never off the 200pt canvas.
    @Test func bitsStayInRangeAcrossTime() {
        let bits: [PetBit] = [.wiggle, .zoomies, .stretch, .curious, .flop, .fidget, .stomp, .sniffle, .meditate, .tada, .typing, .pageTurn, .snore]
        for bit in bits {
            var motion = PetMotionProfile()
            motion.bit = bit
            motion.bitInterval = 3
            let base = PetStateResolver.resolve(mood: .neutral, identity: PetIdentity(species: .penguin)).rig
            var moved = false
            for i in 0..<600 {
                let t = Double(i) * 0.05
                let (rig, live) = PetAnimator.animate(rig: base, motion: motion, time: t)
                for v in rig.vector.values { #expect(v.isFinite, "\(bit) produced a non-finite rig value at t=\(t)") }
                #expect(rig.eyeOpen >= -0.001 && rig.eyeOpen <= 1.001, "\(bit) eyeOpen out of range: \(rig.eyeOpen)")
                #expect(rig.lying >= 0 && rig.lying <= 1, "\(bit) lying out of range: \(rig.lying)")
                #expect(abs(rig.headTurn) <= 1, "\(bit) headTurn out of range: \(rig.headTurn)")
                #expect(live.hop >= -0.001 && live.hop <= 22, "\(bit) hop out of range: \(live.hop)")
                #expect(live.squash > 0.7 && live.squash < 1.3, "\(bit) squash out of range: \(live.squash)")
                #expect(abs(live.lean) <= 36, "\(bit) lean out of range: \(live.lean)")
                if rig != base || live.hop != 0 || live.lean != 0 { moved = true }
            }
            #expect(moved, "\(bit) never changed anything")
        }
    }

    @Test func everyMoodHasABit() {
        for mood in Mood.allCases {
            let state = PetStateResolver.resolve(mood: mood, identity: PetIdentity(species: .cat))
            #expect(state.motion.bit != .none, "\(mood) has no signature bit")
        }
    }

    @Test func breathCurveIsBoundedAndPeaksOnInhale() {
        for i in 0...100 {
            let b = PetAnimator.breath(phase: Double(i) / 100)
            #expect(b >= 0 && b <= 1)
        }
        #expect(PetAnimator.breath(phase: 0.42) > 0.99)
        #expect(PetAnimator.breath(phase: 0) < 0.01)
    }
}

@Suite struct PetReactionTests {
    /// Every mood answers a tap differently from its rest pose, and escalation changes the answer.
    @Test func everyMoodHasItsOwnHello() {
        let identity = PetIdentity(species: .dog)
        for mood in Mood.allCases {
            let base = PetStateResolver.resolve(mood: mood, identity: identity)
            let hello = PetReaction.tap(on: base, streak: 1)
            let giggle = PetReaction.tap(on: base, streak: 2)
            let dizzy = PetReaction.tap(on: base, streak: 6)
            #expect(hello.first.rig != base.rig, "\(mood): hello looks like rest")
            #expect(giggle.first.rig != hello.first.rig, "\(mood): giggle looks like hello")
            #expect(dizzy.first.rig != giggle.first.rig, "\(mood): dizzy looks like giggle")
            #expect(hello.hold > 0 && hello.settle > 0)
            for v in hello.first.rig.vector.values + giggle.first.rig.vector.values + dizzy.first.rig.vector.values { #expect(v.isFinite) }
        }
    }

    @Test func signaturePosesAreDistinct() {
        // The silhouettes that used to collapse into one must now differ in the body, not just the face.
        let identity = PetIdentity(species: .penguin)
        func body(_ m: Mood) -> [Double] {
            let r = PetStateResolver.resolve(mood: m, identity: identity).rig
            return [r.armRaise, r.armCross, r.armOut, r.squash, r.headDrop, r.lying, r.lean, r.tilt]
        }
        let pairs: [(Mood, Mood)] = [(.neutral, .sad), (.calm, .frustrated), (.happy, .neutral), (.stressed, .calm), (.tired, .sad)]
        for (a, b) in pairs {
            let d = zip(body(a), body(b)).map { abs($0 - $1) }.reduce(0, +)
            #expect(d > 0.6, "\(a) and \(b) share a body pose (distance \(d))")
        }
    }
}

@Suite struct PetLifeTests {
    @Test func scheduleFollowsTheClock() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        func at(_ hour: Int, weekday: Int = 3) -> Date { // 3 = Tuesday
            var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 14 + weekday; c.hour = hour; c.minute = 0 // 15 Sep 2026 is a Tuesday
            return cal.date(from: c)!
        }
        #expect(PetLife.activity(at: at(23), calendar: cal) == .sleeping)
        #expect(PetLife.activity(at: at(3), calendar: cal) == .sleeping)
        #expect(PetLife.activity(at: at(7), calendar: cal) == .waking)
        #expect(PetLife.activity(at: at(11), calendar: cal) == .working)
        #expect(PetLife.activity(at: at(11, weekday: 6), calendar: cal) == .lounging, "Saturday daytime is for lounging")
        #expect(PetLife.activity(at: at(20), calendar: cal) == .reading)
    }

    @Test func everyActivityHasAPoseAPropOrABit() {
        let identity = PetIdentity(species: .cat)
        for activity in PetLife.allCases {
            let s = activity.state(identity: identity)
            #expect(s.motion.bit != .none, "\(activity) has nothing to do")
            for v in s.rig.vector.values { #expect(v.isFinite) }
        }
        #expect(PetLife.sleeping.state(identity: identity).accessory == .nightcap)
        #expect(PetLife.working.state(identity: identity).accessory == .laptop)
        #expect(PetLife.reading.state(identity: identity).accessory == .book)
    }

    @Test func freshMoodBeatsTheSchedule() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        var c = DateComponents(); c.year = 2026; c.month = 9; c.day = 15; c.hour = 23
        let night = cal.date(from: c)!
        let fresh = PetSnapshot(identity: PetIdentity(species: .dog), mood: .excited, intensity: .strong, loggedAt: night.addingTimeInterval(-600))
        #expect(fresh.state(at: night, calendar: cal).mood == .excited, "an excited pet at 11pm is excited, not asleep")
        let faded = PetSnapshot(identity: PetIdentity(species: .dog), mood: .excited, intensity: .strong, loggedAt: night.addingTimeInterval(-12 * 3600))
        #expect(faded.state(at: night, calendar: cal).accessory == .nightcap, "a faded mood at night is sleep")
    }
}
