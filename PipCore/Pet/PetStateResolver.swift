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
            rig.mouthCurve = 0.85
            rig.mouthOpen = 0.15
            rig.eyeArc = 0.35
            rig.blush = 0.55
            rig.earLift = 0.95
            rig.tailLift = 0.85
            rig.squash = 1.03
            motion.bounceAmount = 2.5
            motion.bounceRate = 1.4
            motion.tailWagRate = 1.2
            motion.tailWagAmount = 0.6
            motion.breathRate = 0.32
            env.tintStrength = 0.5

        case .excited:
            rig.mouthCurve = 1
            rig.mouthOpen = 0.65
            rig.mouthWidth = 1.15
            rig.eyeScale = 1.18
            rig.pupilScale = 1.3
            rig.blush = 0.65
            rig.earLift = 1
            rig.tailLift = 1
            rig.squash = 1.06
            rig.lift = -4
            motion.bounceAmount = 6
            motion.bounceRate = 2.4
            motion.tailWagRate = 2.6
            motion.tailWagAmount = 1
            motion.breathRate = 0.45
            motion.gazeInterval = 1.6
            accessory = .sparkles
            env.tintStrength = 0.6

        case .calm:
            rig.mouthCurve = 0.45
            rig.eyeOpen = 0.78
            rig.lidHeaviness = 0.25
            rig.eyeArc = 0.15
            rig.blush = 0.35
            rig.earLift = 0.7
            rig.tailLift = 0.35
            rig.squash = 0.96
            motion.breathRate = 0.18
            motion.breathAmount = 0.028
            motion.tailWagRate = 0.25
            motion.tailWagAmount = 0.2
            motion.blinkInterval = 5.5
            motion.gazeInterval = 5
            env.tintStrength = 0.35

        case .neutral:
            rig.mouthCurve = 0.3
            rig.blush = 0.25
            rig.earLift = 0.8
            rig.tailLift = 0.5
            motion.tailWagRate = 0.4
            motion.tailWagAmount = 0.25
            env.tintStrength = 0.3

        case .tired:
            rig.mouthCurve = 0.1
            rig.eyeOpen = 0.35
            rig.lidHeaviness = 0.8
            rig.eyeSquint = 0.2
            rig.earLift = 0.35
            rig.tailLift = 0.15
            rig.squash = 0.9
            rig.lying = 0.75
            rig.lift = 6
            rig.blush = 0.2
            rig.gazeY = 0.25
            motion.breathRate = 0.14
            motion.breathAmount = 0.035
            motion.blinkInterval = 2.5
            motion.gazeInterval = 7
            motion.earTwitch = 0.1
            accessory = .zzz
            env.tintStrength = 0.3
            env.dimness = 0.35
            env.shadowSpread = 1.25

        case .stressed:
            rig.mouthCurve = -0.25
            rig.mouthWobble = 0.8
            rig.mouthWidth = 0.85
            rig.eyeScale = 1.08
            rig.pupilScale = 0.7
            rig.browInnerUp = 0.75
            rig.browWeight = 0.9
            rig.earLift = 0.45
            rig.tailLift = 0.25
            rig.squash = 1.02
            rig.sweat = 0.9
            rig.blush = 0.15
            rig.tilt = -3
            motion.jitter = 1.4
            motion.breathRate = 0.55
            motion.breathAmount = 0.016
            motion.blinkInterval = 1.6
            motion.gazeInterval = 0.9
            motion.tailWagRate = 3.2
            motion.tailWagAmount = 0.35
            motion.earTwitch = 0.9
            accessory = .stressLines
            env.tintStrength = 0.45

        case .sad:
            rig.mouthCurve = -0.6
            rig.mouthWidth = 0.8
            rig.eyeOpen = 0.8
            rig.pupilScale = 1.1
            rig.gazeY = 0.35
            rig.browInnerUp = 0.9
            rig.browWeight = 0.8
            rig.earLift = 0.15
            rig.tailLift = 0.05
            rig.squash = 0.9
            rig.lying = 0.2
            rig.lift = 4
            rig.tilt = 4
            rig.blush = 0.1
            motion.breathRate = 0.16
            motion.breathAmount = 0.022
            motion.blinkInterval = 3.2
            motion.gazeInterval = 6
            motion.tailWagRate = 0
            accessory = .rainCloud
            env.tintStrength = 0.35
            env.dimness = 0.25

        case .frustrated:
            rig.mouthCurve = -0.45
            rig.mouthWidth = 0.9
            rig.eyeSquint = 0.55
            rig.browInnerUp = -0.85
            rig.browWeight = 1
            rig.earLift = 0.3
            rig.tailLift = 0.7
            rig.squash = 1.04
            rig.blush = 0.45
            rig.tilt = 2
            motion.jitter = 0.5
            motion.tailWagRate = 2.4
            motion.tailWagAmount = 0.55
            motion.breathRate = 0.5
            motion.breathAmount = 0.03
            motion.blinkInterval = 3
            motion.swayAmount = 1.2
            motion.swayRate = 0.9
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

        state.motion.bounceAmount *= s
        state.motion.jitter *= s
        state.motion.tailWagAmount *= min(s, 1.2)
        state.motion.swayAmount *= s
        state.motion.tailWagRate *= (0.8 + 0.2 * s)

        if intensity == .slight {
            // Slight moods keep their accessory only when it is very characteristic.
            switch state.accessory {
            case .sparkles, .rainCloud, .steam: state.accessory = nil
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
            state.motion.bounceAmount *= 1.2
            state.rig.tilt *= 1.5
            if (mood == .stressed || mood == .sad) && intensity == .strong {
                state.rig.lying = max(state.rig.lying, 0.85)
                state.rig.lift += 6
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
            state.motion.bounceAmount *= 0.6
            state.motion.jitter *= 0.5
            state.motion.breathRate *= 0.85
            state.motion.tailWagRate *= 0.7
            state.rig.mouthOpen *= 0.7
            state.rig.lidHeaviness = max(state.rig.lidHeaviness, 0.15)

        case .chaotic:
            // Big reactions, quick eyes.
            state.motion.bounceAmount *= 1.5
            state.motion.jitter *= 1.5
            state.motion.gazeInterval *= 0.6
            state.rig.eyeScale *= 1.05
            if mood == .excited { state.rig.mouthOpen = 1; state.rig.lift -= 3 }

        case .sleepy:
            // Calm and neutral drift toward a nap.
            if mood == .calm || mood == .neutral {
                state.rig.eyeOpen = min(state.rig.eyeOpen, 0.6)
                state.rig.lidHeaviness = max(state.rig.lidHeaviness, 0.45)
                state.rig.lying = max(state.rig.lying, 0.35)
                if mood == .calm && state.accessory == nil { state.accessory = .zzz }
            }
            state.motion.bounceAmount *= 0.7
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
            // No tail to speak of; flippers use tailLift. Penguins don't blush as much.
            state.rig.blush *= 0.7
        case .capybara:
            state.motion.breathAmount *= 1.2
            state.rig.eyeScale *= 0.9
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
    }
}

extension Double {
    func clamped(_ lower: Double, _ upper: Double) -> Double { Swift.min(Swift.max(self, lower), upper) }
}
