import CoreGraphics
import Foundation

/// Something that happened to the pet, with when it happened. Events are what make the pet
/// answer you; they travel between devices so both play the same reaction.
public struct PetEvent: Codable, Hashable, Sendable {
    public enum Kind: Codable, Hashable, Sendable {
        /// You opened the app or raised your wrist.
        case arrive
        /// You opened the app after a few days away: an extra-happy hello.
        case missedYou
        /// You logged a mood.
        case logged(Mood, MoodIntensity)
        case boop
        case tickle
        case flustered
        /// A petting session just ended.
        case petted
        case wave
        /// It caught a treat.
        case munch
        /// You're writing a note; it leans in and listens.
        case listening
        /// You shook the phone.
        case dizzy
        /// One little hop (chasing the ball).
        case hop
        /// Brought the ball back.
        case proud
        /// You're back after a rough day: a soft hello, no bounce.
        case gentleHello
        /// A tap, answered in keeping with what it is doing (see `PetPokes`); `variant` −1 is a
        /// sleeping pet tapped awake.
        case poke(head: Bool, variant: Int)
        /// Swatted at a bubble, with the paw on that side (screen left when `left`).
        case swat(left: Bool)
    }

    public var kind: Kind
    public var at: Date

    public init(_ kind: Kind, at: Date = .now) {
        self.kind = kind
        self.at = at
    }
}

/// Everything that decides what the pet looks like at a moment (Bible §5).
public struct PetScene: Equatable, Sendable {
    public var species: PetSpecies
    public var stance: PetStance
    /// The stance before the current one, and when the change happened, for the blend.
    public var previous: PetStance?
    public var stanceSince: Date
    /// Recent events. Old ones are ignored once their clip has played.
    public var events: [PetEvent]
    /// A finger has been resting on the pet since then.
    public var pettingSince: Date?
    /// Where a finger is, in −1…1 around the head, while one is down.
    public var look: CGPoint?
    /// Sit With Pet's breathing guide, 0 (out) … 1 (in). Overrides the idle breath.
    public var breathGuide: Double?
    /// The mood picker is showing this mood; the pet tries it on.
    public var preview: Mood?
    /// The phone's tilt, −1 (left) … 1 (right): the pet leans against it to keep its balance.
    public var tilt: Double = 0
    /// Something in its paws that isn't the stance's own prop (the ball it fetched), and whether
    /// to hide the stance's prop (no laptop at play time).
    public var heldProp: PetProp?
    public var hidesStanceProp = false
    /// What it has on and around it (see `PetDressing.choose`).
    public var dressing: PetDressing
    /// The toy you play with most; now and then it brings it to you (see `PetToy`).
    public var favourite: PetToy?
    /// Yesterday was hard and nothing is logged yet today: greet softly, no bouncing about.
    public var gentle = false
    /// Music is playing while you play together: it dances.
    public var dancing = false
    public var wear: PetWear? {
        get { dressing.head }
        set { dressing.head = newValue }
    }

    public init(species: PetSpecies, stance: PetStance, previous: PetStance? = nil, stanceSince: Date = .distantPast, events: [PetEvent] = [],
                pettingSince: Date? = nil, look: CGPoint? = nil, breathGuide: Double? = nil, preview: Mood? = nil, wear: PetWear? = nil,
                dressing: PetDressing? = nil) {
        self.dressing = dressing ?? PetDressing(head: wear)
        self.species = species
        self.stance = stance
        self.previous = previous
        self.stanceSince = stanceSince
        self.events = events
        self.pettingSince = pettingSince
        self.look = look
        self.breathGuide = breathGuide
        self.preview = preview
    }

    /// What the pet is holding. Previewing a mood shows that mood's prop.
    public var prop: PetProp? {
        if let heldProp { return heldProp }
        if hidesStanceProp { return nil }
        if let preview { return PetStance.mood(preview, .moderate).prop }
        return stance.prop
    }

    /// What it is holding in this pose: its favourite ball while it offers it to you.
    public func prop(for pose: PetPose) -> PetProp? {
        if pose.holdToy > 0.5, heldProp == nil, prop == nil || prop == .ball { return .heldBall }
        return prop
    }
}

/// Turns a scene and a time into a pose. A pure function: same scene, same clock → same pet,
/// on any device. Layers, bottom to top:
///   stance rest (blended from the previous stance) → idle (breath, blinks, glances, sway, tail)
///   → one vignette slot at a time → event clips → petting → attention → secondary motion.
public enum PetDirector {
    public static let stanceBlend: TimeInterval = 0.7

    public static func pose(_ scene: PetScene, at date: Date) -> PetPose {
        let t = date.timeIntervalSince1970
        var p = primary(scene, t: t)
        // Secondary motion: ears and tail lag the body. Sample the primary motion a moment ago
        // and let the difference push them the other way (follow-through, not a simulation).
        let past = primary(scene, t: t - 0.08)
        let rise = p.lift - past.lift
        let tilt = p.headTilt - past.headTilt
        let sway = p.x - past.x
        p.earL += (-rise * 0.05 + tilt * 0.02).clamped(-0.5, 0.5)
        p.earR += (-rise * 0.05 - tilt * 0.02).clamped(-0.5, 0.5)
        p.tail += (-sway * 0.12 - (p.lean - past.lean) * 0.03).clamped(-0.5, 0.5)
        return p.clamped()
    }

    /// A still pose for surfaces that cannot animate: the stance's `hold` variation `index`.
    public static func hold(_ scene: PetScene, index: Int = 0) -> PetPose {
        var stance = scene.stance
        if let preview = scene.preview { stance = .mood(preview, .moderate) }
        let holds = stance.holds(scene.species)
        return holds[((index % holds.count) + holds.count) % holds.count].clamped()
    }

    // MARK: Layers

    static func primary(_ scene: PetScene, t: Double) -> PetPose {
        let s = scene.species
        var stance = scene.stance
        if let preview = scene.preview { stance = .mood(preview, .moderate) }

        // 1. Rest, blended from the previous stance.
        var p = stance.rest(s)
        let since = t - scene.stanceSince.timeIntervalSince1970
        if let previous = scene.previous, scene.preview == nil, since < stanceBlend {
            p = PetPose.mix(previous.rest(s), p, PetMath.easeInOut(since / stanceBlend))
        }

        // 2. Idle.
        p = idle(p, stance: stance, species: s, t: t)
        if let activity = stance.activity { p = doing(p, activity, t: t) }
        if stance == .meditating {
            // Sitting so still it seems to float a little.
            p.lift += 3 + sin(t * 0.55) * 1.6
        }
        if scene.dancing, !stance.isAsleep {
            p = dance(p, stance: stance, t: t)
        } else if scene.wear == .headphones {
            p = listening(p, stance: stance, t: t)
        }

        // 3. Event clips (and how much they push vignettes aside).
        var busy = 0.0
        for event in scene.events {
            let local = t - event.at.timeIntervalSince1970
            guard let clip = clip(for: event.kind, stance: stance, species: s, gentle: scene.gentle), local >= 0, local <= clip.duration else { continue }
            p = clip.apply(to: p, at: local, weight: weight(for: event.kind))
            busy = max(busy, clip.envelope(at: local))
        }
        if let since = scene.pettingSince {
            let w = PetMath.smoothstep((t - since.timeIntervalSince1970) / 0.35)
            p = petting(p, stance: stance, species: s, t: t, weight: w)
            busy = max(busy, w)
        }

        // 4. A vignette, unless something else is going on.
        if busy < 0.99, scene.preview == nil, let (clip, local) = vignette(stance: stance, species: s, t: t, extras: extras(scene, stance: stance, t: t),
                                                                            gentle: scene.gentle) {
            p = clip.apply(to: p, at: local, weight: 1 - busy)
        }

        // 5. Attention: a finger on the screen draws the eyes, and a little of the head.
        if let look = scene.look, !stance.isAsleep {
            p.gazeX += (Double(look.x).clamped(-1, 1) - p.gazeX) * 0.9
            p.gazeY += (Double(look.y).clamped(-1, 1) * 0.7 - p.gazeY) * 0.9
            p.headTurn += Double(look.x).clamped(-1, 1) * 0.3
            p.headTilt += Double(look.x).clamped(-1, 1) * 4
        }

        // Carrying the ball back: both paws hold it at the chest.
        if scene.heldProp == .heldBall { p.armL = -55; p.armR = -55 }

        // 6. The phone tilts: lean against it, head level, arms out for balance.
        if scene.tilt != 0, !stance.isAsleep {
            let tilt = scene.tilt.clamped(-1, 1)
            p.lean -= tilt * 16
            p.headTilt += tilt * 10
            p.armL += abs(tilt) * 55
            p.armR += abs(tilt) * 55
            p.eyeWide += abs(tilt) * 0.2
            p.gazeX -= tilt * 0.6
        }

        // 7. Sit With Pet: the chest follows the guide.
        if let guide = scene.breathGuide {
            p.breath = guide * 1.2
            p.headNod = p.headNod - guide * 0.08
        }
        return p
    }

    static func weight(for kind: PetEvent.Kind) -> Double {
        if case .logged(_, let intensity) = kind { return intensity.weight }
        return 1
    }

    static func clip(for kind: PetEvent.Kind, stance: PetStance, species s: PetSpecies, gentle: Bool = false) -> PetClip? {
        switch kind {
        case .arrive: gentle && !stance.isAsleep ? PetClips.gentleHello(s) : PetClips.arrive(stance, s)
        case .gentleHello: PetClips.gentleHello(s)
        case .poke(let head, let variant): PetPokes.clip(for: stance, species: s, onHead: head, variant: variant)
        case .swat(let left): PetClips.swat(s, left: left)
        case .missedYou: stance.isAsleep ? PetClips.arrive(stance, s) : PetClips.missedYou(s)
        case .logged(let mood, _): PetClips.reaction(to: mood, s)
        case .boop: PetClips.boop(s)
        case .tickle: PetClips.tickle(s)
        case .flustered: PetClips.flustered(s)
        case .petted: PetClips.afterPetting(s)
        case .wave: PetClips.wave(s)
        case .munch: PetClips.munch(s)
        case .listening: PetClips.listening(s)
        case .dizzy: PetClips.dizzy(s)
        case .hop: PetClips.hop(s)
        case .proud: PetClips.vignette(.wiggle, s)
        }
    }

    /// Breath with a tempo that drifts, irregular blinks, glances that hold, a little sway,
    /// the tail. Everything is seeded by wall-clock time.
    static func idle(_ base: PetPose, stance: PetStance, species: PetSpecies, t: Double) -> PetPose {
        var p = base
        let idle = stance.idle
        // Breath: a rate that wanders ±10% so it never ticks like a metronome. Inhale is quicker than exhale.
        let phase = t * idle.breathRate + PetMath.noise(t * 0.05, seed: 1) * 0.35
        let u = phase - floor(phase)
        let wave = u < 0.4 ? PetMath.easeInOut(u / 0.4) : 1 - PetMath.easeInOut((u - 0.4) / 0.6)
        p.breath += wave * idle.breathDepth

        // Sway and head drift.
        p.lean += PetMath.noise(t * 0.13, seed: 2) * idle.sway
        p.headTilt += PetMath.noise(t * 0.17, seed: 3) * idle.tiltNoise
        p.headTurn += PetMath.noise(t * 0.11, seed: 4) * 0.08

        // On its toes (excited): a light, quick bounce.
        if idle.bob > 0 {
            let b = abs(sin(t * .pi * 1.6))
            p.lift += b * 2.2 * idle.bob
            p.squash += (1 - b) * 0.05 * idle.bob
        }

        // Blinks: one every 2.5–5.5 s, sometimes a double. Sleepy lids blink slower.
        if idle.blinks {
            let slot = 4.0
            let n = floor(t / slot)
            let start = n * slot + PetMath.hash01(n * 1.9) * 2.6
            let dur = 0.16 + p.lidL * 0.12
            var close = PetMath.bump((t - start) / dur)
            if PetMath.hash01(n * 3.7) > 0.78 { close = max(close, PetMath.bump((t - start - dur - 0.1) / dur)) }
            p.blink = max(p.blink, close)
        }

        // Glances: pick a spot, move there quickly, hold. Now and then look straight at you.
        if idle.gazeRange > 0 {
            let slot = 2.3
            let n = floor(t / slot)
            func target(_ k: Double) -> (Double, Double) {
                if PetMath.hash01(k * 5.1) < 0.35 { return (0, 0) }
                return ((PetMath.hash01(k * 2.3) - 0.5) * 2 * idle.gazeRange, (PetMath.hash01(k * 7.7) - 0.5) * idle.gazeRange)
            }
            let (x0, y0) = target(n - 1), (x1, y1) = target(n)
            let k = PetMath.easeOut((t - n * slot) / 0.14)
            p.gazeX += x0 + (x1 - x0) * k
            p.gazeY += y0 + (y1 - y0) * k
            p.headTurn += (x0 + (x1 - x0) * PetMath.easeInOut((t - n * slot) / 0.5)) * 0.15
        }

        // Ear flicks now and then.
        let earSlot = floor(t / 5.3)
        if PetMath.hash01(earSlot * 4.4) < 0.35 {
            let e = PetMath.bump((t - earSlot * 5.3 - 1.2) / 0.3)
            if PetMath.hash01(earSlot * 8.1) < 0.5 { p.earL -= e * 0.5 } else { p.earR -= e * 0.5 }
        }

        // Tail: a slow swish, or a wag whose speed follows the mood.
        if idle.tailWag > 0.4 {
            p.tail += sin(t * (species == .dog ? 14 : 5) * idle.tailWag) * 0.7 * idle.tailWag
        } else {
            p.tail += PetMath.noise(t * 0.4, seed: 6) * 0.6
        }
        return p
    }

    /// What the pet is doing, all the time rather than now and then, so the status line is
    /// always visibly true: eyes that read lines, paws that type, a ball that rolls.
    static func doing(_ base: PetPose, _ activity: PetActivity, t: Double) -> PetPose {
        var p = base
        switch activity {
        case .reading:
            // A line takes 2.6 s: the eyes travel left to right, then flick back to the next line.
            let u = (t / 2.6).truncatingRemainder(dividingBy: 1)
            let x = u < 0.86 ? -0.65 + 1.3 * (u / 0.86) : 0.65 - 1.3 * PetMath.easeOut((u - 0.86) / 0.14)
            p.gazeX = x
            p.headTurn += x * 0.1
            p.gazeY = max(p.gazeY, 0.75)
        case .working:
            // Typing in bursts with small pauses to read the screen.
            let burst = PetMath.noise(t * 0.5, seed: 11) > -0.3
            if burst {
                p.armL += sin(t * 19) * 6
                p.armR += sin(t * 19 + 1.7) * 6
                p.headBob += abs(sin(t * 9.5)) * 0.6
            }
            p.gazeX = PetMath.noise(t * 0.35, seed: 12) * 0.5
            p.gazeY = 0.45
        case .playing:
            // It watches the ball roll back and forth.
            p.gazeX = 0.75 + sin(t * 1.1) * 0.2
            p.gazeY = 0.55
            p.headTurn += sin(t * 1.1) * 0.06
        case .daydreaming:
            p.gazeX = 0.5 + PetMath.noise(t * 0.2, seed: 13) * 0.1
            p.gazeY = -0.65
        default:
            break
        }
        return p
    }

    /// Music on while you play: a real dance on the beat (about 112 bpm) — bounce, sway, paws
    /// up in turn, little steps. After a hard mood it only sways, eyes half closed.
    static func dance(_ base: PetPose, stance: PetStance, t: Double) -> PetPose {
        guard !stance.isHard else { return listening(base, stance: stance, t: t) }
        var p = base
        let ph = t * 1.87 * .pi
        let bounce = abs(sin(ph))
        let side = sin(ph / 2)
        p.lift += bounce * 4
        p.squash += (1 - bounce) * 0.07
        p.lean += side * 8
        p.x += side * 3
        p.headTilt += sin(ph / 2 + 0.6) * 9
        p.headNod += (1 - bounce) * 0.08
        p.armL += 65 + side * 55
        p.armR += 65 - side * 55
        p.stepL += max(0, side) * 5
        p.stepR += max(0, -side) * 5
        p.smile = max(p.smile, 0.6)
        p.smileEyes = max(p.smileEyes, 0.55)
        p.notes = max(p.notes, 0.8)
        p.tail += sin(t * 11) * 0.8
        return p
    }

    /// Headphones on: a good mood nods along to the beat with a note or two; a hard one just
    /// sways slowly with its eyes half closed. Music is company too.
    static func listening(_ base: PetPose, stance: PetStance, t: Double) -> PetPose {
        var p = base
        if stance.isHard {
            p.headTilt += sin(t * 1.1) * 4
            p.lidL = max(p.lidL, 0.45); p.lidR = max(p.lidR, 0.45)
        } else {
            let beat = t * 2 * .pi * 1.7
            p.headNod += max(0, sin(beat)) * 0.12
            p.headTilt += sin(beat / 2) * 3.5
            p.notes = max(p.notes, 0.4)
            p.smile += 0.1
        }
        return p
    }

    /// Vignettes play one at a time in fixed wall-clock slots. Each run of slots walks a
    /// shuffled order of the repertoire, so nothing repeats back to back and every trick gets
    /// its turn (the Snoopy "decision engine", made deterministic).
    static func vignette(stance: PetStance, species: PetSpecies, t: Double, extras: [PetVignette] = [], gentle: Bool = false) -> (PetClip, Double)? {
        var repertoire = stance.repertoire(species)
        for extra in extras where !repertoire.contains(extra) { repertoire.append(extra) }
        if gentle { repertoire.removeAll { PetVignette.bouncy.contains($0) } }
        guard !repertoire.isEmpty else { return nil }
        let every = stance.vignetteEvery
        let n = floor(t / every)
        // Roughly one slot in five stays quiet.
        guard PetMath.hash01(n * 0.917 + 3) > 0.2 else { return nil }
        let v = choice(repertoire, slot: Int(n))
        let clip = PetClips.vignette(v, species)
        let room = max(every - clip.duration - 1, 0)
        let start = n * every + 0.5 + PetMath.hash01(n * 1.31) * room
        let local = t - start
        guard local >= 0, local <= clip.duration else { return nil }
        return (clip, local)
    }

    /// Vignettes that join the stance's own for now: the shape of the week, and its favourite
    /// toy. Only while it is awake, in a good or neutral mood, with its paws free.
    static func extras(_ scene: PetScene, stance: PetStance, t: Double) -> [PetVignette] {
        guard !stance.isAsleep, !stance.isHard, stance != .meditating else { return [] }
        var list = PetDay.weekVignettes(at: Date(timeIntervalSince1970: t))
        if let favourite = scene.favourite, scene.prop == nil || scene.prop == .ball { list.append(favourite.vignette) }
        return list
    }

    static func choice(_ list: [PetVignette], slot: Int) -> PetVignette {
        let count = list.count
        let cycle = slot >= 0 ? slot / count : (slot - count + 1) / count
        let previousLast = order(list, cycle: cycle - 1, previousLast: nil).last.map { list[$0] }
        return list[order(list, cycle: cycle, previousLast: previousLast)[((slot % count) + count) % count]]
    }

    /// One shuffled pass over the repertoire with no two equal vignettes side by side, and not
    /// starting with the one the previous pass ended on. Lists may repeat an entry to weight it.
    static func order(_ list: [PetVignette], cycle: Int, previousLast: PetVignette?) -> [Int] {
        var o = shuffled(list.count, seed: Double(cycle))
        func fix(from start: Int, before: PetVignette?) {
            for i in start..<o.count {
                let prev = i == 0 ? before : list[o[i - 1]]
                guard let prev, list[o[i]] == prev else { continue }
                if let j = (i + 1..<o.count).first(where: { list[o[$0]] != prev }) { o.swapAt(i, j) }
            }
        }
        fix(from: 0, before: previousLast)
        return o
    }

    static func shuffled(_ count: Int, seed: Double) -> [Int] {
        var idx = Array(0..<count)
        for i in stride(from: count - 1, to: 0, by: -1) {
            let j = Int(PetMath.hash01(seed * 91.7 + Double(i) * 17.3 + 0.5) * Double(i + 1)) % (i + 1)
            idx.swapAt(i, j)
        }
        return idx
    }

    /// A hand resting on the pet: eyes shut happy, leaning into it, slow breath, hearts. Asleep, it
    /// smiles in its sleep and snuggles into your hand without waking; in a hard feeling it leans
    /// in quietly, with a heart or two rather than a shower of them.
    public static func petting(_ base: PetPose, stance: PetStance = .mood(.happy, .moderate), species: PetSpecies, t: Double, weight w: Double) -> PetPose {
        if stance.isAsleep {
            var target = base
            target.smile = max(base.smile, 0.45)
            target.blush = 0.6
            target.headTilt = base.headTilt + 6 + sin(t * 0.9) * 1.5
            target.lean = base.lean + 3
            target.earL = -0.3; target.earR = -0.3
            target.hearts = 0.3
            return PetPose.mix(base, target, w)
        }
        var target = base
        target.smileEyes = 1
        target.lidL = 0; target.lidR = 0
        target.lidSlant = 0
        target.browShow = 0
        target.sweat = 0
        target.smile = max(base.smile, 0.7)
        target.mouthOpen = 0
        target.cheekPuff = 0
        target.blush = 0.9
        target.headTilt = base.headTilt + 11 + sin(t * 1.3) * 2
        target.headNod = min(base.headNod, 0.1)
        target.lean = base.lean + 4
        target.slump = min(base.slump, 0.2)
        target.earL = -0.25; target.earR = -0.25
        target.hearts = stance.isHard ? 0.4 : 0.75
        target.tail = species == .dog ? sin(t * 12) * 0.9 : base.tail
        target.tailUp = max(base.tailUp, 0.3)
        target.gazeX = 0; target.gazeY = 0
        return PetPose.mix(base, target, w)
    }
}
