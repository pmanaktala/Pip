import Foundation

/// Named pieces of acting. Vignettes are what a pet does on its own; reactions answer you.
/// Durations are in seconds. See `Docs/Pets/Bible.md` §4 for which stance uses which.
public enum PetVignette: String, CaseIterable, Codable, Sendable {
    case lookAround, curious, lookAtYou, slowBlink, stretch, yawn, nodOff, rubEye
    case dance, clap, bounce, fistPump, wiggle, hum
    case sip, deepBreath, shakeOff, fidget, sigh, patSpot, lookUpSmile
    case huff, stomp, pageTurn, chuckle, snore, earTwitch, stir
    case tailWag, groom, flap, waddle, headTilt, daydream, batBall
    case typing, typing2
    /// Monday morning: the biggest stretch of the week, and a yawn to go with it.
    case mondayStretch
    /// Friday evening: a happy little dance.
    case fridayWiggle
    /// Its favourite toy on the main screen: it brings you the ball, blows a bubble, or looks
    /// hopefully at you for a treat.
    case offerBall, blowBubble, hopeful

    /// Too lively for the day after a rough one.
    static let bouncy: Set<PetVignette> = [.bounce, .fistPump, .dance, .wiggle, .fridayWiggle, .clap]
}

public enum PetClips {
    // MARK: Vignettes

    public static func vignette(_ v: PetVignette, _ s: PetSpecies) -> PetClip {
        switch v {
        case .lookAround:
            return PetClip("lookAround", 3.4, fadeIn: 0.25, fadeOut: 0.4, [
                set(\.gazeX, K(0, 0), K(0.35, -0.85, .out), K(1.3, -0.85), K(1.6, 0.85, .out), K(2.6, 0.85), K(3.0, 0)),
                add(\.headTurn, K(0, 0), K(0.5, -0.35), K(1.4, -0.35), K(1.8, 0.35), K(2.7, 0.35), K(3.2, 0)),
                add(\.headTilt, K(0, 0), K(0.5, -3), K(1.8, 4), K(3.2, 0)),
            ])
        case .curious:
            return PetClip("curious", 2.6, [
                add(\.headTilt, K(0, 0), K(0.45, 15, .back), K(1.9, 15), K(2.5, 0)),
                add(\.earL, K(0, 0), K(0.4, 0.5), K(2.0, 0.5), K(2.5, 0)),
                add(\.earR, K(0, 0), K(0.4, -0.2), K(2.0, -0.2), K(2.5, 0)),
                add(\.browRaise, K(0, 0), K(0.4, 0.8), K(2.0, 0.8), K(2.5, 0)),
                add(\.eyeWide, K(0, 0), K(0.4, 0.12), K(2.0, 0.12), K(2.5, 0)),
                bump(\.question, 1, from: 0.3, peak: 0.6, hold: 1.7, end: 2.1),
                set(\.gazeX, K(0, 0), K(0.4, 0.25), K(2.6, 0.25)),
            ])
        case .lookAtYou:
            return PetClip("lookAtYou", 2.8, fadeIn: 0.3, fadeOut: 0.5, [
                set(\.gazeX, K(0, 0), K(2.8, 0)), set(\.gazeY, K(0, -0.1), K(2.8, -0.1)),
                add(\.headTurn, K(0, 0)),
                bump(\.smileEyes, 0.5, from: 0.2, peak: 0.8, hold: 2.1, end: 2.7),
                bump(\.smile, 0.35, from: 0.2, peak: 0.8, hold: 2.1, end: 2.7),
                bump(\.headTilt, 6, from: 0.1, peak: 0.8, hold: 2.1, end: 2.7),
                bump(\.blush, 0.35, from: 0.4, peak: 1.0, hold: 2.0, end: 2.7),
            ])
        case .slowBlink:
            // The cat's "I trust you": a long, slow close and open while looking at you.
            return PetClip("slowBlink", 2.6, fadeIn: 0.3, fadeOut: 0.4, [
                set(\.gazeX, K(0, 0), K(2.6, 0)),
                set(\.lidL, K(0, 0.2), K(0.9, 1), K(1.4, 1), K(2.2, 0.15)),
                set(\.lidR, K(0, 0.2), K(0.9, 1), K(1.4, 1), K(2.2, 0.15)),
                bump(\.smile, 0.35, from: 0.3, peak: 1.0, hold: 1.8, end: 2.5),
                bump(\.headTilt, 5, from: 0.2, peak: 1.0, hold: 1.8, end: 2.5),
            ])
        case .stretch:
            return PetClip("stretch", 3.0, [
                add(\.armL, K(0, 0), K(0.2, -10), K(0.75, 155, .out), K(1.7, 160), K(2.2, 0)),
                add(\.armR, K(0, 0), K(0.2, -10), K(0.75, 155, .out), K(1.7, 160), K(2.2, 0)),
                add(\.squash, K(0, 0), K(0.2, 0.15), K(0.75, -0.3, .out), K(1.7, -0.3), K(2.2, 0.05), K(2.5, 0)),
                add(\.lift, K(0, 0), K(0.75, 3), K(1.7, 3), K(2.2, 0)),
                set(\.lidL, K(0, 0), K(0.6, 1), K(1.8, 1), K(2.3, 0)), set(\.lidR, K(0, 0), K(0.6, 1), K(1.8, 1), K(2.3, 0)),
                bump(\.mouthOpen, 0.7, from: 0.5, peak: 0.9, hold: 1.5, end: 1.9), bump(\.mouthRound, 0.7, from: 0.5, peak: 0.9, hold: 1.5, end: 1.9),
                bump(\.headNod, -0.35, from: 0.3, peak: 0.9, hold: 1.5, end: 2.1),
                osc(\.x, from: 2.1, to: 2.9, amp: 1.6, cycles: 2.5),
                osc(\.headTilt, from: 2.1, to: 2.9, amp: 6, cycles: 2.5),
            ])
        case .yawn:
            return PetClip("yawn", 2.4, [
                bump(\.headNod, -0.4, from: 0.1, peak: 0.6, hold: 1.4, end: 2.0),
                set(\.mouthOpen, K(0, 0), K(0.6, 1), K(1.4, 1), K(1.9, 0)), set(\.mouthRound, K(0, 0), K(0.6, 0.7), K(1.4, 0.7), K(1.9, 0)),
                set(\.lidL, K(0, 0.3), K(0.6, 1), K(1.5, 1), K(2.1, 0.4)), set(\.lidR, K(0, 0.3), K(0.6, 1), K(1.5, 1), K(2.1, 0.4)),
                add(\.armR, K(0, 0), K(0.5, -95), K(1.5, -95), K(2.1, 0)),
                bump(\.breath, 1, from: 0.1, peak: 0.8, hold: 1.2, end: 2.0),
                bump(\.squash, -0.12, from: 0.2, peak: 0.8, hold: 1.2, end: 2.0),
            ])
        case .nodOff:
            return PetClip("nodOff", 3.8, fadeIn: 0.3, fadeOut: 0.5, [
                add(\.headNod, K(0, 0), K(2.2, 0.55, .in), K(2.35, -0.15, .out), K(2.8, 0), K(3.6, 0)),
                add(\.headTilt, K(0, 0), K(2.2, -9, .in), K(2.4, 2, .out), K(3.4, 0)),
                set(\.lidL, K(0, 0.5), K(1.8, 1), K(2.3, 1), K(2.4, 0), K(3.0, 0.4)),
                set(\.lidR, K(0, 0.5), K(1.8, 1), K(2.3, 1), K(2.4, 0), K(3.0, 0.4)),
                bump(\.eyeWide, 0.3, from: 2.3, peak: 2.45, hold: 2.7, end: 3.3),
                bump(\.earL, 0.6, from: 2.3, peak: 2.4, end: 3.0), bump(\.earR, 0.6, from: 2.3, peak: 2.4, end: 3.0),
                bump(\.exclaim, 0.6, from: 2.3, peak: 2.4, hold: 2.8, end: 3.1),
            ])
        case .rubEye:
            return PetClip("rubEye", 2.2, [
                add(\.armR, K(0, 0), K(0.45, -118, .out), K(1.6, -118), K(2.0, 0)),
                osc(\.armR, from: 0.5, to: 1.6, amp: 6, cycles: 3),
                set(\.lidR, K(0, 0.3), K(0.45, 1), K(1.6, 1), K(2.0, 0.3)),
                bump(\.headTilt, 6, from: 0.2, peak: 0.6, hold: 1.5, end: 2.0),
                bump(\.smile, -0.2, from: 0.3, peak: 0.6, hold: 1.5, end: 2.0),
            ])
        case .dance:
            return PetClip("dance", 3.4, [
                osc(\.x, from: 0, to: 3.3, amp: 3.5, cycles: 3),
                osc(\.lean, from: 0, to: 3.3, amp: 7, cycles: 3),
                osc(\.headTilt, from: 0, to: 3.3, amp: 7, cycles: 3, phase: 1),
                osc(\.stepL, from: 0, to: 3.3, center: 3, amp: 3, cycles: 3),
                osc(\.stepR, from: 0, to: 3.3, center: 3, amp: 3, cycles: 3, phase: 1),
                add(\.armL, K(0, 0), K(0.4, 45), K(2.9, 45), K(3.3, 0)), add(\.armR, K(0, 0), K(0.4, 45), K(2.9, 45), K(3.3, 0)),
                osc(\.armL, from: 0.3, to: 3.0, amp: 18, cycles: 3), osc(\.armR, from: 0.3, to: 3.0, amp: 18, cycles: 3, phase: 1),
                bump(\.smileEyes, 0.5, from: 0, peak: 0.4, hold: 3.0, end: 3.4),
                bump(\.notes, 1, from: 0.2, peak: 0.6, hold: 2.8, end: 3.3),
            ])
        case .clap:
            return PetClip("clap", 1.9, [
                set(\.armL, K(0, 0), K(0.25, 30), K(0.45, -55, .in), K(0.65, 25), K(0.85, -55, .in), K(1.05, 25), K(1.25, -55, .in), K(1.6, 0)),
                set(\.armR, K(0, 0), K(0.25, 30), K(0.45, -55, .in), K(0.65, 25), K(0.85, -55, .in), K(1.05, 25), K(1.25, -55, .in), K(1.6, 0)),
                bump(\.smileEyes, 0.8, from: 0, peak: 0.3, hold: 1.4, end: 1.8),
                bump(\.mouthOpen, 0.6, from: 0, peak: 0.3, hold: 1.4, end: 1.8),
                bump(\.lift, 3, from: 0.35, peak: 0.5, end: 0.7), bump(\.lift, 3, from: 0.75, peak: 0.9, end: 1.1),
            ])
        case .bounce:
            return PetClip("bounce", 1.6, [
                add(\.squash, K(0, 0), K(0.12, 0.22), K(0.3, -0.2, .out), K(0.5, 0.25, .in), K(0.62, -0.12), K(0.82, 0.2, .in), K(1.1, 0)),
                add(\.lift, K(0, 0), K(0.12, 0), K(0.33, 11, .out), K(0.5, 0, .in), K(0.66, 7, .out), K(0.82, 0, .in)),
                add(\.armL, K(0, 0), K(0.3, 70), K(0.9, 50), K(1.4, 0)), add(\.armR, K(0, 0), K(0.3, 70), K(0.9, 50), K(1.4, 0)),
                bump(\.smileEyes, 0.8, from: 0, peak: 0.25, hold: 1.1, end: 1.5),
                bump(\.earL, -0.4, from: 0.3, peak: 0.45, end: 0.8), bump(\.earR, -0.4, from: 0.3, peak: 0.45, end: 0.8),
            ])
        case .fistPump:
            return PetClip("fistPump", 1.6, [
                add(\.armR, K(0, 0), K(0.25, 155, .out), K(0.45, 115), K(0.65, 155), K(0.85, 115), K(1.05, 150), K(1.45, 0)),
                bump(\.lift, 5, from: 0.15, peak: 0.3, end: 0.55),
                bump(\.smileEyes, 1, from: 0, peak: 0.25, hold: 1.2, end: 1.55),
                bump(\.mouthOpen, 0.7, from: 0, peak: 0.25, hold: 1.2, end: 1.55),
                bump(\.sparkles, 0.8, from: 0.2, peak: 0.4, hold: 1.1, end: 1.5),
            ])
        case .wiggle:
            return PetClip("wiggle", 2.0, [
                osc(\.x, from: 0, to: 1.9, amp: 2.6, cycles: 4),
                osc(\.lean, from: 0, to: 1.9, amp: 6, cycles: 4, phase: 1),
                osc(\.tail, from: 0, to: 1.9, amp: 1, cycles: 6),
                bump(\.smileEyes, 0.6, from: 0, peak: 0.3, hold: 1.6, end: 1.95),
                bump(\.smile, 0.3, from: 0, peak: 0.3, hold: 1.6, end: 1.95),
            ])
        case .hum:
            return PetClip("hum", 3.4, fadeIn: 0.3, fadeOut: 0.5, [
                osc(\.headTilt, from: 0, to: 3.3, amp: 6, cycles: 2),
                osc(\.lean, from: 0, to: 3.3, amp: 3, cycles: 2),
                set(\.lidL, K(0, 0.2), K(0.5, 0.75), K(2.9, 0.75), K(3.3, 0.2)), set(\.lidR, K(0, 0.2), K(0.5, 0.75), K(2.9, 0.75), K(3.3, 0.2)),
                bump(\.mouthOpen, 0.25, from: 0.3, peak: 0.6, hold: 2.8, end: 3.2), bump(\.mouthRound, 0.9, from: 0.3, peak: 0.6, hold: 2.8, end: 3.2),
                bump(\.notes, 1, from: 0.3, peak: 0.8, hold: 2.8, end: 3.3),
            ])
        case .sip:
            return PetClip("sip", 3.2, fadeIn: 0.3, fadeOut: 0.4, [
                add(\.armL, K(0, 0), K(0.8, -22), K(2.0, -22), K(2.6, 0)), add(\.armR, K(0, 0), K(0.8, -22), K(2.0, -22), K(2.6, 0)),
                add(\.headNod, K(0, 0), K(0.8, 0.2), K(2.0, 0.2), K(2.6, -0.1), K(3.1, 0)),
                set(\.lidL, K(0, 0.3), K(0.8, 1), K(2.0, 1), K(2.5, 0.35)), set(\.lidR, K(0, 0.3), K(0.8, 1), K(2.0, 1), K(2.5, 0.35)),
                bump(\.breath, 0.8, from: 2.0, peak: 2.5, end: 3.1),
                bump(\.smile, 0.3, from: 2.1, peak: 2.5, hold: 2.9, end: 3.2),
                bump(\.blush, 0.3, from: 2.1, peak: 2.5, hold: 2.9, end: 3.2),
            ])
        case .deepBreath:
            return PetClip("deepBreath", 5.6, fadeIn: 0.5, fadeOut: 0.6, [
                add(\.breath, K(0, 0), K(2.2, 1.2), K(2.6, 1.2), K(5.2, -0.2), K(5.6, 0)),
                add(\.headNod, K(0, 0), K(2.2, -0.2), K(2.6, -0.2), K(5.2, 0.05), K(5.6, 0)),
                set(\.lidL, K(0, 0.2), K(1.6, 1), K(4.8, 1), K(5.5, 0.2)), set(\.lidR, K(0, 0.2), K(1.6, 1), K(4.8, 1), K(5.5, 0.2)),
                bump(\.mouthRound, 0.8, from: 2.7, peak: 3.1, hold: 4.6, end: 5.0), bump(\.mouthOpen, 0.2, from: 2.7, peak: 3.1, hold: 4.6, end: 5.0),
                add(\.slump, K(0, 0), K(2.2, -0.2), K(5.0, 0.1), K(5.6, 0)),
                add(\.earL, K(0, 0), K(2.4, 0.3), K(5.0, 0.4), K(5.6, 0)), add(\.earR, K(0, 0), K(2.4, 0.3), K(5.0, 0.4), K(5.6, 0)),
            ])
        case .shakeOff:
            return PetClip("shakeOff", 1.8, [
                osc(\.x, from: 0.1, to: 1.4, amp: 3.2, cycles: 5),
                osc(\.headTilt, from: 0.1, to: 1.4, amp: 11, cycles: 5, phase: 1),
                osc(\.earL, from: 0.1, to: 1.5, amp: 0.7, cycles: 5), osc(\.earR, from: 0.1, to: 1.5, amp: 0.7, cycles: 5, phase: 1),
                osc(\.tail, from: 0.1, to: 1.5, amp: 0.8, cycles: 5),
                set(\.squeeze, K(0, 0), K(0.15, 1), K(1.3, 1), K(1.45, 0)),
                bump(\.smile, 0.3, from: 1.3, peak: 1.5, end: 1.8),
            ])
        case .fidget:
            return PetClip("fidget", 2.6, [
                osc(\.armL, from: 0.1, to: 2.4, amp: 8, cycles: 4), osc(\.armR, from: 0.1, to: 2.4, amp: 8, cycles: 4, phase: 1),
                set(\.gazeY, K(0, 0), K(0.3, 0.7), K(2.3, 0.7), K(2.6, 0)),
                osc(\.gazeX, from: 0.3, to: 2.3, amp: 0.4, cycles: 2),
                bump(\.headNod, 0.15, from: 0, peak: 0.4, hold: 2.1, end: 2.5),
            ])
        case .sigh:
            return PetClip("sigh", 2.6, fadeIn: 0.3, fadeOut: 0.4, [
                add(\.breath, K(0, 0), K(0.9, 1), K(2.1, -0.3), K(2.6, 0)),
                add(\.slump, K(0, 0), K(0.9, -0.1), K(2.1, 0.15), K(2.6, 0)),
                add(\.headNod, K(0, 0), K(0.9, -0.15), K(2.1, 0.15), K(2.6, 0)),
                set(\.lidL, K(0, 0.3), K(1.0, 0.7), K(2.0, 0.7), K(2.5, 0.3)), set(\.lidR, K(0, 0.3), K(1.0, 0.7), K(2.0, 0.7), K(2.5, 0.3)),
                bump(\.mouthOpen, 0.2, from: 1.0, peak: 1.3, hold: 1.8, end: 2.1), bump(\.mouthRound, 0.8, from: 1.0, peak: 1.3, hold: 1.8, end: 2.1),
            ])
        case .patSpot:
            // "Sit here with me": pats the floor beside it and looks at you.
            return PetClip("patSpot", 3.0, fadeIn: 0.3, fadeOut: 0.4, [
                set(\.armR, K(0, -30), K(0.5, 30), K(0.75, 18, .in), K(1.0, 32), K(1.25, 18, .in), K(1.5, 32), K(1.75, 18, .in), K(2.5, -30)),
                set(\.gazeX, K(0, 0.2), K(0.4, 0.7), K(1.2, 0.7), K(1.5, 0), K(3.0, 0)),
                set(\.gazeY, K(0, 0.3), K(0.4, 0.6), K(1.2, 0.6), K(1.5, -0.1), K(3.0, -0.1)),
                bump(\.headTilt, 8, from: 0.2, peak: 0.6, hold: 2.4, end: 2.9),
                bump(\.smile, 0.5, from: 1.2, peak: 1.6, hold: 2.5, end: 2.9),
                bump(\.lidSlant, 0.5, from: 1.2, peak: 1.6, hold: 2.5, end: 2.9),
            ])
        case .lookUpSmile:
            return PetClip("lookUpSmile", 3.0, fadeIn: 0.4, fadeOut: 0.5, [
                add(\.headNod, K(0, 0), K(0.7, -0.4), K(2.3, -0.4), K(2.9, 0)),
                add(\.slump, K(0, 0), K(0.7, -0.2), K(2.3, -0.2), K(2.9, 0)),
                set(\.gazeX, K(0, 0), K(3.0, 0)), set(\.gazeY, K(0, -0.15), K(3.0, -0.15)),
                bump(\.smile, 0.7, from: 0.5, peak: 1.0, hold: 2.2, end: 2.8),
                bump(\.lidSlant, 0.5, from: 0.5, peak: 1.0, hold: 2.2, end: 2.8),
                bump(\.earL, 0.4, from: 0.5, peak: 1.0, hold: 2.2, end: 2.8), bump(\.earR, 0.4, from: 0.5, peak: 1.0, hold: 2.2, end: 2.8),
                bump(\.tail, 0.4, from: 0.8, peak: 1.2, end: 1.6), bump(\.tail, -0.4, from: 1.6, peak: 2.0, end: 2.4),
            ])
        case .huff:
            return PetClip("huff", 1.8, [
                set(\.cheekPuff, K(0, 0), K(0.5, 1), K(0.7, 1), K(0.8, 0)),
                bump(\.breath, 0.8, from: 0, peak: 0.5, hold: 0.7, end: 0.95),
                bump(\.mouthOpen, 0.4, from: 0.7, peak: 0.8, hold: 1.0, end: 1.3), bump(\.mouthRound, 0.8, from: 0.7, peak: 0.8, hold: 1.0, end: 1.3),
                bump(\.steam, 1, from: 0.75, peak: 0.9, hold: 1.3, end: 1.7),
                bump(\.squash, 0.12, from: 0.7, peak: 0.85, end: 1.2),
            ])
        case .stomp:
            return PetClip("stomp", 1.4, [
                add(\.stepR, K(0, 0), K(0.25, 10, .out), K(0.36, 0, .in), K(0.6, 0), K(0.8, 9, .out), K(0.9, 0, .in)),
                add(\.squash, K(0, 0), K(0.36, 0), K(0.42, 0.22), K(0.6, 0), K(0.9, 0), K(0.96, 0.2), K(1.2, 0)),
                add(\.lean, K(0, 0), K(0.25, -4), K(0.45, 2), K(0.8, -3), K(1.0, 1), K(1.3, 0)),
                bump(\.steam, 0.8, from: 0.4, peak: 0.55, hold: 1.0, end: 1.4),
                bump(\.headNod, 0.12, from: 0.36, peak: 0.42, end: 0.6),
            ])
        case .pageTurn:
            return PetClip("pageTurn", 1.8, [
                add(\.armR, K(0, 0), K(0.3, 30, .out), K(0.55, 0)),
                set(\.gazeX, K(0, 0.6), K(0.35, 0.6), K(0.6, -0.6, .out), K(1.6, 0.3, .linear), K(1.8, 0.3)),
                add(\.headTurn, K(0, 0), K(0.6, -0.12), K(1.6, 0.08), K(1.8, 0)),
            ])
        case .chuckle:
            return PetClip("chuckle", 1.5, [
                bump(\.smileEyes, 0.9, from: 0, peak: 0.2, hold: 1.1, end: 1.45),
                bump(\.mouthOpen, 0.35, from: 0, peak: 0.2, hold: 1.1, end: 1.45),
                osc(\.squash, from: 0.1, to: 1.1, amp: 0.06, cycles: 3),
                bump(\.headTilt, -5, from: 0, peak: 0.3, hold: 1.0, end: 1.4),
            ])
        case .snore:
            return PetClip("snore", 3.2, fadeIn: 0.4, fadeOut: 0.5, [
                add(\.breath, K(0, 0), K(1.4, 1.2), K(2.8, -0.1), K(3.2, 0)),
                bump(\.mouthOpen, 0.3, from: 1.0, peak: 1.4, hold: 1.8, end: 2.4), bump(\.mouthRound, 0.9, from: 1.0, peak: 1.4, hold: 1.8, end: 2.4),
                bump(\.headNod, -0.1, from: 0.4, peak: 1.4, end: 2.8),
                bump(\.zzz, 0.4, from: 1.2, peak: 1.6, hold: 2.4, end: 3.0),
            ])
        case .earTwitch:
            return PetClip("earTwitch", 0.8, fadeIn: 0.05, fadeOut: 0.2, [
                add(\.earR, K(0, 0), K(0.08, -0.7, .out), K(0.2, 0.3), K(0.35, -0.3), K(0.6, 0)),
                bump(\.headTilt, -2, from: 0, peak: 0.1, end: 0.5),
            ])
        case .stir:
            return PetClip("stir", 2.6, fadeIn: 0.3, fadeOut: 0.5, [
                add(\.headTilt, K(0, 0), K(0.8, 9), K(1.9, 9), K(2.6, 0)),
                bump(\.headNod, -0.1, from: 0.2, peak: 0.8, end: 1.6),
                bump(\.mouthOpen, 0.15, from: 0.6, peak: 0.8, end: 1.1), bump(\.mouthOpen, 0.15, from: 1.1, peak: 1.3, end: 1.6),
                bump(\.smile, 0.3, from: 1.2, peak: 1.6, hold: 2.1, end: 2.4),
                add(\.armL, K(0, 0), K(0.8, 8), K(1.9, 8), K(2.6, 0)),
            ])
        case .tailWag:
            return PetClip("tailWag", 2.2, [
                osc(\.tail, from: 0, to: 2.1, amp: 1, cycles: s == .cat ? 2 : 7),
                add(\.tailUp, K(0, 0), K(0.3, 0.4), K(1.8, 0.4), K(2.1, 0)),
                osc(\.x, from: 0, to: 2.1, amp: s == .dog ? 1.3 : 0, cycles: 7),
                bump(\.smile, 0.25, from: 0, peak: 0.3, hold: 1.8, end: 2.1),
                bump(\.earL, 0.3, from: 0, peak: 0.3, hold: 1.8, end: 2.1), bump(\.earR, 0.3, from: 0, peak: 0.3, hold: 1.8, end: 2.1),
            ])
        case .groom:
            return PetClip("groom", 3.2, [
                add(\.armR, K(0, 0), K(0.5, -112, .out), K(2.6, -112), K(3.0, 0)),
                osc(\.armR, from: 0.6, to: 2.5, amp: 7, cycles: 4),
                osc(\.headTilt, from: 0.5, to: 2.6, center: 10, amp: 5, cycles: 4),
                set(\.lidL, K(0, 0.2), K(0.5, 1), K(2.6, 1), K(3.0, 0.2)), set(\.lidR, K(0, 0.2), K(0.5, 1), K(2.6, 1), K(3.0, 0.2)),
                bump(\.mouthOpen, 0.25, from: 0.5, peak: 0.7, hold: 2.4, end: 2.7),
            ])
        case .flap:
            return PetClip("flap", 1.6, [
                add(\.armL, K(0, 0), K(0.15, 40), K(0.3, 85), K(0.45, 30), K(0.6, 85), K(0.75, 30), K(0.9, 80), K(1.3, 0)),
                add(\.armR, K(0, 0), K(0.15, 40), K(0.3, 85), K(0.45, 30), K(0.6, 85), K(0.75, 30), K(0.9, 80), K(1.3, 0)),
                bump(\.lift, 4, from: 0.2, peak: 0.45, end: 0.75),
                bump(\.smileEyes, 0.7, from: 0, peak: 0.25, hold: 1.1, end: 1.5),
                bump(\.mouthOpen, 0.4, from: 0, peak: 0.25, hold: 1.1, end: 1.5),
            ])
        case .waddle:
            return PetClip("waddle", 2.8, [
                add(\.stepL, K(0, 0), K(0.3, 6), K(0.55, 0), K(1.3, 0), K(1.6, 6), K(1.85, 0)),
                add(\.stepR, K(0, 0), K(0.65, 0), K(0.95, 6), K(1.2, 0), K(1.95, 0), K(2.25, 6), K(2.5, 0)),
                osc(\.lean, from: 0, to: 2.7, amp: 7, cycles: 2),
                osc(\.x, from: 0, to: 2.7, amp: 2.5, cycles: 2),
                osc(\.headTilt, from: 0, to: 2.7, amp: 5, cycles: 2, phase: 1),
                add(\.armL, K(0, 0), K(0.3, 25), K(2.4, 25), K(2.7, 0)), add(\.armR, K(0, 0), K(0.3, 25), K(2.4, 25), K(2.7, 0)),
            ])
        case .headTilt:
            return PetClip("headTilt", 2.2, [
                add(\.headTilt, K(0, 0), K(0.35, 18, .back), K(1.6, 18), K(2.1, 0)),
                add(\.earL, K(0, 0), K(0.35, 0.8), K(1.6, 0.8), K(2.1, 0)),
                add(\.earR, K(0, 0), K(0.35, -0.3), K(1.6, -0.3), K(2.1, 0)),
                add(\.browRaise, K(0, 0), K(0.35, 0.8), K(1.6, 0.8), K(2.1, 0)),
                set(\.gazeX, K(0, 0), K(2.2, 0)),
                bump(\.eyeWide, 0.15, from: 0.1, peak: 0.4, hold: 1.6, end: 2.1),
            ])
        case .daydream:
            return PetClip("daydream", 3.6, fadeIn: 0.5, fadeOut: 0.6, [
                set(\.gazeX, K(0, 0.3), K(0.7, 0.55), K(3.6, 0.55)), set(\.gazeY, K(0, -0.4), K(0.7, -0.85), K(3.6, -0.85)),
                bump(\.headNod, -0.25, from: 0.2, peak: 0.9, hold: 2.9, end: 3.5),
                bump(\.headTilt, 7, from: 0.2, peak: 0.9, hold: 2.9, end: 3.5),
                bump(\.smile, 0.35, from: 0.6, peak: 1.2, hold: 2.8, end: 3.4),
                bump(\.blush, 0.3, from: 0.8, peak: 1.4, hold: 2.6, end: 3.3),
                bump(\.breath, 0.7, from: 1.4, peak: 2.1, end: 3.0),
            ])
        case .typing:
            // Tap-tap-tap behind the lid, eyes tracking the line, a little nod at the end.
            return PetClip("typing", 3.0, fadeIn: 0.2, fadeOut: 0.4, [
                osc(\.armL, from: 0.1, to: 2.4, amp: 7, cycles: 7), osc(\.armR, from: 0.1, to: 2.4, amp: 7, cycles: 7, phase: 1),
                set(\.gazeX, K(0, -0.5), K(2.3, 0.5, .linear), K(2.6, -0.3), K(3.0, 0)),
                osc(\.headBob, from: 0.1, to: 2.4, amp: 0.6, cycles: 7),
                bump(\.headNod, 0.12, from: 2.3, peak: 2.5, end: 2.9),
                bump(\.smile, 0.2, from: 2.3, peak: 2.6, end: 3.0),
            ])
        case .typing2:
            // Reads something, thinks, then a quick burst of typing.
            return PetClip("typing2", 3.2, fadeIn: 0.25, fadeOut: 0.4, [
                bump(\.headTilt, 7, from: 0, peak: 0.5, hold: 1.4, end: 1.8),
                bump(\.browRaise, 0.6, from: 0.2, peak: 0.5, hold: 1.3, end: 1.7),
                set(\.gazeY, K(0, 0.45), K(0.5, 0.1), K(1.5, 0.1), K(1.9, 0.5), K(3.2, 0.45)),
                osc(\.armL, from: 1.8, to: 3.1, amp: 8, cycles: 5), osc(\.armR, from: 1.8, to: 3.1, amp: 8, cycles: 5, phase: 1),
            ])
        case .mondayStretch:
            return PetClip("mondayStretch", 4.6, [
                add(\.armL, K(0, 0), K(0.3, -10), K(0.95, 168, .out), K(2.4, 172), K(2.95, 0)),
                add(\.armR, K(0, 0), K(0.3, -10), K(0.95, 168, .out), K(2.4, 172), K(2.95, 0)),
                add(\.squash, K(0, 0), K(0.3, 0.15), K(0.95, -0.36, .out), K(2.4, -0.36), K(2.95, 0.06), K(3.2, 0)),
                add(\.lift, K(0, 0), K(0.95, 4), K(2.4, 4), K(2.95, 0)),
                bump(\.lidL, 1, from: 0.5, peak: 0.95, hold: 2.5, end: 3.0), bump(\.lidR, 1, from: 0.5, peak: 0.95, hold: 2.5, end: 3.0),
                bump(\.mouthOpen, 1, from: 0.8, peak: 1.3, hold: 2.2, end: 2.7), bump(\.mouthRound, 0.8, from: 0.8, peak: 1.3, hold: 2.2, end: 2.7),
                bump(\.headNod, -0.4, from: 0.5, peak: 1.1, hold: 2.3, end: 2.8),
                osc(\.x, from: 3.0, to: 4.3, amp: 1.8, cycles: 3), osc(\.headTilt, from: 3.0, to: 4.3, amp: 7, cycles: 3),
                // Still a bit sleepy afterwards.
                bump(\.lidL, 0.45, from: 3.1, peak: 3.4, hold: 4.0, end: 4.5), bump(\.lidR, 0.45, from: 3.1, peak: 3.4, hold: 4.0, end: 4.5),
            ])
        case .fridayWiggle:
            return PetClip("fridayWiggle", 3.0, [
                osc(\.x, from: 0, to: 2.9, amp: 3, cycles: 5),
                osc(\.lean, from: 0, to: 2.9, amp: 8, cycles: 5, phase: 1),
                osc(\.stepL, from: 0.1, to: 2.8, center: 3, amp: 3, cycles: 5),
                osc(\.stepR, from: 0.1, to: 2.8, center: 3, amp: 3, cycles: 5, phase: 1),
                add(\.armL, K(0, 0), K(0.3, 70), K(2.6, 70), K(2.95, 0)), add(\.armR, K(0, 0), K(0.3, 70), K(2.6, 70), K(2.95, 0)),
                osc(\.armL, from: 0.3, to: 2.7, amp: 25, cycles: 5), osc(\.armR, from: 0.3, to: 2.7, amp: 25, cycles: 5, phase: 1),
                bump(\.smileEyes, 0.8, from: 0, peak: 0.3, hold: 2.6, end: 2.95),
                bump(\.smile, 0.4, from: 0, peak: 0.3, hold: 2.6, end: 2.95),
                bump(\.sparkles, 1, from: 0.2, peak: 0.6, hold: 2.3, end: 2.9),
                osc(\.tail, from: 0, to: 2.9, amp: 1, cycles: 7),
            ])
        case .offerBall:
            // Glances off to find it, pops up holding it, holds it out to you, hopeful.
            return PetClip("offerBall", 4.0, fadeIn: 0.2, fadeOut: 0.35, [
                set(\.gazeX, K(0, 0), K(0.3, 0.85, .out), K(0.8, 0.85), K(1.0, 0), K(4.0, 0)),
                add(\.headTurn, K(0, 0), K(0.35, 0.4), K(0.8, 0.4), K(1.0, 0)),
                set(\.holdToy, K(0, 0), K(0.9, 0), K(0.92, 1, .linear), K(3.5, 1), K(3.52, 0, .linear), K(4.0, 0)),
                add(\.lift, K(0, 0), K(0.9, 0), K(1.05, 6, .out), K(1.25, 0, .in), K(4.0, 0)),
                set(\.armL, K(0, 0), K(0.9, 0), K(1.0, -40), K(3.4, -40), K(3.8, 0)),
                set(\.armR, K(0, 0), K(0.9, 0), K(1.0, -40), K(3.4, -40), K(3.8, 0)),
                bump(\.headTilt, 12, from: 1.0, peak: 1.4, hold: 3.2, end: 3.7),
                bump(\.eyeWide, 0.2, from: 1.0, peak: 1.3, hold: 3.2, end: 3.6),
                bump(\.smile, 0.45, from: 1.0, peak: 1.3, hold: 3.3, end: 3.8),
                set(\.gazeY, K(0, 0), K(1.0, -0.1), K(3.4, -0.1), K(3.9, 0)),
                osc(\.tail, from: 1.0, to: 3.6, amp: 1, cycles: s == .dog ? 9 : 3),
            ])
        case .blowBubble:
            // A deep breath, cheeks puffed, a slow blow; then it watches the bubbles rise.
            return PetClip("blowBubble", 4.2, fadeIn: 0.2, fadeOut: 0.4, [
                bump(\.breath, 0.8, from: 0, peak: 0.6, hold: 0.8, end: 1.4),
                bump(\.cheekPuff, 0.9, from: 0.4, peak: 0.8, hold: 1.0, end: 1.5),
                bump(\.mouthOpen, 0.25, from: 1.0, peak: 1.2, hold: 1.8, end: 2.1), bump(\.mouthRound, 1, from: 1.0, peak: 1.2, hold: 1.8, end: 2.1),
                bump(\.bubble, 1, from: 1.1, peak: 1.4, hold: 3.6, end: 4.1),
                set(\.gazeY, K(0, 0), K(1.8, 0), K(2.4, -0.8), K(3.8, -0.8), K(4.2, 0)),
                bump(\.headNod, -0.25, from: 1.9, peak: 2.4, hold: 3.6, end: 4.0),
                bump(\.smileEyes, 0.6, from: 2.3, peak: 2.7, hold: 3.6, end: 4.0),
                bump(\.smile, 0.4, from: 2.2, peak: 2.6, hold: 3.6, end: 4.0),
            ])
        case .hopeful:
            // Treat time? Big eyes, head on one side, a little bounce, licks its lips.
            return PetClip("hopeful", 3.0, fadeIn: 0.2, fadeOut: 0.4, [
                set(\.gazeX, K(0, 0), K(0.3, 0), K(3.0, 0)), set(\.gazeY, K(0, 0), K(0.3, -0.15), K(2.6, -0.15), K(3.0, 0)),
                bump(\.eyeWide, 0.28, from: 0, peak: 0.3, hold: 2.4, end: 2.9),
                bump(\.headTilt, 14, from: 0, peak: 0.45, hold: 2.3, end: 2.9),
                bump(\.smile, 0.5, from: 0, peak: 0.4, hold: 2.4, end: 2.9),
                add(\.lift, K(0, 0), K(0.6, 0), K(0.75, 4, .out), K(0.9, 0, .in), K(1.05, 4, .out), K(1.2, 0, .in), K(3.0, 0)),
                bump(\.mouthOpen, 0.3, from: 1.5, peak: 1.65, hold: 1.9, end: 2.1),
                bump(\.hearts, 0.6, from: 0.8, peak: 1.2, hold: 2.3, end: 2.8),
                osc(\.tail, from: 0.3, to: 2.8, amp: 1, cycles: s == .dog ? 8 : 3),
            ])
        case .batBall:
            return PetClip("batBall", 2.2, [
                set(\.gazeX, K(0, 0.8), K(2.2, 0.8)), set(\.gazeY, K(0, 0.6), K(2.2, 0.6)),
                add(\.armR, K(0, 0), K(0.35, 55, .out), K(0.55, 30, .in), K(0.8, 58, .out), K(1.0, 30, .in), K(1.6, 0)),
                add(\.lean, K(0, 0), K(0.35, 6), K(1.2, 6), K(1.7, 0)),
                bump(\.smileEyes, 0.6, from: 0.5, peak: 0.8, hold: 1.6, end: 2.1),
                bump(\.mouthOpen, 0.3, from: 0.5, peak: 0.8, hold: 1.5, end: 1.9),
                osc(\.tail, from: 0.2, to: 2.0, amp: 0.9, cycles: s == .dog ? 5 : 2),
            ])
        }
    }

    // MARK: Reactions

    /// The pet answers a mood you just logged: it mirrors you for a beat (Bible §4).
    public static func reaction(to mood: Mood, _ s: PetSpecies) -> PetClip {
        switch mood {
        case .happy:
            return PetClip("react.happy", 1.6, fadeIn: 0.05, [
                add(\.squash, K(0, 0), K(0.15, 0.25), K(0.38, -0.2, .out), K(0.6, 0.2, .in), K(0.8, 0)),
                add(\.lift, K(0, 0), K(0.15, 0), K(0.4, 12, .out), K(0.6, 0, .in)),
                add(\.armL, K(0, 0), K(0.15, -10), K(0.4, 115, .out), K(1.1, 90), K(1.5, 0)),
                add(\.armR, K(0, 0), K(0.15, -10), K(0.4, 115, .out), K(1.1, 90), K(1.5, 0)),
                set(\.smileEyes, K(0, 0), K(0.3, 1), K(1.2, 1), K(1.6, 0.4)),
                bump(\.mouthOpen, 0.7, from: 0.2, peak: 0.4, hold: 1.1, end: 1.5),
                bump(\.blush, 0.8, from: 0.2, peak: 0.5, hold: 1.3, end: 1.6),
                bump(\.hearts, 0.9, from: 0.3, peak: 0.6, hold: 1.2, end: 1.6),
                bump(\.earL, -0.4, from: 0.38, peak: 0.5, end: 0.9), bump(\.earR, -0.4, from: 0.38, peak: 0.5, end: 0.9),
            ])
        case .excited:
            return PetClip("react.excited", 2.0, fadeIn: 0.05, [
                add(\.squash, K(0, 0), K(0.22, 0.35), K(0.45, -0.3, .out), K(0.72, 0.3, .in), K(0.86, -0.1), K(1.02, 0.18, .in), K(1.3, 0)),
                add(\.lift, K(0, 0), K(0.22, 0), K(0.5, 22, .out), K(0.72, 0, .in), K(0.88, 7, .out), K(1.02, 0, .in)),
                add(\.armL, K(0, 0), K(0.22, -20), K(0.5, 155, .out), K(1.4, 140), K(1.9, 0)),
                add(\.armR, K(0, 0), K(0.22, -20), K(0.5, 155, .out), K(1.4, 140), K(1.9, 0)),
                set(\.smileEyes, K(0, 0), K(0.3, 1), K(1.6, 1), K(2.0, 0.3)),
                bump(\.mouthOpen, 1, from: 0.25, peak: 0.45, hold: 1.4, end: 1.9),
                bump(\.sparkles, 1, from: 0.3, peak: 0.6, hold: 1.5, end: 2.0),
                bump(\.earL, -0.6, from: 0.45, peak: 0.6, end: 1.0), bump(\.earR, -0.6, from: 0.45, peak: 0.6, end: 1.0),
                osc(\.tail, from: 0.4, to: 1.9, amp: 1, cycles: 5),
            ])
        case .calm:
            return PetClip("react.calm", 3.0, fadeIn: 0.3, fadeOut: 0.6, [
                add(\.breath, K(0, 0), K(1.3, 1.2), K(2.8, -0.1), K(3.0, 0)),
                add(\.headNod, K(0, 0), K(1.3, -0.25), K(2.8, 0.05), K(3.0, 0)),
                set(\.lidL, K(0, 0.2), K(1.1, 1), K(2.4, 1), K(3.0, 0.4)), set(\.lidR, K(0, 0.2), K(1.1, 1), K(2.4, 1), K(3.0, 0.4)),
                bump(\.smile, 0.4, from: 1.3, peak: 1.8, hold: 2.5, end: 3.0),
                bump(\.mouthRound, 0.8, from: 1.4, peak: 1.7, hold: 2.3, end: 2.6), bump(\.mouthOpen, 0.2, from: 1.4, peak: 1.7, hold: 2.3, end: 2.6),
            ])
        case .neutral:
            return PetClip("react.neutral", 1.6, [
                bump(\.earL, 0.6, from: 0, peak: 0.2, hold: 1.0, end: 1.5), bump(\.earR, 0.6, from: 0, peak: 0.2, hold: 1.0, end: 1.5),
                add(\.headNod, K(0, 0), K(0.3, 0.3), K(0.55, -0.05), K(0.8, 0.2), K(1.1, 0)),
                bump(\.browRaise, 0.7, from: 0, peak: 0.2, hold: 0.8, end: 1.3),
                set(\.gazeX, K(0, 0), K(1.6, 0)),
                bump(\.smile, 0.25, from: 0.3, peak: 0.6, hold: 1.1, end: 1.5),
            ])
        case .tired:
            return PetClip("react.tired", 2.6, fadeIn: 0.2, fadeOut: 0.6, [
                bump(\.headNod, -0.4, from: 0.1, peak: 0.6, hold: 1.4, end: 2.0),
                set(\.mouthOpen, K(0, 0), K(0.6, 1), K(1.4, 1), K(1.9, 0)), set(\.mouthRound, K(0, 0), K(0.6, 0.7), K(1.4, 0.7), K(1.9, 0)),
                set(\.lidL, K(0, 0.3), K(0.6, 1), K(1.6, 1), K(2.3, 0.6)), set(\.lidR, K(0, 0.3), K(0.6, 1), K(1.6, 1), K(2.3, 0.6)),
                add(\.armL, K(0, 0), K(0.6, 60), K(1.4, 60), K(2.0, 0)), add(\.armR, K(0, 0), K(0.6, 60), K(1.4, 60), K(2.0, 0)),
                add(\.slump, K(0, 0), K(0.6, -0.2), K(1.5, -0.2), K(2.2, 0.25), K(2.6, 0)),
                bump(\.breath, 1, from: 0.1, peak: 0.7, hold: 1.3, end: 2.0),
            ])
        case .stressed:
            return PetClip("react.stressed", 3.2, fadeIn: 0.04, fadeOut: 0.6, [
                add(\.squash, K(0, 0), K(0.1, 0.25, .out), K(0.5, 0.1), K(0.9, 0)),
                bump(\.lift, 3, from: 0, peak: 0.1, end: 0.35),
                bump(\.eyeWide, 0.35, from: 0, peak: 0.1, hold: 0.7, end: 1.1),
                bump(\.earL, -0.6, from: 0, peak: 0.1, hold: 0.9, end: 1.4), bump(\.earR, -0.6, from: 0, peak: 0.1, hold: 0.9, end: 1.4),
                bump(\.sweat, 1, from: 0.1, peak: 0.3, hold: 1.2, end: 1.8),
                add(\.breath, K(0, 0), K(1.0, 0), K(2.0, 1.1), K(3.1, 0)),
                set(\.lidL, K(0, 0), K(1.0, 0.1), K(1.8, 1), K(2.7, 1), K(3.2, 0.3)), set(\.lidR, K(0, 0), K(1.0, 0.1), K(1.8, 1), K(2.7, 1), K(3.2, 0.3)),
            ])
        case .sad:
            return PetClip("react.sad", 3.0, fadeIn: 0.3, fadeOut: 0.6, [
                add(\.headNod, K(0, 0), K(0.8, 0.3), K(1.0, 0.18, .out), K(1.15, 0.3), K(1.35, 0.2, .out), K(1.5, 0.3), K(2.4, 0.3), K(3.0, 0)),
                add(\.slump, K(0, 0), K(0.8, 0.25), K(2.4, 0.25), K(3.0, 0)),
                bump(\.tears, 0.9, from: 0.9, peak: 1.3, hold: 2.3, end: 2.9),
                bump(\.lidSlant, -0.3, from: 0.2, peak: 0.8, hold: 2.2, end: 2.9),
                set(\.gazeY, K(0, 0.2), K(0.8, 0.5), K(2.0, 0.5), K(2.5, -0.1), K(3.0, 0)),
                bump(\.smile, 0.3, from: 2.2, peak: 2.6, end: 3.0),
            ])
        case .frustrated:
            return PetClip("react.frustrated", 2.0, fadeIn: 0.05, [
                add(\.squash, K(0, 0), K(0.18, 0.2), K(0.3, -0.05), K(0.42, 0.28, .in), K(0.65, 0)),
                add(\.stepR, K(0, 0), K(0.28, 10, .out), K(0.42, 0, .in)),
                set(\.cheekPuff, K(0, 0), K(0.5, 1), K(1.2, 1), K(1.35, 0)),
                bump(\.steam, 1, from: 0.4, peak: 0.6, hold: 1.5, end: 1.9),
                bump(\.mouthOpen, 0.35, from: 1.25, peak: 1.4, hold: 1.55, end: 1.8), bump(\.mouthRound, 0.9, from: 1.25, peak: 1.4, hold: 1.55, end: 1.8),
                bump(\.headNod, 0.15, from: 0.38, peak: 0.45, end: 0.7),
                osc(\.x, from: 0.42, to: 0.9, amp: 1.5, cycles: 3),
            ])
        }
    }

    // MARK: Touch and presence

    /// Noticing you: eyes up, ears up, a wave or a hop depending on how it feels.
    public static func arrive(_ stance: PetStance, _ s: PetSpecies) -> PetClip {
        if stance.isAsleep {
            return sleepyHello(s)
        }
        let low = stance.energy < 0.3
        let wave: [PetClip.Track] = low ? [
            add(\.armR, K(0, 0), K(0.6, 70, .out), K(1.0, 55), K(1.4, 70), K(2.0, 0)),
        ] : [
            add(\.armR, K(0, 0), K(0.45, 135, .out), K(0.7, 115), K(0.95, 138), K(1.2, 115), K(1.45, 135), K(1.9, 0)),
        ]
        return PetClip("arrive", 2.2, fadeIn: 0.08, fadeOut: 0.5, wave + [
            set(\.gazeX, K(0, 0), K(2.2, 0)), set(\.gazeY, K(0, -0.15), K(2.2, -0.15)),
            add(\.headNod, K(0, 0), K(0.2, -0.2, .out), K(1.8, -0.1), K(2.2, 0)),
            bump(\.eyeWide, 0.22, from: 0, peak: 0.15, hold: 0.5, end: 0.9),
            bump(\.earL, 0.7, from: 0, peak: 0.15, hold: 1.0, end: 1.6), bump(\.earR, 0.7, from: 0, peak: 0.15, hold: 1.0, end: 1.6),
            bump(\.smileEyes, low ? 0.35 : 0.7, from: 0.3, peak: 0.6, hold: 1.7, end: 2.1),
            bump(\.smile, low ? 0.35 : 0.5, from: 0.3, peak: 0.6, hold: 1.7, end: 2.1),
            bump(\.lift, low ? 0 : 5, from: 0.1, peak: 0.28, end: 0.5),
            add(\.squash, K(0, 0), K(0.1, low ? 0 : 0.12), K(0.28, low ? 0 : -0.1), K(0.5, low ? 0 : 0.08), K(0.7, 0)),
            osc(\.tail, from: 0.2, to: 2.0, amp: low ? 0.3 : 1, cycles: s == .dog ? 6 : 2),
        ])
    }

    /// You came back after a few days: it hops twice with both arms up, then hugs itself happy.
    public static func missedYou(_ s: PetSpecies) -> PetClip {
        PetClip("missedYou", 3.4, fadeIn: 0.05, fadeOut: 0.6, [
            set(\.gazeX, K(0, 0), K(3.4, 0)), set(\.gazeY, K(0, -0.15), K(3.4, -0.15)),
            bump(\.eyeWide, 0.3, from: 0, peak: 0.12, hold: 0.35, end: 0.6),
            bump(\.exclaim, 1, from: 0, peak: 0.12, hold: 0.5, end: 0.8),
            add(\.squash, K(0, 0), K(0.45, 0.25), K(0.62, -0.25, .out), K(0.8, 0.22, .in), K(0.95, -0.2, .out), K(1.12, 0.2, .in), K(1.4, 0)),
            add(\.lift, K(0, 0), K(0.45, 0), K(0.66, 14, .out), K(0.8, 0, .in), K(0.98, 12, .out), K(1.12, 0, .in)),
            add(\.armL, K(0, 0), K(0.5, 150, .out), K(1.3, 150), K(1.7, -55), K(3.0, -55), K(3.4, 0)),
            add(\.armR, K(0, 0), K(0.5, 150, .out), K(1.3, 150), K(1.7, -55), K(3.0, -55), K(3.4, 0)),
            set(\.smileEyes, K(0, 0), K(0.5, 1), K(3.0, 1), K(3.4, 0.4)),
            bump(\.mouthOpen, 0.8, from: 0.4, peak: 0.6, hold: 1.3, end: 1.7),
            bump(\.blush, 1, from: 0.5, peak: 0.9, hold: 3.0, end: 3.4),
            bump(\.hearts, 1, from: 1.4, peak: 1.8, hold: 3.0, end: 3.4),
            osc(\.tail, from: 0.3, to: 3.2, amp: 1, cycles: s == .dog ? 10 : 3),
        ])
    }

    /// You opened the app while it was asleep: it half wakes, gives a drowsy little wave and a
    /// yawn, and settles back down.
    public static func sleepyHello(_ s: PetSpecies) -> PetClip {
        PetClip("sleepyHello", 4.4, fadeIn: 0.4, fadeOut: 0.8, [
            set(\.lidL, K(0, 1), K(0.8, 0.55), K(2.3, 0.55), K(2.6, 1), K(4.4, 1)),
            set(\.lidR, K(0, 1), K(0.9, 0.6), K(2.3, 0.6), K(2.6, 1), K(4.4, 1)),
            add(\.headNod, K(0, 0), K(0.8, -0.3), K(2.3, -0.25), K(3.4, 0)),
            add(\.armR, K(0, 0), K(1.0, 70, .out), K(1.3, 55), K(1.6, 70), K(2.1, 0)),
            set(\.mouthOpen, K(0, 0), K(2.4, 0), K(2.8, 0.8), K(3.4, 0.8), K(3.8, 0)),
            set(\.mouthRound, K(0, 0), K(2.4, 0), K(2.8, 0.8), K(3.4, 0.8), K(3.8, 0)),
            bump(\.smile, 0.35, from: 0.8, peak: 1.2, hold: 2.2, end: 2.6),
            set(\.zzz, K(0, 0.8), K(0.6, 0), K(3.6, 0), K(4.4, 0.8)),
        ])
    }

    /// A treat caught: snap, chew chew chew, a happy wiggle.
    public static func munch(_ s: PetSpecies) -> PetClip {
        PetClip("munch", 2.2, fadeIn: 0.03, fadeOut: 0.5, [
            set(\.mouthOpen, K(0, 0), K(0.08, 1, .out), K(0.2, 0), K(2.2, 0)),
            osc(\.cheekPuff, from: 0.25, to: 1.5, center: 0.5, amp: 0.4, cycles: 5),
            osc(\.headBob, from: 0.25, to: 1.5, amp: 1.2, cycles: 5),
            set(\.smileEyes, K(0, 0), K(0.2, 1), K(1.9, 1), K(2.2, 0.3)),
            bump(\.blush, 1, from: 0.2, peak: 0.5, hold: 1.8, end: 2.2),
            bump(\.hearts, 1, from: 1.3, peak: 1.6, hold: 1.9, end: 2.2),
            osc(\.x, from: 1.4, to: 2.1, amp: 2, cycles: 3),
            osc(\.tail, from: 0.2, to: 2.1, amp: 1, cycles: s == .dog ? 8 : 3),
        ])
    }

    /// You're writing: it leans in, ears up, and nods now and then.
    public static func listening(_ s: PetSpecies) -> PetClip {
        PetClip("listening", 1.8, fadeIn: 0.2, fadeOut: 0.5, [
            add(\.headNod, K(0, 0), K(0.3, 0.15), K(0.55, 0.05), K(0.8, 0.18), K(1.2, 0.08), K(1.8, 0)),
            bump(\.headTilt, 8, from: 0, peak: 0.3, hold: 1.3, end: 1.8),
            bump(\.earL, 0.5, from: 0, peak: 0.2, hold: 1.3, end: 1.8), bump(\.earR, 0.5, from: 0, peak: 0.2, hold: 1.3, end: 1.8),
            set(\.gazeX, K(0, 0), K(1.8, 0)), set(\.gazeY, K(0, 0.2), K(1.8, 0.2)),
            bump(\.smile, 0.25, from: 0.1, peak: 0.4, hold: 1.3, end: 1.8),
        ])
    }

    /// A shake: eyes squeeze, head wobbles, little stars, then a sheepish grin.
    public static func dizzy(_ s: PetSpecies) -> PetClip {
        PetClip("dizzy", 2.4, fadeIn: 0.03, fadeOut: 0.5, [
            set(\.squeeze, K(0, 0), K(0.05, 1), K(0.5, 1), K(0.6, 0)),
            osc(\.headTilt, from: 0.1, to: 1.8, amp: 14, cycles: 3),
            osc(\.lean, from: 0.1, to: 1.8, amp: 6, cycles: 3, phase: 1),
            bump(\.sparkles, 1, from: 0.1, peak: 0.3, hold: 1.6, end: 2.0),
            bump(\.eyeWide, 0.25, from: 0.6, peak: 0.7, hold: 1.4, end: 1.8),
            bump(\.smile, 0.6, from: 1.5, peak: 1.8, hold: 2.1, end: 2.4),
            bump(\.blush, 0.8, from: 1.5, peak: 1.8, hold: 2.1, end: 2.4),
        ])
    }

    /// One little hop.
    /// The day after a rough one: no bounce, just a soft lean toward you and a kind face.
    public static func gentleHello(_ s: PetSpecies) -> PetClip {
        PetClip("gentleHello", 3.2, fadeIn: 0.5, fadeOut: 0.8, [
            set(\.gazeX, K(0, 0), K(3.2, 0)), set(\.gazeY, K(0, -0.1), K(3.2, -0.1)),
            bump(\.lean, 5, from: 0, peak: 1.0, hold: 2.3, end: 3.1),
            bump(\.headTilt, 9, from: 0.2, peak: 1.1, hold: 2.3, end: 3.1),
            bump(\.smile, 0.35, from: 0.3, peak: 1.0, hold: 2.4, end: 3.1),
            bump(\.smileEyes, 0.45, from: 0.5, peak: 1.2, hold: 2.4, end: 3.1),
            bump(\.blush, 0.3, from: 0.5, peak: 1.2, hold: 2.4, end: 3.1),
            bump(\.hearts, 0.35, from: 0.9, peak: 1.4, hold: 2.3, end: 3.0),
            bump(\.earL, -0.2, from: 0.2, peak: 0.9, hold: 2.4, end: 3.1), bump(\.earR, -0.2, from: 0.2, peak: 0.9, hold: 2.4, end: 3.1),
        ])
    }

    /// Swatting at a bubble: a quick paw up, a little hop, a pop.
    public static func swat(_ s: PetSpecies, left: Bool = false) -> PetClip {
        PetClip("swat", 0.9, fadeIn: 0.03, fadeOut: 0.25, [
            add(left ? \.armL : \.armR, K(0, 0), K(0.14, 150, .out), K(0.4, 120), K(0.8, 0)),
            add(\.lift, K(0, 0), K(0.12, 5, .out), K(0.3, 0, .in), K(0.9, 0)),
            bump(\.eyeWide, 0.25, from: 0, peak: 0.1, hold: 0.3, end: 0.6),
            bump(\.mouthOpen, 0.5, from: 0.1, peak: 0.2, hold: 0.4, end: 0.7),
            bump(\.smile, 0.5, from: 0.2, peak: 0.35, hold: 0.6, end: 0.9),
            set(\.gazeY, K(0, -0.6), K(0.9, -0.3)),
        ])
    }

    public static func hop(_ s: PetSpecies) -> PetClip {
        PetClip("hop", 0.42, fadeIn: 0.02, fadeOut: 0.05, [
            add(\.lift, K(0, 0), K(0.08, 0), K(0.2, 8, .out), K(0.34, 0, .in), K(0.42, 0)),
            add(\.squash, K(0, 0), K(0.08, 0.15), K(0.2, -0.12), K(0.34, 0.15), K(0.42, 0)),
            add(\.armL, K(0, 0), K(0.2, s == .penguin ? 60 : 30), K(0.42, 0)), add(\.armR, K(0, 0), K(0.2, s == .penguin ? 60 : 30), K(0.42, 0)),
        ])
    }

    /// A tap on the head.
    public static func boop(_ s: PetSpecies) -> PetClip {
        PetClip("boop", 1.3, fadeIn: 0.03, fadeOut: 0.35, [
            set(\.squeeze, K(0, 0), K(0.05, 1), K(0.4, 1), K(0.5, 0)),
            add(\.headNod, K(0, 0), K(0.06, -0.3, .out), K(0.4, -0.2), K(0.6, 0.05), K(0.9, 0)),
            add(\.squash, K(0, 0), K(0.06, 0.16, .out), K(0.3, -0.05), K(0.5, 0)),
            add(\.earL, K(0, 0), K(0.06, -0.8, .out), K(0.5, 0.3), K(0.9, 0)), add(\.earR, K(0, 0), K(0.06, -0.8, .out), K(0.5, 0.3), K(0.9, 0)),
            set(\.smileEyes, K(0, 0), K(0.45, 0), K(0.6, 1), K(1.1, 1), K(1.3, 0.3)),
            bump(\.mouthOpen, 0.5, from: 0.45, peak: 0.6, hold: 1.0, end: 1.25),
            bump(\.blush, 0.9, from: 0.1, peak: 0.4, hold: 1.0, end: 1.3),
            bump(\.lift, 3, from: 0.55, peak: 0.68, end: 0.82),
        ])
    }

    /// A tap on the body.
    public static func tickle(_ s: PetSpecies) -> PetClip {
        PetClip("tickle", 1.4, fadeIn: 0.03, [
            osc(\.x, from: 0, to: 1.2, amp: 2.4, cycles: 4),
            osc(\.lean, from: 0, to: 1.2, amp: 6, cycles: 4, phase: 1),
            add(\.armL, K(0, 0), K(0.15, -45), K(1.0, -45), K(1.3, 0)), add(\.armR, K(0, 0), K(0.15, -45), K(1.0, -45), K(1.3, 0)),
            set(\.smileEyes, K(0, 0), K(0.1, 1), K(1.1, 1), K(1.4, 0.3)),
            bump(\.mouthOpen, 0.7, from: 0, peak: 0.12, hold: 1.0, end: 1.3),
            bump(\.blush, 1, from: 0, peak: 0.2, hold: 1.1, end: 1.4),
            osc(\.tail, from: 0, to: 1.3, amp: 1, cycles: 4),
        ])
    }

    /// Too many taps: covers its eyes, then peeks.
    public static func flustered(_ s: PetSpecies) -> PetClip {
        PetClip("flustered", 2.4, fadeIn: 0.05, fadeOut: 0.5, [
            set(\.armL, K(0, 0), K(0.25, -120, .out), K(1.9, -120), K(2.3, 0)),
            set(\.armR, K(0, 0), K(0.25, -120, .out), K(1.0, -120), K(1.2, -80), K(1.6, -80), K(1.8, -120), K(2.3, 0)),
            set(\.lidL, K(0, 0), K(0.25, 1), K(2.0, 1), K(2.3, 0)),
            set(\.lidR, K(0, 0), K(0.25, 1), K(1.05, 1), K(1.15, 0), K(1.65, 0), K(1.75, 1), K(2.0, 1), K(2.3, 0)),
            bump(\.blush, 1, from: 0, peak: 0.2, hold: 2.0, end: 2.4),
            bump(\.smile, 0.6, from: 0.2, peak: 0.5, hold: 2.0, end: 2.4),
            bump(\.slump, 0.3, from: 0, peak: 0.25, hold: 1.9, end: 2.3),
            bump(\.headTilt, -8, from: 1.0, peak: 1.2, hold: 1.6, end: 1.8),
        ])
    }

    /// After petting: a contented afterglow.
    public static func afterPetting(_ s: PetSpecies) -> PetClip {
        PetClip("afterPetting", 1.8, fadeIn: 0.05, fadeOut: 0.8, [
            set(\.smileEyes, K(0, 1), K(1.2, 0.8), K(1.8, 0.3)),
            bump(\.blush, 0.7, from: 0, peak: 0.1, hold: 1.0, end: 1.8),
            bump(\.hearts, 0.8, from: 0, peak: 0.1, hold: 0.8, end: 1.6),
            bump(\.smile, 0.5, from: 0, peak: 0.1, hold: 1.2, end: 1.8),
            bump(\.headTilt, 7, from: 0, peak: 0.1, hold: 0.8, end: 1.7),
            osc(\.tail, from: 0, to: 1.6, amp: 0.8, cycles: s == .dog ? 5 : 2),
        ])
    }

    /// A wave back (the Live Activity button, the watch).
    public static func wave(_ s: PetSpecies) -> PetClip {
        PetClip("wave", 2.0, fadeIn: 0.08, fadeOut: 0.5, [
            add(\.armR, K(0, 0), K(0.35, 135, .out), K(0.6, 112), K(0.85, 138), K(1.1, 112), K(1.35, 135), K(1.8, 0)),
            set(\.gazeX, K(0, 0), K(2.0, 0)),
            bump(\.smileEyes, 0.7, from: 0.1, peak: 0.4, hold: 1.5, end: 1.9),
            bump(\.smile, 0.5, from: 0.1, peak: 0.4, hold: 1.5, end: 1.9),
            bump(\.headTilt, 7, from: 0.1, peak: 0.4, hold: 1.5, end: 1.9),
        ])
    }
}
