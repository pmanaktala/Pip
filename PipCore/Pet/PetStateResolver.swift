import Foundation

/// Pure function: (mood, intensity, species, personality) → `PetMoodState`.
///
/// This is the single place that decides what a mood *looks like*. Views, widgets and
/// Live Activities all call it, so the pet is consistent everywhere.
public enum PetStateResolver {

    public static func resolve(mood: Mood, intensity: MoodIntensity = .moderate, identity: PetIdentity) -> PetMoodState {
        resolve(mood: mood, intensity: intensity, species: identity.species, personality: identity.personality)
    }

    public static func resolve(mood: Mood, intensity: MoodIntensity = .moderate, species: PetSpecies, personality: PetPersonality) -> PetMoodState {
        var state = base(for: mood)
        applyIntensity(intensity, to: &state)
        applyPersonality(personality, mood: mood, intensity: intensity, to: &state)
        applySpecies(species, to: &state)
        clamp(&state.rig)
        // Keep hops inside the 200-unit canvas at every intensity and personality.
        state.motion.hopHeight = min(state.motion.hopHeight, 16)
        return state
    }

    /// A gently pleasant resting state used before any mood has been logged.
    public static func resting(identity: PetIdentity) -> PetMoodState {
        resolve(mood: .neutral, intensity: .slight, identity: identity)
    }

    // MARK: - Base states

    private static func base(for mood: Mood) -> PetMoodState {
        var rig = PetRig()
        var motion = PetMotionProfile()
        var env = PetEnvironment()
        var accessory: PetAccessory?

        switch mood {
        case .happy:
            // Sitting tall, chin up, ears and tail up, small hops now and then.
            rig.mouthCurve = 0.85
            rig.mouthOpen = 0.12
            rig.eyeArc = 0.3
            rig.blush = 0.55
            rig.earLift = 0.95
            rig.tailLift = 0.85
            rig.armOut = 0.55
            rig.squash = 1.04
            rig.tilt = 7
            motion.hopHeight = 6
            motion.swayAmount = 2.4
            motion.hopInterval = 4.5
            motion.tailWagRate = 1.1
            motion.tailWagAmount = 0.6
            motion.breathRate = 0.3
            motion.bit = .wiggle
            motion.bitInterval = 9
            env.tintStrength = 0.5

        case .excited:
            // Up on the toes, arms up, mouth open, bouncing.
            rig.mouthCurve = 1
            rig.mouthOpen = 0.6
            rig.mouthWidth = 1.15
            rig.eyeScale = 1.15
            rig.pupilScale = 1.25
            rig.blush = 0.65
            rig.earLift = 1
            rig.tailLift = 1
            rig.armRaise = 1
            rig.squash = 1.08
            rig.lean = 0
            rig.tilt = -5
            motion.hopHeight = 12
            motion.hopInterval = 2.2
            motion.tailWagRate = 2.4
            motion.tailWagAmount = 1
            motion.breathRate = 0.42
            motion.gazeInterval = 1.6
            motion.swayAmount = 0.6
            motion.bit = .zoomies
            motion.bitInterval = 7
            accessory = .sparkles
            env.tintStrength = 0.6

        case .calm:
            // Settled: a little lower, soft eyes, slow breath and the odd sigh.
            rig.mouthCurve = 0.45
            rig.eyeOpen = 0.8
            rig.lidHeaviness = 0.25
            rig.eyeArc = 0.15
            rig.blush = 0.35
            rig.earLift = 0.7
            rig.tailLift = 0.3
            rig.squash = 0.94
            rig.headDrop = 0.2
            rig.armCross = 0.55
            rig.tilt = 5
            motion.breathRate = 0.18
            motion.breathAmount = 0.036
            motion.tailWagRate = 0.25
            motion.tailWagAmount = 0.2
            motion.blinkInterval = 5.5
            motion.gazeInterval = 5
            motion.swayAmount = 0.8
            motion.swayPeriod = 9
            motion.sigh = 0.6
            motion.bit = .stretch
            motion.bitInterval = 16
            env.tintStrength = 0.35

        case .neutral:
            rig.mouthCurve = 0.35
            rig.blush = 0.2
            rig.tilt = 3
            rig.earLift = 0.8
            rig.tailLift = 0.5
            rig.squash = 1.01
            motion.swayAmount = 2
            motion.tailWagRate = 0.4
            motion.tailWagAmount = 0.25
            motion.bit = .curious
            motion.bitInterval = 11
            env.tintStrength = 0.3

        case .tired:
            // Slumped: lying, head sunk, heavy lids, nodding off.
            rig.mouthCurve = 0.1
            rig.eyeOpen = 0.35
            rig.lidHeaviness = 0.8
            rig.eyeSquint = 0.2
            rig.earLift = 0.35
            rig.tailLift = 0.1
            rig.squash = 0.93
            rig.lying = 0.45
            rig.headDrop = 0.65
            rig.blush = 0.3
            rig.gazeY = 0.25
            rig.tilt = 10
            rig.lean = 5
            motion.breathRate = 0.14
            motion.breathAmount = 0.032
            motion.blinkInterval = 2.5
            motion.gazeInterval = 7
            motion.earTwitch = 0.1
            motion.swayAmount = 0.5
            motion.nod = 4
            motion.bit = .flop
            motion.bitInterval = 15
            accessory = .zzz
            env.tintStrength = 0.3
            env.dimness = 0.35
            env.shadowSpread = 1.25

        case .stressed:
            // Hunched and pulled in, wide eyes, shivering bursts.
            rig.mouthCurve = -0.25
            rig.mouthWobble = 0.8
            rig.mouthWidth = 0.85
            rig.eyeScale = 1.08
            rig.pupilScale = 0.7
            rig.browInnerUp = 0.75
            rig.browWeight = 0.9
            rig.earLift = 0.4
            rig.tailLift = 0.2
            rig.squash = 0.95
            rig.headDrop = 0.5
            rig.armCross = 0.9
            rig.sweat = 0.9
            rig.blush = 0.15
            rig.tilt = -3
            motion.shiver = 2.2
            motion.breathRate = 0.5
            motion.breathAmount = 0.016
            motion.blinkInterval = 1.6
            motion.gazeInterval = 0.9
            motion.tailWagRate = 3
            motion.tailWagAmount = 0.3
            motion.earTwitch = 0.9
            motion.swayAmount = 0.4
            motion.bit = .fidget
            motion.bitInterval = 6
            accessory = .stressLines
            env.tintStrength = 0.45

        case .sad:
            // Head down, ears flat, tail on the floor, slow breath with a sigh.
            rig.mouthCurve = -0.6
            rig.mouthWidth = 0.8
            rig.eyeOpen = 0.8
            rig.lidHeaviness = 0.35
            rig.pupilScale = 1.1
            rig.gazeY = 0.35
            rig.browInnerUp = 0.9
            rig.browWeight = 0.8
            rig.earLift = 0.1
            rig.tailLift = 0
            rig.squash = 0.92
            rig.lying = 0.15
            rig.headDrop = 0.8
            rig.armRaise = 0.55 // holding the umbrella up
            rig.tilt = 4
            rig.lean = -3
            rig.blush = 0.1
            motion.breathRate = 0.16
            motion.breathAmount = 0.022
            motion.blinkInterval = 3.2
            motion.gazeInterval = 6
            motion.tailWagRate = 0
            motion.swayAmount = 0.5
            motion.swayPeriod = 10
            motion.sigh = 1
            motion.bit = .sniffle
            motion.bitInterval = 12
            accessory = .umbrella
            env.tintStrength = 0.35
            env.dimness = 0.25

        case .frustrated:
            // Leaning in, brows down, tail stiff and twitching, a huff of steam.
            rig.mouthCurve = -0.45
            rig.mouthWidth = 0.9
            rig.eyeSquint = 0.55
            rig.browInnerUp = -0.85
            rig.browWeight = 1
            rig.earLift = 0.3
            rig.tailLift = 0.75
            rig.squash = 1.03
            rig.armCross = 1
            rig.headTurn = 0.6
            rig.blush = 0.45
            rig.tilt = -6
            rig.lean = -2
            motion.shiver = 0.4
            motion.tailWagRate = 2.4
            motion.tailWagAmount = 0.55
            motion.breathRate = 0.5
            motion.breathAmount = 0.03
            motion.blinkInterval = 3
            motion.swayAmount = 1
            motion.swayPeriod = 3
            motion.bit = .stomp
            motion.bitInterval = 8
            accessory = .steam
            env.tintStrength = 0.45
        }

        return PetMoodState(mood: mood, intensity: .moderate, rig: rig, motion: motion, accessory: accessory, environment: env)
    }

    // MARK: - Intensity

    /// Scales the *distance from neutral* of every expressive field, and the motion amplitudes.
    private static func applyIntensity(_ intensity: MoodIntensity, to state: inout PetMoodState) {
        state.intensity = intensity
        let s = intensity.scale
        let neutral = PetRig()
        state.rig = PetRig.lerp(neutral, state.rig, s)
        // Eye openness should not overshoot past fully open when intensifying.
        state.rig.eyeOpen = min(state.rig.eyeOpen, 1)
        state.rig.squash = max(state.rig.squash, 0.88)
        state.rig.lying = min(state.rig.lying, 0.9)

        state.motion.hopHeight *= s
        state.motion.shiver *= s
        state.motion.tailWagAmount *= min(s, 1.2)
        state.motion.tailWagRate *= (0.8 + 0.2 * s)
        state.motion.nod *= s
        state.motion.sigh *= s

        if intensity == .slight {
            // Slight moods keep their accessory only when it is very characteristic.
            switch state.accessory {
            case .sparkles, .rainCloud, .umbrella, .steam: state.accessory = nil
            default: break
            }
            state.environment.tintStrength *= 0.7
        }
        if intensity == .strong {
            state.environment.tintStrength = min(1, state.environment.tintStrength * 1.25)
        }
    }

    // MARK: - Personality

    private static func applyPersonality(_ personality: PetPersonality, mood: Mood, intensity: MoodIntensity, to state: inout PetMoodState) {
        switch personality {
        case .dramatic:
            // Everything is a little bigger; strong stress or sadness is a full flop.
            state.motion.hopHeight *= 1.2
            state.rig.tilt *= 1.5
            if (mood == .stressed || mood == .sad) && intensity == .strong {
                state.rig.lying = max(state.rig.lying, 0.85)
                state.rig.headDrop = max(state.rig.headDrop, 0.8)
                state.rig.squash = min(state.rig.squash, 0.88)
            }
            if mood == .frustrated { state.rig.mouthCurve -= 0.15 }

        case .optimistic:
            // Never fully frowns; the tail always has a little life in it.
            state.rig.mouthCurve = max(state.rig.mouthCurve, -0.15)
            state.rig.tailLift = max(state.rig.tailLift, 0.4)
            state.motion.tailWagRate = max(state.motion.tailWagRate, 0.6)
            state.motion.tailWagAmount = max(state.motion.tailWagAmount, 0.3)
            state.rig.browInnerUp *= 0.7

        case .serene:
            // Slower, softer everything.
            state.motion.hopHeight *= 0.6
            state.motion.shiver *= 0.5
            state.motion.breathRate *= 0.85
            state.motion.tailWagRate *= 0.7
            state.rig.mouthOpen *= 0.7
            state.rig.lidHeaviness = max(state.rig.lidHeaviness, 0.15)

        case .chaotic:
            // Big reactions, quick eyes.
            state.motion.hopHeight *= 1.4
            state.motion.hopInterval *= 0.8
            state.motion.shiver *= 1.4
            state.motion.gazeInterval *= 0.6
            state.rig.eyeScale *= 1.05
            if mood == .excited { state.rig.mouthOpen = 1; state.rig.armRaise = 1 }

        case .sleepy:
            // Calm and neutral drift toward a nap.
            if mood == .calm || mood == .neutral {
                state.rig.eyeOpen = min(state.rig.eyeOpen, 0.6)
                state.rig.lidHeaviness = max(state.rig.lidHeaviness, 0.45)
                state.rig.lying = max(state.rig.lying, 0.35)
                state.rig.headDrop = max(state.rig.headDrop, 0.3)
                state.motion.nod = max(state.motion.nod, 2)
                if mood == .calm && state.accessory == nil { state.accessory = .zzz }
            }
            state.motion.hopHeight *= 0.7
            state.motion.blinkInterval *= 0.8
        }
    }

    // MARK: - Species

    /// Species-level adjustments that are about anatomy, not feeling.
    private static func applySpecies(_ species: PetSpecies, to state: inout PetMoodState) {
        switch species {
        case .dog:
            // Dogs pant when happy or excited.
            if state.mood == .happy || state.mood == .excited {
                state.rig.tongue = state.mood == .excited ? 1 : 0.6
                state.rig.mouthOpen = max(state.rig.mouthOpen, 0.3)
            }
        case .penguin:
            // Flippers carry a lot of the pose; penguins don't blush as much.
            state.rig.blush *= 0.7
            state.rig.armRaise = max(state.rig.armRaise, state.rig.tailLift * 0.5)
        case .capybara:
            state.motion.breathAmount *= 1.2
            state.motion.hopHeight *= 0.5
        case .cat, .redPanda:
            break
        }
    }

    private static func clamp(_ rig: inout PetRig) {
        rig.eyeOpen = rig.eyeOpen.clamped(0, 1)
        rig.eyeArc = rig.eyeArc.clamped(0, 1)
        rig.eyeSquint = rig.eyeSquint.clamped(0, 1)
        rig.lying = rig.lying.clamped(0, 1)
        rig.earLift = rig.earLift.clamped(0, 1)
        rig.tailLift = rig.tailLift.clamped(0, 1)
        rig.mouthCurve = rig.mouthCurve.clamped(-1, 1)
        rig.mouthOpen = rig.mouthOpen.clamped(0, 1)
        rig.mouthWobble = rig.mouthWobble.clamped(0, 1)
        rig.tongue = rig.tongue.clamped(0, 1)
        rig.blush = rig.blush.clamped(0, 1)
        rig.sweat = rig.sweat.clamped(0, 1)
        rig.lidHeaviness = rig.lidHeaviness.clamped(0, 1)
        rig.browInnerUp = rig.browInnerUp.clamped(-1, 1)
        rig.browWeight = rig.browWeight.clamped(0, 1)
        rig.headDrop = rig.headDrop.clamped(0, 1)
        rig.armRaise = rig.armRaise.clamped(0, 1)
        rig.armCross = rig.armCross.clamped(0, 1)
        rig.armOut = rig.armOut.clamped(0, 1)
        rig.headTurn = rig.headTurn.clamped(-1, 1)
    }
}

extension Double {
    func clamped(_ lower: Double, _ upper: Double) -> Double { Swift.min(Swift.max(self, lower), upper) }
}
