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
