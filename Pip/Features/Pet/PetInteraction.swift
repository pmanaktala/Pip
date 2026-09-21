import SwiftUI

/// How the pet answers touch. A tap gets a hello that depends on the mood; taps in quick
/// succession escalate from hello to giggles to "okay, that's enough"; a held finger is petting;
/// and while a finger is on the room the pet's eyes follow it. All of it layers on the resolved
/// state in `displayedState`, so a reaction never loses the mood underneath.
extension AppState {

    // MARK: Looking

    /// Where the pet looks, in -1…1 relative to its head. `nil` returns control to idle motion.
    func look(at target: CGPoint?) {
        lookTarget = target
    }

    // MARK: Petting

    func startPetting() {
        guard !isPetting else { return }
        reactionTask?.cancel()
        isPetting = true
        Haptics.soft()
        purrTask = Task { @MainActor in
            // A slow purr in the fingertips for as long as the hand stays.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.7))
                guard !Task.isCancelled else { return }
                Haptics.soft()
            }
        }
    }

    func stopPetting() {
        guard isPetting else { return }
        purrTask?.cancel()
        purrTask = nil
        isPetting = false
        // A contented settle after the hand leaves.
        var settle = currentMoodState
        settle.rig.eyeArc = max(settle.rig.eyeArc, 0.9)
        settle.rig.mouthCurve = max(settle.rig.mouthCurve, 0.7)
        settle.rig.blush = 1
        settle.rig.tilt += 6
        settle.accessory = .heart
        perform(settle, for: 1.2)
    }

    /// The petting pose, layered over the mood: eyes shut, leaning into the hand, purring breath.
    func pettingOverlay(_ base: PetMoodState) -> PetMoodState {
        var s = base
        s.rig.eyeOpen = 0
        s.rig.eyeArc = 1
        s.rig.mouthCurve = max(s.rig.mouthCurve, 0.75)
        s.rig.mouthOpen = 0
        s.rig.blush = 1
        s.rig.tilt = base.rig.tilt + 9
        s.rig.headDrop = min(s.rig.headDrop, 0.15)
        s.rig.headTurn = 0
        s.rig.lying = min(s.rig.lying, 0.3)
        s.rig.armCross = max(s.rig.armCross, 0.5)
        s.rig.armRaise = 0
        s.rig.browInnerUp = min(s.rig.browInnerUp, 0.3)
        s.rig.sweat = 0
        s.rig.squash = max(s.rig.squash, 1.0)
        s.motion.breathRate = 0.38
        s.motion.breathAmount = 0.05
        s.motion.hopHeight = 0
        s.motion.shiver = 0
        s.motion.nod = 0
        s.motion.bit = .none
        s.motion.blinkInterval = .infinity
        s.motion.gazeInterval = .infinity
        s.accessory = .heart
        return s
    }

    /// Eyes (and a little of the head) follow the finger; idle glances pause while it is there.
    func lookOverlay(_ base: PetMoodState, target: CGPoint) -> PetMoodState {
        var s = base
        s.rig.gazeX = Double(target.x).clamped(-1, 1)
        s.rig.gazeY = Double(target.y).clamped(-1, 1) * 0.7
        s.rig.headTurn = (Double(target.x) * 0.7).clamped(-1, 1)
        s.rig.eyeOpen = max(s.rig.eyeOpen, 0.55)
        s.motion.gazeInterval = .infinity
        return s
    }

    // MARK: Tapping

    /// One tap says hello in the pet's current mood. Quick repeats escalate: giggles, then dizzy.
    func pokePet() {
        let now = Date.now
        tapStreak = now.timeIntervalSince(lastTapAt) < 2.5 ? tapStreak + 1 : 1
        lastTapAt = now
        let reaction = PetReaction.tap(on: currentMoodState, streak: tapStreak)
        if tapStreak >= 6 { tapStreak = 0 }
        reaction.strong ? Haptics.light() : Haptics.soft()
        perform(reaction.first, then: reaction.second, hold: reaction.hold, settle: reaction.settle)
    }

    // MARK: Plumbing

    /// The resolved mood with no reaction on top (honours the DEBUG `PIP_MOOD` override).
    var currentMoodState: PetMoodState {
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["PIP_MOOD"], let mood = Mood(rawValue: forced) {
            return PetStateResolver.resolve(mood: mood, intensity: .moderate, identity: identity)
        }
        #endif
        return snapshot.state()
    }

    /// Shows `first`, then `second`, then returns to the resolved state. Cancels anything running.
    func perform(_ first: PetMoodState, then second: PetMoodState, hold: Double, settle: Double) {
        reactionTask?.cancel()
        withAnimation(.spring(duration: 0.35, bounce: 0.45)) { poke = first }
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) { poke = second }
            try? await Task.sleep(for: .seconds(settle))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.5)) { poke = nil }
        }
    }

    /// Shows one state for a while, then returns.
    func perform(_ state: PetMoodState, for seconds: Double) {
        reactionTask?.cancel()
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) { poke = state }
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.6)) { poke = nil }
        }
    }
}

/// A two-beat reaction: `first`, then `second`, then back to the mood.
struct PetReaction {
    var first: PetMoodState
    var second: PetMoodState
    var hold: Double
    var settle: Double
    var strong = false

    /// What a tap gets, given the mood and how many taps came in quick succession.
    static func tap(on base: PetMoodState, streak tapStreak: Int) -> PetReaction {
        if tapStreak >= 6 {
            // Okay, okay. Dizzy, a sweat drop, a wobble, and a sit-down. Then a reset.
            var dizzy = base
            dizzy.rig.eyeSquint = 1
            dizzy.rig.eyeOpen = 0.6
            dizzy.rig.mouthWobble = 1
            dizzy.rig.mouthCurve = 0
            dizzy.rig.sweat = 1
            dizzy.rig.tilt = tapStreak.isMultiple(of: 2) ? 16 : -16
            dizzy.rig.squash = 0.94
            dizzy.rig.armOut = 0.6
            dizzy.rig.blush = 0.6
            dizzy.motion.hopHeight = 0
            dizzy.motion.bit = .none
            dizzy.accessory = nil
            var sit = dizzy
            sit.rig.tilt = 0
            sit.rig.eyeSquint = 0.4
            sit.rig.eyeOpen = 0.8
            sit.rig.mouthWobble = 0
            sit.rig.mouthCurve = 0.3
            sit.rig.armOut = 0
            return PetReaction(first: dizzy, second: sit, hold: 0.5, settle: 1.6, strong: true)
        }

        if tapStreak >= 2 {
            // Tickled: a giggle wiggle, arms out, hearts. Alternates the lean each tap.
            var giggle = base
            giggle.rig.eyeArc = 1
            giggle.rig.eyeOpen = 0.9
            giggle.rig.mouthOpen = 0.55
            giggle.rig.mouthCurve = 1
            giggle.rig.blush = 1
            giggle.rig.lean = tapStreak.isMultiple(of: 2) ? 11 : -11
            giggle.rig.tilt = tapStreak.isMultiple(of: 2) ? -8 : 8
            giggle.rig.lift = base.rig.lift - 9
            giggle.rig.squash = min(1.1, base.rig.squash + 0.07)
            giggle.rig.armOut = 0.9
            giggle.rig.armCross = 0
            giggle.rig.headDrop = 0
            giggle.rig.lying = min(base.rig.lying, 0.2)
            giggle.rig.browInnerUp = 0
            giggle.motion.hopHeight = 0
            giggle.motion.bit = .none
            giggle.accessory = .heart
            var settle = giggle
            settle.rig.lean = 0
            settle.rig.lift = base.rig.lift
            settle.rig.squash = base.rig.squash
            settle.rig.mouthOpen = 0.2
            settle.rig.armOut = 0.4
            return PetReaction(first: giggle, second: settle, hold: 0.28, settle: 0.9, strong: true)
        }

        // First tap: hello, in character.
        var hello = base
        var settle = base
        hello.motion.hopHeight = 0
        hello.motion.bit = .none
        settle.motion.bit = .none
        var hold = 0.32, tail = 0.9

        switch base.mood {
        case .happy, .neutral:
            hello.rig.eyeArc = max(hello.rig.eyeArc, 0.8)
            hello.rig.mouthCurve = max(hello.rig.mouthCurve, 0.7)
            hello.rig.mouthOpen = 0.25
            hello.rig.lift = base.rig.lift - 16
            hello.rig.squash = min(1.1, base.rig.squash + 0.07)
            hello.rig.earLift = 1
            hello.rig.armRaise = 1
            hello.rig.tilt = 8
            hello.accessory = .heart
            settle.rig.armRaise = 0.35
            settle.rig.eyeArc = max(base.rig.eyeArc, 0.4)
            settle.accessory = .heart
        case .excited:
            hello.rig.lift = base.rig.lift - 22
            hello.rig.squash = 1.1
            hello.rig.armRaise = 1
            hello.rig.mouthOpen = 0.9
            hello.rig.eyeScale = 1.25
            hello.accessory = .sparkles
            settle.rig.armRaise = 0.7
            settle.accessory = .heart
        case .calm:
            // A slow blink and a head tilt: quietly pleased to see you.
            hello.rig.eyeOpen = 0
            hello.rig.mouthCurve = 0.7
            hello.rig.tilt = 14
            hello.rig.blush = 0.7
            hello.accessory = .heart
            hold = 0.5
            settle.rig.eyeOpen = 0.9
            settle.rig.eyeArc = 0.6
            settle.rig.tilt = 8
            settle.accessory = .heart
        case .tired:
            // One eye opens a crack, a grumble, and straight back to sleep.
            hello.rig.eyeOpen = 0.45
            hello.rig.lidHeaviness = 0.9
            hello.rig.mouthCurve = -0.1
            hello.rig.tilt = base.rig.tilt + 6
            hello.rig.headDrop = 0.4
            hello.accessory = nil
            hold = 0.7
            settle = base
            settle.rig.eyeOpen = 0.05
            settle.motion.bit = .none
            tail = 0.6
        case .sad:
            // Looks up from under the umbrella; the smallest smile. Comforted, not fixed.
            hello.rig.headDrop = 0.2
            hello.rig.gazeY = -0.35
            hello.rig.mouthCurve = 0.3
            hello.rig.mouthWobble = 0
            hello.rig.browInnerUp = 0.6
            hello.rig.eyeOpen = 1
            hello.rig.blush = 0.5
            hold = 0.6
            settle.rig.headDrop = 0.45
            settle.rig.mouthCurve = 0.15
            settle.accessory = base.accessory
            tail = 1.2
        case .stressed:
            // Startled: a jump and a shiver, then a relieved breath.
            hello.rig.eyeScale = 1.35
            hello.rig.pupilScale = 0.6
            hello.rig.lift = base.rig.lift - 12
            hello.rig.squash = 1.08
            hello.rig.armCross = 0
            hello.rig.armRaise = 1
            hello.rig.mouthOpen = 0.5
            hello.motion.shiver = 3
            hold = 0.26
            settle.rig.mouthCurve = 0.4
            settle.rig.browInnerUp = 0.3
            settle.rig.eyeOpen = 0.6
            settle.rig.armCross = 0.5
            settle.rig.sweat = 0.4
            settle.motion.shiver = 0.5
            settle.accessory = .heart
        case .frustrated:
            // Hmph. Turns the other way, eyes shut… then peeks.
            hello.rig.headTurn = base.rig.headTurn > 0 ? -0.9 : 0.9
            hello.rig.eyeOpen = 0
            hello.rig.armCross = 1
            hello.rig.tilt = -10
            hello.rig.mouthCurve = -0.5
            hello.accessory = base.accessory
            hold = 0.7
            settle = hello
            settle.rig.eyeOpen = 0.45
            settle.rig.eyeSquint = 0.8
            settle.rig.mouthCurve = -0.2
            settle.rig.gazeX = -hello.rig.headTurn
            tail = 1.0
        }
        return PetReaction(first: hello, second: settle, hold: hold, settle: tail)
    }
}
