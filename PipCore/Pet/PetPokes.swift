import Foundation

/// What a tap does depends on what the pet is doing, and it never does the same thing twice in a
/// row: a sleeping pet opens one grumpy eye, a working one looks up and waves, a sad one leans
/// into your finger, a happy one giggles, winks or hops. The variation is chosen when you tap and
/// travels with the event, so the phone and the watch play the same one.
public enum PetPokes {
    /// The kind of answer a stance gives.
    public enum Group: String, Sendable {
        case asleep, sleepy, sad, stressed, frustrated, calm, meditating, working, reading, playful, neutral
    }

    public static func group(for stance: PetStance) -> Group {
        switch stance {
        case .life(.sleeping), .life(.napping): return .asleep
        case .life(.waking), .life(.windingDown), .busy(.windingDown, _, _), .mood(.tired, _): return .sleepy
        case .mood(.sad, _): return .sad
        case .mood(.stressed, _): return .stressed
        case .mood(.frustrated, _): return .frustrated
        case .mood(.calm, _): return .calm
        case .meditating: return .meditating
        case .life(.working), .busy(.working, _, _): return .working
        case .life(.reading), .busy(.reading, _, _): return .reading
        case .mood(.happy, _), .mood(.excited, _), .life(.playing), .busy(_, .happy, _), .busy(_, .excited, _): return .playful
        default: return .neutral
        }
    }

    /// How many variations a tap has for this stance (head and body taps share them, except that
    /// a playful or neutral pet giggles when tickled).
    public static func count(for stance: PetStance, onHead: Bool) -> Int {
        clips(group(for: stance), onHead: onHead, .penguin).count
    }

    /// The clip for a tap. `variant` is taken modulo the count; `wokenUp` is a sleeping pet tapped
    /// again and again: it wakes, pouts and flops back to sleep.
    public static func clip(for stance: PetStance, species s: PetSpecies, onHead: Bool, variant: Int) -> PetClip {
        if variant < 0 { return wokenUp(s) }
        let list = clips(group(for: stance), onHead: onHead, s)
        return list[((variant % list.count) + list.count) % list.count]
    }

    static func clips(_ g: Group, onHead: Bool, _ s: PetSpecies) -> [PetClip] {
        switch g {
        case .asleep: [grumpyPeek(s), rollOver(s), sleepTalk(s)]
        case .sleepy: [drowsyNuzzle(s), yawnSmile(s), PetClips.vignette(.rubEye, s)]
        case .sad: [leanIn(s), reachUp(s), lookUpSmile(s)]
        case .stressed: [startleExhale(s), smallSmile(s), leanIn(s)]
        case .frustrated: [hmph(s), grumble(s), smallSmile(s)]
        case .calm: [slowBlinkLove(s), contentSway(s), leanIn(s)]
        case .meditating: [oneEyeOpen(s)]
        case .working: [lookUpWave(s), noticeYou(s), PetClips.wave(s)]
        case .reading: [peekOver(s), noticeYou(s)]
        case .playful: onHead ? [PetClips.boop(s), wink(s), hopSpin(s), surprisedLaugh(s), heartEyes(s)]
            : [PetClips.tickle(s), hopSpin(s), surprisedLaugh(s), heartEyes(s)]
        case .neutral: onHead ? [PetClips.boop(s), curiousTilt(s), wink(s), PetClips.wave(s)]
            : [PetClips.tickle(s), curiousTilt(s), PetClips.wave(s)]
        }
    }

    // MARK: Asleep

    /// One eye opens, brow down, cheeks puffed, a tiny puff of steam: "I was sleeping." Then it closes again.
    static func grumpyPeek(_ s: PetSpecies) -> PetClip {
        PetClip("poke.grumpyPeek", 2.6, fadeIn: 0.1, fadeOut: 0.5, [
            set(\.lidR, K(0, 1), K(0.35, 1), K(0.55, 0.4, .out), K(1.6, 0.4), K(1.9, 1), K(2.6, 1)),
            add(\.zzz, K(0, 0), K(0.3, -0.8), K(2.0, -0.8), K(2.5, 0)),
            bump(\.browShow, 0.9, from: 0.35, peak: 0.55, hold: 1.6, end: 1.9),
            bump(\.browSlant, 0.8, from: 0.35, peak: 0.55, hold: 1.6, end: 1.9),
            set(\.gazeX, K(0, 0), K(0.55, 0.3), K(1.6, 0.3), K(1.9, 0)),
            bump(\.cheekPuff, 0.8, from: 0.6, peak: 0.8, hold: 1.3, end: 1.6),
            bump(\.steam, 0.6, from: 0.7, peak: 0.9, hold: 1.2, end: 1.5),
            bump(\.smile, -0.35, from: 0.4, peak: 0.6, hold: 1.5, end: 1.9),
            bump(\.headTilt, 5, from: 1.7, peak: 2.1, end: 2.6),
        ])
    }

    /// Grumbles and rolls its head over to the other side, still asleep.
    static func rollOver(_ s: PetSpecies) -> PetClip {
        PetClip("poke.rollOver", 2.6, fadeIn: 0.1, fadeOut: 0.5, [
            add(\.headTilt, K(0, 0), K(0.8, 22), K(2.0, 22), K(2.6, 0)),
            osc(\.lean, from: 0.1, to: 0.9, amp: 3, cycles: 2),
            osc(\.mouthOpen, from: 0.2, to: 0.9, center: 0.15, amp: 0.12, cycles: 3),
            bump(\.browShow, 0.6, from: 0.1, peak: 0.3, hold: 0.8, end: 1.1),
            bump(\.browSlant, 0.5, from: 0.1, peak: 0.3, hold: 0.8, end: 1.1),
            bump(\.smile, 0.3, from: 1.1, peak: 1.5, hold: 2.1, end: 2.6),
            add(\.earL, K(0, 0), K(0.2, -0.4), K(0.5, 0), K(2.6, 0)),
        ])
    }

    /// Mumbles something in its sleep with a dreamy smile.
    static func sleepTalk(_ s: PetSpecies) -> PetClip {
        PetClip("poke.sleepTalk", 2.4, fadeIn: 0.1, fadeOut: 0.5, [
            osc(\.mouthOpen, from: 0.2, to: 1.4, center: 0.15, amp: 0.13, cycles: 4),
            bump(\.mouthRound, 0.6, from: 0.2, peak: 0.4, hold: 1.3, end: 1.5),
            bump(\.smile, 0.5, from: 1.2, peak: 1.5, hold: 2.0, end: 2.4),
            bump(\.blush, 0.5, from: 1.2, peak: 1.5, hold: 2.0, end: 2.4),
            add(\.earR, K(0, 0), K(0.15, -0.5), K(0.35, 0), K(2.4, 0)),
            bump(\.headNod, -0.1, from: 0.2, peak: 0.5, hold: 1.4, end: 1.8),
        ])
    }

    /// Tapped awake: both eyes half open, arms folded, a pout and a puff of steam, then it flops
    /// straight back to sleep.
    static func wokenUp(_ s: PetSpecies) -> PetClip {
        PetClip("poke.wokenUp", 3.4, fadeIn: 0.05, fadeOut: 0.6, [
            set(\.lidL, K(0, 1), K(0.3, 0.35, .out), K(2.3, 0.35), K(2.8, 1), K(3.4, 1)),
            set(\.lidR, K(0, 1), K(0.3, 0.35, .out), K(2.3, 0.35), K(2.8, 1), K(3.4, 1)),
            add(\.zzz, K(0, 0), K(0.2, -0.8), K(2.8, -0.8), K(3.3, 0)),
            bump(\.lift, 4, from: 0, peak: 0.12, end: 0.35),
            bump(\.eyeWide, 0.2, from: 0, peak: 0.15, end: 0.5),
            bump(\.browShow, 1, from: 0.4, peak: 0.6, hold: 2.3, end: 2.6),
            bump(\.browSlant, 0.9, from: 0.4, peak: 0.6, hold: 2.3, end: 2.6),
            set(\.armL, K(0, 0), K(0.5, -62), K(2.3, -62), K(2.8, 0)), set(\.armR, K(0, 0), K(0.5, -62), K(2.3, -62), K(2.8, 0)),
            bump(\.cheekPuff, 1, from: 0.6, peak: 0.8, hold: 1.8, end: 2.1),
            bump(\.steam, 1, from: 0.7, peak: 0.9, hold: 1.8, end: 2.2),
            bump(\.smile, -0.5, from: 0.4, peak: 0.6, hold: 2.2, end: 2.6),
            add(\.headTurn, K(0, 0), K(0.8, 0), K(1.0, -0.5), K(2.0, -0.5), K(2.3, 0), K(3.4, 0)),
            bump(\.slump, 0.3, from: 2.3, peak: 2.7, end: 3.3),
            bump(\.squash, 0.12, from: 2.4, peak: 2.6, end: 3.0),
        ])
    }

    // MARK: Sleepy

    static func drowsyNuzzle(_ s: PetSpecies) -> PetClip {
        PetClip("poke.drowsyNuzzle", 2.4, fadeIn: 0.15, fadeOut: 0.5, [
            bump(\.headTilt, 13, from: 0, peak: 0.6, hold: 1.8, end: 2.4),
            bump(\.lean, 4, from: 0, peak: 0.6, hold: 1.8, end: 2.4),
            set(\.lidL, K(0, 0.5), K(0.5, 0.85), K(1.9, 0.85), K(2.4, 0.5)),
            set(\.lidR, K(0, 0.5), K(0.5, 0.85), K(1.9, 0.85), K(2.4, 0.5)),
            bump(\.smile, 0.45, from: 0.2, peak: 0.6, hold: 1.9, end: 2.4),
            bump(\.blush, 0.5, from: 0.2, peak: 0.6, hold: 1.9, end: 2.4),
        ])
    }

    static func yawnSmile(_ s: PetSpecies) -> PetClip {
        PetClip("poke.yawnSmile", 2.6, fadeIn: 0.1, fadeOut: 0.5, [
            set(\.mouthOpen, K(0, 0), K(0.5, 0.9), K(1.2, 0.9), K(1.5, 0), K(2.6, 0)),
            set(\.mouthRound, K(0, 0), K(0.5, 0.7), K(1.2, 0.7), K(1.5, 0), K(2.6, 0)),
            set(\.lidL, K(0, 0.5), K(0.5, 1), K(1.3, 1), K(1.7, 0.6), K(2.6, 0.5)),
            set(\.lidR, K(0, 0.5), K(0.5, 1), K(1.3, 1), K(1.7, 0.6), K(2.6, 0.5)),
            bump(\.headNod, -0.3, from: 0.1, peak: 0.5, hold: 1.2, end: 1.6),
            bump(\.smile, 0.45, from: 1.4, peak: 1.7, hold: 2.2, end: 2.6),
            bump(\.smileEyes, 0.5, from: 1.4, peak: 1.7, hold: 2.2, end: 2.6),
        ])
    }

    // MARK: Hard feelings: comfort, not giggles

    /// Leans into your finger and looks up with a small, brave smile.
    static func leanIn(_ s: PetSpecies) -> PetClip {
        PetClip("poke.leanIn", 2.8, fadeIn: 0.2, fadeOut: 0.6, [
            bump(\.lean, 6, from: 0, peak: 0.7, hold: 2.0, end: 2.8),
            bump(\.headTilt, 12, from: 0, peak: 0.7, hold: 2.0, end: 2.8),
            set(\.gazeX, K(0, 0), K(0.5, 0), K(2.8, 0)), set(\.gazeY, K(0, 0), K(0.5, -0.2), K(2.2, -0.2), K(2.8, 0)),
            bump(\.lidSlant, 0.4, from: 0.3, peak: 0.8, hold: 2.1, end: 2.7),
            bump(\.smile, 0.45, from: 0.4, peak: 0.9, hold: 2.1, end: 2.7),
            bump(\.blush, 0.35, from: 0.4, peak: 0.9, hold: 2.1, end: 2.7),
            bump(\.hearts, 0.35, from: 1.0, peak: 1.4, hold: 2.0, end: 2.6),
        ])
    }

    /// Reaches a paw up toward your finger.
    static func reachUp(_ s: PetSpecies) -> PetClip {
        PetClip("poke.reachUp", 2.8, fadeIn: 0.15, fadeOut: 0.6, [
            add(\.armR, K(0, 0), K(0.5, 190, .out), K(1.9, 180), K(2.5, 0)),
            set(\.gazeX, K(0, 0), K(0.4, 0.35), K(2.2, 0.35), K(2.8, 0)), set(\.gazeY, K(0, 0), K(0.4, -0.5), K(2.2, -0.5), K(2.8, 0)),
            bump(\.headTilt, 8, from: 0.2, peak: 0.6, hold: 2.0, end: 2.6),
            bump(\.lidSlant, 0.35, from: 0.3, peak: 0.8, hold: 2.0, end: 2.6),
            bump(\.smile, 0.4, from: 0.6, peak: 1.0, hold: 2.1, end: 2.7),
        ])
    }

    static func lookUpSmile(_ s: PetSpecies) -> PetClip {
        var c = PetClips.vignette(.lookUpSmile, s)
        c.name = "poke.lookUpSmile"
        return c
    }

    /// Startled for a blink, then one long, slow breath out.
    static func startleExhale(_ s: PetSpecies) -> PetClip {
        PetClip("poke.startleExhale", 3.0, fadeIn: 0.03, fadeOut: 0.6, [
            bump(\.eyeWide, 0.3, from: 0, peak: 0.1, hold: 0.3, end: 0.6),
            bump(\.lift, 3, from: 0, peak: 0.1, end: 0.3),
            bump(\.exclaim, 0.8, from: 0.05, peak: 0.15, hold: 0.5, end: 0.8),
            bump(\.breath, 1.1, from: 0.9, peak: 1.4, hold: 1.6, end: 2.6),
            bump(\.lidL, 0.9, from: 1.1, peak: 1.5, hold: 2.2, end: 2.6), bump(\.lidR, 0.9, from: 1.1, peak: 1.5, hold: 2.2, end: 2.6),
            bump(\.sweat, -0.5, from: 1.2, peak: 1.8, hold: 2.4, end: 2.9),
            bump(\.smile, 0.4, from: 1.6, peak: 2.0, hold: 2.5, end: 2.9),
        ])
    }

    /// Looks at you and manages a small smile.
    static func smallSmile(_ s: PetSpecies) -> PetClip {
        PetClip("poke.smallSmile", 2.2, fadeIn: 0.15, fadeOut: 0.5, [
            set(\.gazeX, K(0, 0), K(0.3, 0), K(2.2, 0)), set(\.gazeY, K(0, 0), K(0.3, -0.1), K(1.8, -0.1), K(2.2, 0)),
            bump(\.smile, 0.5, from: 0.2, peak: 0.6, hold: 1.7, end: 2.2),
            bump(\.browSlant, 0.3, from: 0.2, peak: 0.6, hold: 1.7, end: 2.2),
            bump(\.headTilt, 7, from: 0.1, peak: 0.5, hold: 1.7, end: 2.2),
            bump(\.cheekPuff, -0.5, from: 0.1, peak: 0.4, hold: 1.7, end: 2.1),
        ])
    }

    /// "Hmph!": turns away with puffed cheeks and a little steam, then peeks back, softened.
    static func hmph(_ s: PetSpecies) -> PetClip {
        PetClip("poke.hmph", 2.9, fadeIn: 0.05, fadeOut: 0.6, [
            add(\.headTurn, K(0, 0), K(0.25, -0.7, .out), K(1.4, -0.7), K(1.8, 0.05), K(2.9, 0)),
            set(\.gazeX, K(0, 0), K(0.25, -1), K(1.3, -1), K(1.5, 0.7), K(2.3, 0.3), K(2.9, 0)),
            bump(\.cheekPuff, 1, from: 0.1, peak: 0.3, hold: 1.3, end: 1.6),
            bump(\.steam, 1, from: 0.2, peak: 0.4, hold: 1.1, end: 1.5),
            bump(\.headTilt, -8, from: 0.1, peak: 0.3, hold: 1.3, end: 1.7),
            bump(\.smile, 0.55, from: 1.6, peak: 1.9, hold: 2.4, end: 2.9),
            bump(\.lidSlant, -0.5, from: 1.6, peak: 1.9, hold: 2.4, end: 2.9),
            bump(\.blush, 0.4, from: 1.6, peak: 1.9, hold: 2.4, end: 2.9),
        ])
    }

    /// A grumbly little stomp, then it lets it go.
    static func grumble(_ s: PetSpecies) -> PetClip {
        PetClip("poke.grumble", 2.4, fadeIn: 0.05, fadeOut: 0.5, [
            add(\.stepL, K(0, 0), K(0.15, 7), K(0.3, 0), K(0.55, 0), K(0.7, 7), K(0.85, 0), K(2.4, 0)),
            add(\.stepR, K(0, 0), K(0.3, 0), K(0.45, 7), K(0.6, 0), K(0.85, 0), K(1.0, 7), K(1.15, 0), K(2.4, 0)),
            osc(\.mouthOpen, from: 0, to: 1.2, center: 0.2, amp: 0.15, cycles: 4),
            bump(\.browShow, 0.5, from: 0, peak: 0.2, hold: 1.1, end: 1.4),
            bump(\.breath, 1, from: 1.2, peak: 1.6, end: 2.1),
            bump(\.smile, 0.45, from: 1.5, peak: 1.8, hold: 2.1, end: 2.4),
        ])
    }

    // MARK: Calm and meditating

    static func slowBlinkLove(_ s: PetSpecies) -> PetClip {
        PetClip("poke.slowBlinkLove", 2.6, fadeIn: 0.15, fadeOut: 0.6, [
            set(\.lidL, K(0, 0.35), K(0.4, 1), K(1.2, 1), K(1.6, 0.35), K(2.6, 0.35)),
            set(\.lidR, K(0, 0.35), K(0.4, 1), K(1.2, 1), K(1.6, 0.35), K(2.6, 0.35)),
            bump(\.smile, 0.5, from: 0.2, peak: 0.6, hold: 2.0, end: 2.6),
            bump(\.blush, 0.5, from: 0.2, peak: 0.6, hold: 2.0, end: 2.6),
            bump(\.headTilt, 8, from: 0.1, peak: 0.6, hold: 2.0, end: 2.6),
            bump(\.hearts, 0.6, from: 1.0, peak: 1.4, hold: 2.0, end: 2.5),
        ])
    }

    static func contentSway(_ s: PetSpecies) -> PetClip {
        PetClip("poke.contentSway", 2.6, fadeIn: 0.2, fadeOut: 0.5, [
            osc(\.headTilt, from: 0, to: 2.5, amp: 7, cycles: 2),
            osc(\.lean, from: 0, to: 2.5, amp: 3, cycles: 2),
            bump(\.smileEyes, 0.8, from: 0.1, peak: 0.4, hold: 2.1, end: 2.5),
            bump(\.smile, 0.4, from: 0.1, peak: 0.4, hold: 2.1, end: 2.5),
            bump(\.notes, 0.6, from: 0.3, peak: 0.7, hold: 2.0, end: 2.5),
        ])
    }

    /// Meditating: one eye opens, it smiles at you, and goes back to breathing.
    static func oneEyeOpen(_ s: PetSpecies) -> PetClip {
        PetClip("poke.oneEyeOpen", 2.4, fadeIn: 0.1, fadeOut: 0.5, [
            set(\.lidR, K(0, 1), K(0.3, 1), K(0.5, 0.35, .out), K(1.6, 0.35), K(1.9, 1), K(2.4, 1)),
            set(\.gazeX, K(0, 0), K(0.5, 0.2), K(1.6, 0.2), K(1.9, 0)),
            bump(\.smile, 0.35, from: 0.4, peak: 0.7, hold: 1.8, end: 2.3),
            bump(\.blush, 0.35, from: 0.4, peak: 0.7, hold: 1.8, end: 2.3),
        ])
    }

    // MARK: Busy

    /// Looks up from the laptop, a quick wave, back to work.
    static func lookUpWave(_ s: PetSpecies) -> PetClip {
        PetClip("poke.lookUpWave", 2.6, fadeIn: 0.1, fadeOut: 0.5, [
            set(\.gazeY, K(0, 0.45), K(0.3, -0.1), K(1.9, -0.1), K(2.3, 0.45), K(2.6, 0.45)),
            set(\.gazeX, K(0, 0), K(0.3, 0), K(2.6, 0)),
            bump(\.headNod, -0.25, from: 0, peak: 0.3, hold: 1.9, end: 2.3),
            add(\.armR, K(0, 0), K(0.4, 150, .out), K(0.65, 125), K(0.9, 150), K(1.15, 125), K(1.4, 145), K(1.9, 0)),
            bump(\.smile, 0.5, from: 0.2, peak: 0.5, hold: 1.9, end: 2.3),
            bump(\.smileEyes, 0.5, from: 0.2, peak: 0.5, hold: 1.9, end: 2.3),
        ])
    }

    /// Notices you: brows up, a little "!", a smile, then back to it.
    static func noticeYou(_ s: PetSpecies) -> PetClip {
        PetClip("poke.noticeYou", 2.2, fadeIn: 0.05, fadeOut: 0.5, [
            set(\.gazeY, K(0, 0.5), K(0.2, -0.1), K(1.6, -0.1), K(2.0, 0.5), K(2.2, 0.5)),
            set(\.gazeX, K(0, 0), K(0.2, 0), K(2.2, 0)),
            bump(\.browRaise, 0.8, from: 0, peak: 0.15, hold: 0.8, end: 1.1),
            bump(\.eyeWide, 0.2, from: 0, peak: 0.15, hold: 0.5, end: 0.8),
            bump(\.exclaim, 0.8, from: 0, peak: 0.15, hold: 0.6, end: 0.9),
            bump(\.headNod, -0.3, from: 0, peak: 0.2, hold: 1.6, end: 2.0),
            bump(\.smile, 0.5, from: 0.5, peak: 0.8, hold: 1.6, end: 2.1),
        ])
    }

    /// Peeks over the top of the book and winks.
    static func peekOver(_ s: PetSpecies) -> PetClip {
        PetClip("poke.peekOver", 2.6, fadeIn: 0.1, fadeOut: 0.5, [
            bump(\.headNod, -0.4, from: 0, peak: 0.35, hold: 1.9, end: 2.4),
            set(\.gazeY, K(0, 0.85), K(0.35, -0.1), K(1.9, -0.1), K(2.4, 0.85), K(2.6, 0.85)),
            set(\.gazeX, K(0, 0.3), K(0.35, 0), K(1.9, 0), K(2.4, 0.3), K(2.6, 0.3)),
            bump(\.browRaise, 0.7, from: 0.1, peak: 0.4, hold: 1.0, end: 1.3),
            set(\.lidL, K(0, 0.25), K(0.9, 0.25), K(1.05, 1), K(1.35, 1), K(1.5, 0.25), K(2.6, 0.25)),
            bump(\.smile, 0.55, from: 0.4, peak: 0.8, hold: 1.9, end: 2.4),
        ])
    }

    // MARK: Playful and neutral

    static func wink(_ s: PetSpecies) -> PetClip {
        PetClip("poke.wink", 1.6, fadeIn: 0.05, fadeOut: 0.4, [
            set(\.lidR, K(0, 0), K(0.2, 1), K(0.8, 1), K(1.0, 0), K(1.6, 0)),
            bump(\.smile, 0.7, from: 0, peak: 0.2, hold: 1.1, end: 1.5),
            bump(\.headTilt, 10, from: 0, peak: 0.25, hold: 1.1, end: 1.5),
            bump(\.blush, 0.6, from: 0, peak: 0.2, hold: 1.1, end: 1.5),
            bump(\.sparkles, 0.6, from: 0.15, peak: 0.35, hold: 0.9, end: 1.3),
        ])
    }

    /// A happy hop with both paws up.
    static func hopSpin(_ s: PetSpecies) -> PetClip {
        PetClip("poke.hop", 1.5, fadeIn: 0.03, fadeOut: 0.3, [
            add(\.squash, K(0, 0), K(0.12, 0.2), K(0.3, -0.2), K(0.55, 0.12), K(0.75, 0), K(1.5, 0)),
            add(\.lift, K(0, 0), K(0.12, 0), K(0.35, 12, .out), K(0.55, 0, .in), K(1.5, 0)),
            add(\.armL, K(0, 0), K(0.15, 140, .out), K(0.7, 130), K(1.1, 0)), add(\.armR, K(0, 0), K(0.15, 140, .out), K(0.7, 130), K(1.1, 0)),
            set(\.smileEyes, K(0, 0), K(0.15, 1), K(1.1, 1), K(1.5, 0.3)),
            bump(\.mouthOpen, 0.7, from: 0.1, peak: 0.25, hold: 0.9, end: 1.2),
            bump(\.sparkles, 0.9, from: 0.2, peak: 0.4, hold: 1.0, end: 1.4),
            osc(\.tail, from: 0, to: 1.4, amp: 1, cycles: s == .dog ? 6 : 2),
        ])
    }

    /// "Oh!" and then a laugh.
    static func surprisedLaugh(_ s: PetSpecies) -> PetClip {
        PetClip("poke.surprisedLaugh", 2.0, fadeIn: 0.03, fadeOut: 0.4, [
            bump(\.eyeWide, 0.3, from: 0, peak: 0.08, hold: 0.35, end: 0.5),
            bump(\.exclaim, 0.9, from: 0, peak: 0.08, hold: 0.4, end: 0.6),
            bump(\.mouthRound, 1, from: 0, peak: 0.08, hold: 0.35, end: 0.5),
            bump(\.mouthOpen, 0.5, from: 0, peak: 0.08, hold: 0.35, end: 0.5),
            set(\.smileEyes, K(0, 0), K(0.45, 0), K(0.6, 1), K(1.6, 1), K(2.0, 0.3)),
            osc(\.mouthOpen, from: 0.55, to: 1.6, center: 0.55, amp: 0.25, cycles: 4),
            osc(\.lift, from: 0.55, to: 1.6, center: 1.5, amp: 1.5, cycles: 4),
            bump(\.blush, 0.8, from: 0.5, peak: 0.7, hold: 1.6, end: 2.0),
        ])
    }

    static func heartEyes(_ s: PetSpecies) -> PetClip {
        PetClip("poke.heartEyes", 2.0, fadeIn: 0.05, fadeOut: 0.5, [
            set(\.smileEyes, K(0, 0), K(0.15, 1), K(1.6, 1), K(2.0, 0.3)),
            bump(\.hearts, 1, from: 0.1, peak: 0.3, hold: 1.4, end: 1.9),
            bump(\.blush, 1, from: 0, peak: 0.2, hold: 1.5, end: 2.0),
            bump(\.headTilt, 12, from: 0, peak: 0.3, hold: 1.4, end: 1.9),
            bump(\.smile, 0.6, from: 0, peak: 0.2, hold: 1.5, end: 2.0),
            osc(\.tail, from: 0, to: 1.8, amp: 1, cycles: s == .dog ? 7 : 3),
        ])
    }

    /// Head right over, a "?", ears up.
    static func curiousTilt(_ s: PetSpecies) -> PetClip {
        var c = PetClips.vignette(.curious, s)
        c.name = "poke.curious"
        return c
    }
}
