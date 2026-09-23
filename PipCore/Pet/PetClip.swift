import Foundation

/// A short piece of keyframed acting: a vignette, a reaction, a greeting.
///
/// Clips are **additive**: each track adds an offset to the stance underneath, so a wave works
/// over any mood. Tracks marked `.set` instead pull a channel toward an absolute value (eyes to
/// the viewer, lids shut), weighted by the clip's envelope. Every key eases in, so motion always
/// has slow in and slow out; overshoot comes from keys, never from springs.
public struct PetClip {
    public enum Ease: Sendable { case inOut, out, `in`, linear, back }

    public struct Key {
        var t: Double
        var v: Double
        var ease: Ease
    }

    public struct Track {
        var channel: WritableKeyPath<PetPose, Double>
        var keys: [Key]
        var absolute: Bool

        func value(at t: Double) -> Double {
            guard let first = keys.first else { return 0 }
            if t <= first.t { return first.v }
            for i in 1..<keys.count where t <= keys[i].t {
                let a = keys[i - 1], b = keys[i]
                let u = (t - a.t) / max(b.t - a.t, 0.0001)
                let e: Double
                switch b.ease {
                case .inOut: e = PetMath.easeInOut(u)
                case .out: e = PetMath.easeOut(u)
                case .in: e = PetMath.easeIn(u)
                case .linear: e = u
                case .back: e = PetMath.easeOutBack(u)
                }
                return a.v + (b.v - a.v) * e
            }
            return keys.last!.v
        }
    }

    public var name: String
    public var duration: Double
    var tracks: [Track]
    /// Envelope for `.set` tracks and for fading a clip out when something interrupts it.
    public var fadeIn: Double = 0.15
    public var fadeOut: Double = 0.3

    init(_ name: String, _ duration: Double, fadeIn: Double = 0.15, fadeOut: Double = 0.3, _ tracks: [Track]) {
        self.name = name
        self.duration = duration
        self.tracks = tracks
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
    }

    /// 0 → 1 → 0 across the clip.
    public func envelope(at t: Double) -> Double {
        guard t >= 0, t <= duration else { return 0 }
        return PetMath.smoothstep(t / max(fadeIn, 0.001)) * PetMath.smoothstep((duration - t) / max(fadeOut, 0.001))
    }

    /// Applies the clip at local time `t` to `base`, scaled by `weight` (intensity, interruption).
    public func apply(to base: PetPose, at t: Double, weight: Double = 1) -> PetPose {
        guard t >= 0, t <= duration, weight > 0 else { return base }
        var p = base
        let env = envelope(at: t) * weight
        for track in tracks {
            let v = track.value(at: t)
            if track.absolute {
                p[keyPath: track.channel] += (v - p[keyPath: track.channel]) * env
            } else {
                p[keyPath: track.channel] += v * weight
            }
        }
        return p
    }
}

// MARK: - Authoring helpers

/// `K(0.3, 120)` — a key at 0.3 s. Eases in-out unless told otherwise.
func K(_ t: Double, _ v: Double, _ e: PetClip.Ease = .inOut) -> PetClip.Key { .init(t: t, v: v, ease: e) }

/// An additive track.
func add(_ c: WritableKeyPath<PetPose, Double>, _ keys: PetClip.Key...) -> PetClip.Track { .init(channel: c, keys: keys, absolute: false) }
func add(_ c: WritableKeyPath<PetPose, Double>, _ keys: [PetClip.Key]) -> PetClip.Track { .init(channel: c, keys: keys, absolute: false) }

/// A track that pulls the channel toward absolute values (weighted by the envelope).
func set(_ c: WritableKeyPath<PetPose, Double>, _ keys: PetClip.Key...) -> PetClip.Track { .init(channel: c, keys: keys, absolute: true) }

/// A bump: 0 → `v` by `peak`, held until `hold`, back to 0 by `end`.
func bump(_ c: WritableKeyPath<PetPose, Double>, _ v: Double, from: Double, peak: Double, hold: Double? = nil, end: Double) -> PetClip.Track {
    add(c, K(from, 0), K(peak, v, .out), K(hold ?? peak, v), K(end, 0))
}

/// An oscillation that eases in and out: `cycles` swings of ±`amp` around `center`, between two times.
func osc(_ c: WritableKeyPath<PetPose, Double>, from: Double, to: Double, center: Double = 0, amp: Double, cycles: Double, phase: Double = 0) -> PetClip.Track {
    var keys = [K(from, 0)]
    let steps = Int(cycles * 2)
    let span = to - from
    for i in 0...steps {
        let u = Double(i) / Double(steps)
        let t = from + span * (0.12 + 0.76 * u)
        let sign: Double = ((i + Int(phase)) % 2 == 0) ? 1 : -1
        let env = sin(Double.pi * (0.12 + 0.76 * u))
        keys.append(K(t, center + sign * amp * max(env, 0.35)))
    }
    keys.append(K(to, 0))
    return add(c, keys)
}
