import Foundation

/// What the pet gets up to when no mood is fresh (Bible §4, "the pet's day").
public enum PetActivity: String, Codable, CaseIterable, Sendable {
    case sleeping, waking, daydreaming, playing, reading, napping, windingDown, working

    /// "Pebble is …" — always matches what the pet is visibly doing.
    public var phrase: String {
        switch self {
        case .sleeping: "is fast asleep"
        case .waking: "is waking up slowly"
        case .daydreaming: "is daydreaming"
        case .playing: "is playing with a ball"
        case .reading: "is reading"
        case .napping: "is having a little nap"
        case .windingDown: "is winding down with some cocoa"
        case .working: "is working alongside you"
        }
    }
}

/// What the pet is being: company in a mood you logged, getting on with its day, or sitting
/// with you. A stance is a resting pose, what it holds, how it idles and what it does now and then.
public enum PetStance: Codable, Hashable, Sendable {
    case mood(Mood, MoodIntensity)
    case life(PetActivity)
    /// Getting on with something in a mood you logged — only ever a good or neutral one (you
    /// never see a cheerful pet at work after telling it you're sad; see `PetSnapshot.stance`).
    case busy(PetActivity, Mood, MoodIntensity)
    /// Sit With Pet: eyes closed, breathing with you.
    case meditating

    /// The activity underneath, for `life` and `busy`.
    public var activity: PetActivity? {
        switch self {
        case .life(let a), .busy(let a, _, _): a
        default: nil
        }
    }

    public var isAsleep: Bool {
        switch self {
        case .life(.sleeping), .life(.napping): true
        default: false
        }
    }

    /// 0 (still) … 1 (bouncing). Sets idle tempo and greeting size.
    public var energy: Double {
        switch self {
        case .mood(let m, _): m.energy
        case .life(let a):
            switch a {
            case .sleeping, .napping: 0.05
            case .waking, .windingDown: 0.2
            case .reading, .daydreaming: 0.3
            case .playing: 0.7
            case .working: 0.35
            }
        case .busy(let a, let m, _): max(PetStance.life(a).energy, m.energy * 0.6)
        case .meditating: 0.1
        }
    }

    public var prop: PetProp? {
        switch self {
        case .mood(let m, _):
            switch m {
            case .calm: .mug
            case .tired, .sad: .blanket
            default: nil
            }
        case .life(let a):
            switch a {
            case .sleeping: .blanket
            case .reading: .book
            case .playing: .ball
            case .windingDown: .mug
            case .working: .laptop
            default: nil
            }
        case .busy(let a, _, _): PetStance.life(a).prop
        case .meditating: nil
        }
    }

    /// How the pet is described right now. Used by the status line and VoiceOver, so words and
    /// picture always agree.
    public func describe(_ name: String) -> String {
        switch self {
        case .mood(let m, _):
            switch m {
            case .happy: "\(name) is happy for you"
            case .excited: "\(name) is buzzing with you"
            case .calm: "\(name) is sipping something warm with you"
            case .neutral: "\(name) is right here"
            case .tired: "\(name) is tucked in with you"
            case .stressed: "\(name) is taking slow breaths with you"
            case .sad: "\(name) is sitting close"
            case .frustrated: "\(name) is huffing along with you"
            }
        case .life(let a): "\(name) \(a.phrase)"
        case .busy(let a, let m, _):
            switch (a, m) {
            case (.working, .happy): "\(name) is working, humming along"
            case (.working, .excited): "\(name) is typing at top speed"
            case (.working, .calm): "\(name) is working quietly beside you"
            case (.working, _): "\(name) is working alongside you"
            case (.windingDown, _): "\(name) is getting ready for bed"
            default: "\(name) \(a.phrase)"
            }
        case .meditating: "\(name) is breathing with you"
        }
    }

    /// The same without the subject — "Reading", "Sitting close" — for where the name is shown.
    public func phrase(_ name: String) -> String {
        let line = describe(name)
        let prefix = name + " is "
        guard line.hasPrefix(prefix) else { return line }
        let rest = line.dropFirst(prefix.count)
        return rest.prefix(1).uppercased() + rest.dropFirst()
    }

    // MARK: Pose

    /// The resting pose. Intensity scales how far the mood departs from neutral.
    public func rest(_ s: PetSpecies) -> PetPose {
        var p = PetPose()
        p.headTilt = 3
        switch self {
        case .mood(let m, let intensity):
            let d = Self.moodDelta(m, s)
            p = p.adding(d, weight: intensity.scale)
            // Props need the same grip whatever the intensity.
            if let arms = Self.grip(for: prop, mood: m) { p.armL = arms; p.armR = arms }
        case .life(let a):
            p = p.adding(Self.lifeDelta(a, s))
        case .busy(let a, let m, let intensity):
            // The activity's body with the mood's face: how it feels while it does the thing.
            p = p.adding(Self.lifeDelta(a, s))
            let face = Self.moodDelta(m, s)
            for k in [\PetPose.smile, \.smileEyes, \.blush, \.lidSlant, \.eyeWide, \.browShow, \.browSlant, \.earL, \.earR, \.tailUp] {
                p[keyPath: k] += face[keyPath: k] * intensity.scale * 0.8
            }
            if m == .calm { p.lidL = max(p.lidL, 0.3); p.lidR = max(p.lidR, 0.3) }
        case .meditating:
            // Cross-legged, paws resting on the knees, eyes closed, a small smile.
            p.lidL = 1; p.lidR = 1; p.smile = 0.3; p.armL = 8; p.armR = 8; p.headTilt = 0
            p.earL = 0.1; p.earR = 0.1; p.crossLegs = 1
        }
        return p
    }

    static func grip(for prop: PetProp?, mood: Mood) -> Double? {
        switch prop {
        case .mug: -57
        case .blanket: -36
        default: nil
        }
    }

    static func moodDelta(_ m: Mood, _ s: PetSpecies) -> PetPose {
        var p = PetPose()
        switch m {
        case .happy:
            p.smile = 0.7; p.smileEyes = 0.6; p.blush = 0.6; p.earL = 0.4; p.earR = 0.4; p.tailUp = 0.5
            p.headTilt = 6; p.armL = 22; p.armR = 22
        case .excited:
            p.smile = 0.9; p.mouthOpen = 0.5; p.eyeWide = 0.18; p.earL = 0.9; p.earR = 0.9; p.tailUp = 1
            p.armL = 55; p.armR = 55; p.squash = -0.12; p.blush = 0.45; p.headNod = -0.15; p.smileEyes = 0.25
        case .calm:
            p.smile = 0.35; p.lidL = 0.35; p.lidR = 0.35; p.smileEyes = 0.2; p.slump = 0.1; p.headTilt = 3; p.blush = 0.15
        case .neutral:
            p.earL = 0.3; p.earR = 0.3; p.smile = 0.1
        case .tired:
            p.lidL = 0.55; p.lidR = 0.55; p.lidSlant = -0.2; p.slump = 0.45; p.headNod = 0.25; p.earL = -0.4; p.earR = -0.4
            p.tailUp = -0.4; p.smile = -0.05; p.headTilt = -3
        case .stressed:
            p.earL = -0.6; p.earR = -0.6; p.lidSlant = -0.35; p.eyeWide = 0.08; p.browShow = 0.8; p.browSlant = -0.7
            p.smile = -0.35; p.armL = -50; p.armR = -50; p.slump = 0.2; p.tailUp = -0.7; p.sweat = 0.5
        case .sad:
            p.lidL = 0.3; p.lidR = 0.3; p.lidSlant = -0.8; p.browShow = 0.9; p.browSlant = -0.9; p.smile = -0.45
            p.slump = 0.5; p.headNod = 0.3; p.earL = -0.8; p.earR = -0.8; p.tailUp = -0.8; p.gazeY = 0.3; p.headTilt = -3
        case .frustrated:
            p.lidL = 0.25; p.lidR = 0.25; p.lidSlant = 0.85; p.browShow = 1; p.browSlant = 0.9; p.smile = -0.4; p.cheekPuff = 0.5
            p.armL = -62; p.armR = -62; p.earL = -0.3; p.earR = -0.3; p.headTurn = -0.22; p.headTilt = -6; p.tailUp = -0.2
        }
        return p
    }

    static func lifeDelta(_ a: PetActivity, _ s: PetSpecies) -> PetPose {
        var p = PetPose()
        switch a {
        case .sleeping:
            p.lidL = 1; p.lidR = 1; p.headNod = 0.5; p.headTilt = -12; p.slump = 0.4; p.zzz = 0.8; p.armL = -40; p.armR = -40
            p.smile = 0.1; p.earL = -0.3; p.earR = -0.3; p.tailUp = -0.5
        case .napping:
            p.lidL = 1; p.lidR = 1; p.headNod = 0.4; p.headTilt = 9; p.slump = 0.3; p.zzz = 0.5; p.smile = 0.15
            p.earL = -0.2; p.earR = -0.2
        case .waking:
            p.lidL = 0.45; p.lidR = 0.45; p.slump = 0.15; p.smile = 0.1; p.earL = -0.1; p.earR = -0.1
        case .daydreaming:
            p.gazeX = 0.45; p.gazeY = -0.6; p.headNod = -0.15; p.headTilt = 9; p.smile = 0.3; p.lidL = 0.15; p.lidR = 0.15
            p.thought = 0.9; p.blush = 0.3
        case .playing:
            p.gazeX = 0.8; p.gazeY = 0.55; p.smile = 0.5; p.smileEyes = 0.2; p.earL = 0.5; p.earR = 0.5; p.tailUp = 0.6
            p.headTurn = 0.25; p.headTilt = 6; p.armR = 12
        case .reading:
            p.armL = -45; p.armR = -45; p.gazeY = 0.85; p.gazeX = 0.3; p.headNod = 0.35; p.lidL = 0.25; p.lidR = 0.25; p.smile = 0.15
        case .windingDown:
            p.armL = -57; p.armR = -57; p.lidL = 0.45; p.lidR = 0.45; p.smile = 0.3; p.slump = 0.15; p.headTilt = 4
        case .working:
            // Paws on the keyboard behind the lid, eyes on the screen.
            p.armL = -22; p.armR = -22; p.gazeY = 0.45; p.headNod = 0.15; p.smile = 0.15; p.lidL = 0.1; p.lidR = 0.1
            p.earL = 0.2; p.earR = 0.2
        }
        return p
    }

    /// Faces for complications and Lock Screen accessories: bold enough to see at 30 pt, and
    /// always true to the stance. They step one per timeline entry (every 5 minutes on the
    /// watch), so each glance at your wrist catches a different little moment.
    public func badgeMoments(_ s: PetSpecies) -> [PetPose] {
        var base = rest(s)
        base.armL = 0; base.armR = 0
        func m(_ f: (inout PetPose) -> Void) -> PetPose { var p = base; f(&p); return p.clamped() }
        let lookLeft = m { $0.headTurn = -0.8; $0.gazeX = -1; $0.headTilt = -6 }
        let lookRight = m { $0.headTurn = 0.8; $0.gazeX = 1; $0.headTilt = 6 }
        let wink = m { $0.lidR = 1; $0.lidL = 0; $0.smile = 0.8; $0.headTilt = 8; $0.blush = 0.6 }
        let beam = m { $0.smileEyes = 1; $0.smile = 1; $0.blush = 0.8 }
        let curious = m { $0.headTilt = 16; $0.question = 1; $0.browRaise = 0.8; $0.eyeWide = 0.15 }
        switch self {
        case .mood(let mood, _):
            switch mood {
            case .happy: return [beam, wink, m { $0.mouthOpen = 0.8; $0.smile = 1; $0.smileEyes = 0.6; $0.sparkles = 1 }, m { $0.headTilt = 14; $0.hearts = 1; $0.smileEyes = 0.7 }]
            case .excited: return [m { $0.mouthOpen = 1; $0.smileEyes = 1; $0.sparkles = 1 }, wink, m { $0.eyeWide = 0.3; $0.mouthOpen = 0.8; $0.exclaim = 1 }, beam]
            case .calm: return [m { $0.lidL = 1; $0.lidR = 1; $0.smile = 0.6; $0.blush = 0.4 }, m { $0.headTilt = 12; $0.smileEyes = 0.6; $0.hearts = 1 }, lookRight, beam]
            case .neutral: return [base, lookLeft, curious, lookRight, m { $0.smileEyes = 0.9; $0.smile = 0.5 }]
            case .tired: return [m { $0.lidL = 1; $0.lidR = 1; $0.mouthOpen = 0.9; $0.mouthRound = 0.8 }, m { $0.lidL = 0.7; $0.lidR = 0.7; $0.headTilt = -12 }, m { $0.lidL = 1; $0.lidR = 1; $0.zzz = 1; $0.headTilt = 10 }]
            case .stressed: return [m { $0.sweat = 1; $0.eyeWide = 0.25 }, m { $0.lidL = 1; $0.lidR = 1; $0.mouthOpen = 0.3; $0.mouthRound = 1; $0.sweat = 0 }, m { $0.smile = 0.2; $0.lidSlant = -0.3; $0.headTilt = 8 }]
            case .sad: return [m { $0.tears = 1 }, m { $0.headNod = -0.3; $0.smile = 0.2; $0.lidSlant = -0.4; $0.headTilt = 8 }, m { $0.lidL = 1; $0.lidR = 1; $0.headTilt = -8 }]
            case .frustrated: return [m { $0.steam = 1; $0.cheekPuff = 1 }, m { $0.mouthOpen = 0.4; $0.mouthRound = 1; $0.steam = 1 }, m { $0.headTurn = -0.8; $0.gazeX = 1; $0.lidL = 0.4; $0.lidR = 0.4 }]
            }
        case .life(let a), .busy(let a, _, _):
            switch a {
            case .sleeping, .napping: return [base, m { $0.headTilt = 14 }, m { $0.lidR = 0.3; $0.headTilt = -8; $0.zzz = 0 }]
            case .waking: return [m { $0.lidL = 1; $0.lidR = 1; $0.mouthOpen = 0.9; $0.mouthRound = 0.8 }, m { $0.lidL = 0.5; $0.lidR = 0.5; $0.headTilt = 10 }, beam]
            case .reading: return [base, m { $0.gazeY = -0.1; $0.smile = 0.5; $0.smileEyes = 0.5 }, m { $0.smileEyes = 1; $0.smile = 0.8 }]
            case .working: return [base, m { $0.gazeY = -0.1; $0.gazeX = 0; $0.smile = 0.4 }, curious]
            case .daydreaming: return [base, m { $0.smileEyes = 0.9; $0.blush = 0.6; $0.hearts = 1 }, lookRight]
            case .playing: return [beam, lookRight, wink, m { $0.mouthOpen = 0.8; $0.smile = 1; $0.sparkles = 1 }]
            case .windingDown: return [m { $0.lidL = 1; $0.lidR = 1; $0.mouthOpen = 0.9; $0.mouthRound = 0.8 }, m { $0.lidL = 0.6; $0.lidR = 0.6; $0.smile = 0.4 }, beam]
            }
        case .meditating:
            return [base]
        }
    }

    /// The mood's face turned up for small tokens (pickers, history, widgets), where the resting
    /// pose is too subtle to tell eight feelings apart at 40 pt. Each one is the peak of its reaction.
    public static func tokenFace(_ m: Mood, _ s: PetSpecies) -> PetPose {
        var p = PetStance.mood(m, .strong).rest(s)
        p.armL = 0; p.armR = 0; p.gazeX = 0; p.gazeY = 0; p.headTurn = 0; p.headNod = 0; p.slump = 0
        switch m {
        case .happy: p.smileEyes = 0.95; p.smile = 0.9; p.blush = 0.8; p.headTilt = 8
        case .excited: p.smileEyes = 1; p.mouthOpen = 0.9; p.smile = 1; p.blush = 0.6; p.sparkles = 0.8; p.eyeWide = 0
        case .calm: p.lidL = 1; p.lidR = 1; p.smile = 0.55; p.blush = 0.3; p.headTilt = 6
        case .neutral: p.smile = 0.1; p.headTilt = 3
        case .tired: p.lidL = 0.7; p.lidR = 0.7; p.mouthOpen = 0.45; p.mouthRound = 0.8; p.headTilt = -8
        case .stressed: p.eyeWide = 0.25; p.browShow = 1; p.browSlant = -0.9; p.sweat = 1; p.smile = -0.5
        case .sad: p.lidSlant = -1; p.browShow = 1; p.browSlant = -1; p.tears = 0.9; p.smile = -0.6; p.lidL = 0.35; p.lidR = 0.35
        case .frustrated: p.lidSlant = 1; p.browShow = 1; p.browSlant = 1; p.cheekPuff = 1; p.smile = -0.5; p.steam = 1; p.headTurn = 0
        }
        return p.clamped()
    }

    // MARK: Behaviour

    /// Idle character: breath tempo and depth, how much it sways, how often it glances.
    struct Idle {
        var breathRate: Double      // breaths per second
        var breathDepth: Double
        var sway: Double            // degrees of lean noise
        var tiltNoise: Double
        var gazeRange: Double
        var blinks: Bool
        var tailWag: Double         // 0 still … 1 fast wag
        var bob: Double             // excited on-its-toes bounce
    }

    var idle: Idle {
        switch self {
        case .mood(let m, _):
            switch m {
            case .happy: Idle(breathRate: 0.3, breathDepth: 0.5, sway: 2.2, tiltNoise: 3, gazeRange: 0.5, blinks: true, tailWag: 0.6, bob: 0)
            case .excited: Idle(breathRate: 0.42, breathDepth: 0.5, sway: 2.5, tiltNoise: 3, gazeRange: 0.6, blinks: true, tailWag: 1, bob: 1)
            case .calm: Idle(breathRate: 0.16, breathDepth: 0.8, sway: 1, tiltNoise: 2, gazeRange: 0.25, blinks: true, tailWag: 0.1, bob: 0)
            case .neutral: Idle(breathRate: 0.24, breathDepth: 0.5, sway: 1.2, tiltNoise: 2.5, gazeRange: 0.55, blinks: true, tailWag: 0.2, bob: 0)
            case .tired: Idle(breathRate: 0.14, breathDepth: 0.7, sway: 1.5, tiltNoise: 3, gazeRange: 0.2, blinks: true, tailWag: 0, bob: 0)
            // Stressed breathes slowly and visibly on purpose: an invitation to breathe along.
            case .stressed: Idle(breathRate: 0.11, breathDepth: 1.1, sway: 0.6, tiltNoise: 1.5, gazeRange: 0.4, blinks: true, tailWag: 0, bob: 0)
            case .sad: Idle(breathRate: 0.15, breathDepth: 0.6, sway: 0.8, tiltNoise: 1.5, gazeRange: 0.2, blinks: true, tailWag: 0, bob: 0)
            case .frustrated: Idle(breathRate: 0.3, breathDepth: 0.7, sway: 0.8, tiltNoise: 1.5, gazeRange: 0.3, blinks: true, tailWag: 0.3, bob: 0)
            }
        case .life(let a):
            switch a {
            case .sleeping, .napping: Idle(breathRate: 0.12, breathDepth: 0.9, sway: 0.5, tiltNoise: 1, gazeRange: 0, blinks: false, tailWag: 0, bob: 0)
            case .waking: Idle(breathRate: 0.18, breathDepth: 0.6, sway: 1.5, tiltNoise: 3, gazeRange: 0.3, blinks: true, tailWag: 0.1, bob: 0)
            case .daydreaming: Idle(breathRate: 0.2, breathDepth: 0.6, sway: 1.5, tiltNoise: 3, gazeRange: 0, blinks: true, tailWag: 0.2, bob: 0)
            case .playing: Idle(breathRate: 0.3, breathDepth: 0.5, sway: 2, tiltNoise: 3, gazeRange: 0, blinks: true, tailWag: 0.8, bob: 0)
            case .reading: Idle(breathRate: 0.2, breathDepth: 0.5, sway: 0.6, tiltNoise: 1.5, gazeRange: 0, blinks: true, tailWag: 0.1, bob: 0)
            case .windingDown: Idle(breathRate: 0.16, breathDepth: 0.7, sway: 1, tiltNoise: 2, gazeRange: 0.2, blinks: true, tailWag: 0, bob: 0)
            case .working: Idle(breathRate: 0.22, breathDepth: 0.5, sway: 0.6, tiltNoise: 1.5, gazeRange: 0, blinks: true, tailWag: 0.15, bob: 0)
            }
        case .busy(let a, let m, let i): Self.busyIdle(a, m, i)
        case .meditating:
            Idle(breathRate: 0.1, breathDepth: 1.1, sway: 0.3, tiltNoise: 0.5, gazeRange: 0, blinks: false, tailWag: 0, bob: 0)
        }
    }

    static func busyIdle(_ a: PetActivity, _ m: Mood, _ i: MoodIntensity) -> Idle {
        var idle = PetStance.life(a).idle
        let mood = PetStance.mood(m, i).idle
        idle.tailWag = max(idle.tailWag, mood.tailWag * 0.7)
        idle.sway = (idle.sway + mood.sway) / 2
        return idle
    }

    /// Seconds between vignette slots. Livelier moods do more; sleep does little.
    var vignetteEvery: Double {
        // Hard feelings get company that is unhurried, however much energy they carry.
        if case .mood(.stressed, _) = self { return 13 }
        if case .mood(.frustrated, _) = self { return 11 }
        return switch energy {
        case ..<0.1: 16
        case ..<0.35: 13
        case ..<0.7: 11
        default: 9
        }
    }

    /// The pet's own business for this stance. The species signature is part of it.
    func repertoire(_ s: PetSpecies) -> [PetVignette] {
        let signature: [PetVignette] = switch s {
        case .penguin: [.flap, .waddle]
        case .cat: [.slowBlink, .groom]
        case .dog: [.tailWag, .headTilt]
        }
        switch self {
        case .mood(let m, _):
            switch m {
            case .happy: return [.hum, .dance, .lookAtYou, .clap, .wiggle] + signature.prefix(1)
            case .excited: return [.bounce, .fistPump, .wiggle, .clap, .dance] + signature.prefix(1)
            case .calm: return [.sip, .lookAtYou, .sigh, .stretch] + (s == .cat ? [.slowBlink] : [])
            case .neutral: return [.lookAround, .curious, .lookAtYou, .stretch] + signature
            case .tired: return [.yawn, .nodOff, .rubEye, .sigh]
            case .stressed: return [.deepBreath, .shakeOff, .fidget, .lookAtYou]
            case .sad: return [.lookUpSmile, .patSpot, .sigh]
            case .frustrated: return [.huff, .stomp, .deepBreath, .shakeOff]
            }
        case .life(let a):
            switch a {
            case .sleeping: return [.snore, .earTwitch, .stir]
            case .napping: return [.snore, .earTwitch, .stir]
            case .waking: return [.stretch, .yawn, .rubEye, .lookAround]
            case .daydreaming: return [.daydream, .sigh, .lookAround, .hum] + signature.prefix(1)
            case .playing: return [.batBall, .wiggle, .bounce] + signature.prefix(1)
            case .reading: return [.pageTurn, .chuckle, .lookAtYou]
            case .windingDown: return [.sip, .yawn, .lookAtYou]
            case .working: return [.typing, .lookAtYou, .stretch, .typing2]
            }
        case .busy(let a, let m, _):
            let base = PetStance.life(a).repertoire(s)
            let flavour: [PetVignette] = switch m {
            case .happy: [.hum]
            case .excited: [.fistPump]
            case .calm: [.sigh]
            default: [.curious]
            }
            return base + flavour
        case .meditating:
            return []
        }
    }

    /// Poses that look right frozen, for widgets, complications and the Live Activity. Entries
    /// cycle through them so a still surface still changes now and then.
    public func holds(_ s: PetSpecies) -> [PetPose] {
        let rest = self.rest(s)
        var look = rest
        look.gazeX = 0; look.gazeY = -0.1; look.smile += 0.25; look.smileEyes += 0.3; look.headTilt += 5
        var aside = rest
        aside.gazeX = -0.6; aside.headTurn -= 0.25; aside.headTilt -= 4
        var tilt = rest
        tilt.headTilt += 11; tilt.earL += 0.4; tilt.earR -= 0.2; tilt.browRaise += 0.4; tilt.gazeX = 0.2
        var other = rest
        other.gazeX = 0.6; other.headTurn += 0.2; other.headTilt += 3; other.tail += 0.5
        switch self {
        case .life(.sleeping), .life(.napping), .meditating:
            var deeper = rest
            deeper.headTilt += 5; deeper.breath = 0.6
            var turned = rest
            turned.headTilt -= 6; turned.smile += 0.15; turned.earL -= 0.2
            return [rest, deeper, turned]
        case .life(.reading):
            var chuckle = rest
            chuckle.smileEyes = 0.7; chuckle.smile = 0.5
            var page = rest
            page.gazeX = -0.5
            return [rest, chuckle, page, look]
        case .life(.working), .busy(.working, _, _):
            var glance = rest
            glance.gazeY = -0.1; glance.gazeX = 0; glance.headNod = 0; glance.smile += 0.25; glance.smileEyes += 0.25
            var thinking = rest
            thinking.headTilt += 8; thinking.gazeY = 0.1; thinking.gazeX = 0.4; thinking.browRaise += 0.4
            return [rest, glance, thinking]
        case .mood(.happy, _), .mood(.excited, _):
            var cheer = rest
            cheer.armR = 130; cheer.smileEyes = 0.8
            return [rest, look, cheer, tilt, other]
        case .mood(.sad, _):
            var up = rest
            up.headNod -= 0.3; up.gazeY = -0.1; up.smile += 0.35; up.lidSlant += 0.3
            var down = rest
            down.headTilt -= 5; down.gazeX = -0.3
            return [rest, up, down]
        default:
            return [rest, look, aside, tilt, other]
        }
    }

}

extension MoodIntensity {
    /// Blend weight of a mood's departure from neutral.
    var weight: Double {
        switch self {
        case .slight: 0.7
        case .moderate: 1
        case .strong: 1.25
        }
    }
}
