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
                    #expect(a.live.hop >= 0 && a.live.hop <= 20)
                    #expect(a.live.squash > 0.85 && a.live.squash < 1.15)
                    #expect(abs(a.live.lean) <= 3)
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
