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
                    #expect(a.live.hop >= 0 && a.live.hop <= 26)
                    #expect(a.live.squash > 0.8 && a.live.squash < 1.2)
                    #expect(abs(a.live.lean) <= 16)
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
        let bits: [PetBit] = [.wiggle, .zoomies, .stretch, .curious, .flop, .fidget, .stomp, .sniffle, .meditate]
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
                #expect(live.hop >= -0.001 && live.hop < 40, "\(bit) hop out of range: \(live.hop)")
                #expect(live.squash > 0.7 && live.squash < 1.3, "\(bit) squash out of range: \(live.squash)")
                #expect(abs(live.lean) < 30, "\(bit) lean out of range: \(live.lean)")
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
