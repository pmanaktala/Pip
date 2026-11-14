import CoreGraphics
import Foundation

/// Shared body space for drawing and inverse-kinematic paw targets. A parked object stays in
/// room coordinates while its paw is converted back through exactly the body's transform.
enum PetBodyGeometry {
    static func pose(_ source: PetPose, style: PetArtStyle) -> PetPose {
        var p = source
        let rest = style == .illustrated ? p.recline : 0
        p.lift *= 1 - rest; p.lean *= 1 - rest
        p.squash *= 1 - rest; p.slump *= 1 - rest
        return p
    }

    static func transform(_ source: PetPose, style: PetArtStyle) -> CGAffineTransform {
        let p = pose(source, style: style)
        let floor = PetFigure.floor
        let lean = CGFloat(p.lean * .pi / 180)
        var t = CGAffineTransform(translationX: CGFloat(p.x), y: -CGFloat(p.lift))
        // GraphicsContext's concatenation operates in its current local space.
        t = CGAffineTransform(a: 1, b: 0, c: -tan(lean) * 0.75, d: 1,
                             tx: tan(lean) * 0.75 * floor, ty: 0).concatenating(t)
        t = t.translatedBy(x: 100, y: floor).rotated(by: lean * 0.25)
        let squash = CGFloat(p.squash) * 0.14
        t = t.scaledBy(x: 1 + squash, y: 1 - squash - CGFloat(p.slump) * 0.05)
        return t.translatedBy(x: -100, y: -floor)
    }

    static func leftHand(_ pose: PetPose, species: PetSpecies, style: PetArtStyle) -> CGPoint {
        let f = PetFigure.of(species, style: style)
        let hand = f.paw(species, angle: pose.armL, pose: pose, side: -1)
        return CGPoint(x: 100 - hand.x, y: hand.y).applying(transform(pose, style: style))
    }
}

/// This checkpoint stages the reading objects. Their shelf is a physical support, not a
/// transition mask: objects remain visible there until grasped and after release.
public struct PetPropStage: Equatable, Sendable {
    var carried: PetProp?
    static let handled: Set<PetProp> = [.mug, .book]

    static func grip(for prop: PetProp) -> CGPoint {
        prop == .mug ? CGPoint(x: 22, y: 142) : CGPoint(x: 18, y: 166)
    }
}

struct PetPropHandlingFrame: Sendable {
    var pose: PetPose
    var prop: PetProp?
    var stage: PetPropStage
    var handling: Bool
}

/// A queued physical performance. A new request preserves the segment already under way,
/// drops unstarted work, then routes the held object back to its support before the latest
/// requested pickup. Reversing direction never replaces or dissolves an object in midair.
struct PetPropHandling: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case rest(PetProp), prepare(PetProp), putDown(PetProp), release(PetProp), reach(PetProp), pickUp(PetProp), settle(PetProp)

        var duration: Double {
            switch self {
            case .rest: 0.7
            case .prepare: 0.75
            case .putDown: 0.85
            case .release: 0.28
            case .reach: 0.48
            case .pickUp: 0.8
            case .settle: 0.22
            }
        }
        var prop: PetProp {
            switch self {
            case .rest(let p), .prepare(let p), .putDown(let p), .release(let p), .reach(let p), .pickUp(let p), .settle(let p): p
            }
        }
    }

    struct Step: Equatable, Sendable {
        var action: Action
        var start: Date
        var source: PetPose?
        var hand: CGPoint?
        var end: Date { start.addingTimeInterval(action.duration) }
    }

    private(set) var initial: PetProp?
    private(set) var target: PetProp?
    private(set) var steps: [Step] = []
    private var blendFrom: PetPose?
    private var blendSince = Date.distantPast

    init(prop: PetProp?) {
        initial = prop.flatMap { PetPropStage.handled.contains($0) ? $0 : nil }
        target = prop
    }

    var end: Date? { steps.last?.end }

    mutating func request(_ prop: PetProp?, at date: Date, source: PetPose,
                          species: PetSpecies, style: PetArtStyle) {
        guard prop != target else { return }
        let current = frame(at: date, base: source, fallback: target, species: species, style: style)
        // A newly requested mood can have a different whole-body pose. Rebase that pose
        // continuously as well as preserving the active carry, including repeated interruptions.
        blendFrom = effectiveBase(source, at: date)
        blendSince = date
        target = prop
        // Only retain work actually under way. Roll completed work into the room's current
        // ownership so the plan stays bounded even after hundreds of mood changes.
        let completed = steps.filter { $0.end <= date }
        let active = steps.first { $0.start <= date && date < $0.end }
        var held = initial
        for s in completed {
            switch s.action {
            case .putDown, .release: held = nil
            case .pickUp(let p), .settle(let p): held = p
            case .rest, .prepare, .reach: break
            }
        }
        initial = held
        steps = active.map { [$0] } ?? []
        var cursor = max(date, active?.end ?? date)
        held = heldAfterSteps()
        let desired = prop.flatMap { PetPropStage.handled.contains($0) ? $0 : nil }
        if let active {
            switch active.action {
            case .prepare(let p):
                if desired == nil { append(.rest(p), at: &cursor) }
            case .putDown(let p): append(.release(p), at: &cursor)
            case .pickUp(let p): append(.settle(p), at: &cursor)
            case .reach(let p):
                if desired == p {
                    append(.pickUp(p), at: &cursor)
                    append(.settle(p), at: &cursor)
                    return
                }
                append(.release(p), at: &cursor)
            default: break
            }
        }
        if held != desired {
            if let held {
                let immediate = cursor == date
                append(.putDown(held), at: &cursor, source: immediate ? current.pose : nil,
                       hand: immediate ? PetBodyGeometry.leftHand(current.pose, species: species, style: style) : nil)
                append(.release(held), at: &cursor)
            }
            if let desired {
                if current.pose.recline > 0.05, active == nil {
                    append(.prepare(desired), at: &cursor, source: current.pose)
                }
                append(.reach(desired), at: &cursor)
                append(.pickUp(desired), at: &cursor)
                append(.settle(desired), at: &cursor)
            }
        }
    }

    private mutating func append(_ action: Action, at date: inout Date, source: PetPose? = nil, hand: CGPoint? = nil) {
        steps.append(Step(action: action, start: date, source: source, hand: hand))
        date = date.addingTimeInterval(action.duration)
    }

    private func heldAfterSteps() -> PetProp? {
        var held = initial
        for s in steps {
            switch s.action {
            case .putDown, .release: held = nil
            case .pickUp(let p), .settle(let p): held = p
            case .rest, .prepare, .reach: break
            }
        }
        return held
    }

    private func effectiveBase(_ base: PetPose, at date: Date) -> PetPose {
        guard let blendFrom else { return base }
        return PetPose.mix(blendFrom, base, PetMath.smoothstep(date.timeIntervalSince(blendSince) / 0.35))
    }

    func frame(at date: Date, base source: PetPose, fallback: PetProp?, species: PetSpecies, style: PetArtStyle) -> PetPropHandlingFrame {
        let base = effectiveBase(source, at: date)
        var held = initial
        for s in steps {
            if date < s.start { break }
            if date >= s.end {
                switch s.action {
                case .putDown, .release: held = nil
                case .pickUp(let p), .settle(let p): held = p
                case .rest, .prepare, .reach: break
                }
                continue
            }
            let t = PetMath.smoothstep(date.timeIntervalSince(s.start) / s.action.duration)
            let prop = s.action.prop
            let shelf = PetPropStage.grip(for: prop)
            var pose = base
            let supported = PetContact.pose(base, holding: prop, species: species)
            var upright = supported
            upright.recline = 0
            upright.propLift = 0
            let grip = PetBodyGeometry.leftHand(upright, species: species, style: style)
            var hand: CGPoint
            var active: PetProp?
            var reachWeight = 0.0
            switch s.action {
            case .rest:
                pose.recline = base.recline * t
                pose.leftHandIK = 0
                return PetPropHandlingFrame(pose: pose.clamped(), prop: nil, stage: PetPropStage(carried: nil), handling: true)
            case .prepare:
                pose = PetPose.mix(s.source ?? base, base, t)
                pose.recline = (s.source?.recline ?? 0) * (1 - t)
                pose.leftHandIK = 0
                return PetPropHandlingFrame(pose: pose.clamped(), prop: nil, stage: PetPropStage(carried: nil), handling: true)
            case .putDown:
                reachWeight = t
                if let source = s.source { pose = PetPose.mix(source, base, t) }
                pose.recline = 0
                pose.propLift = (s.source?.propLift ?? base.propLift) * (1 - t)
                var sourceGrip = supported
                sourceGrip.recline = 0
                let start = s.hand ?? PetBodyGeometry.leftHand(sourceGrip, species: species, style: style)
                hand = Self.carry(from: start, to: shelf, progress: t)
                pose.bookClose = min(1, t * 1.8)
                active = prop
            case .release:
                reachWeight = 1 - t
                pose.recline = base.recline * t
                hand = Self.mix(shelf, PetBodyGeometry.leftHand(base, species: species, style: style), t)
                active = nil
            case .reach:
                reachWeight = t
                pose.recline = 0
                hand = Self.mix(PetBodyGeometry.leftHand(pose, species: species, style: style), shelf, t)
                active = nil
            case .pickUp:
                reachWeight = 1 - t
                pose.recline = 0; pose.propLift = 0
                hand = Self.carry(from: shelf, to: grip, progress: t)
                pose.bookClose = 1 - PetMath.smoothstep((t - 0.35) / 0.65)
                active = prop
            case .settle:
                pose = PetContact.pose(base, holding: prop, species: species)
                pose.recline = 0
                pose.propLift *= t
                hand = PetBodyGeometry.leftHand(pose, species: species, style: style)
                active = prop
            }
            pose.lean -= 16 * reachWeight
            pose.slump += 0.35 * reachWeight
            pose.headNod += 0.2 * reachWeight
            pose.gazeX -= 0.6 * reachWeight
            pose.gazeY += 0.4 * reachWeight
            pose.leftHandX = hand.x; pose.leftHandY = hand.y; pose.leftHandIK = 1
            // Put the supporting limb in front; the other paw keeps its normal acting.
            pose.armL = -45
            return PetPropHandlingFrame(pose: pose.clamped(), prop: active,
                                        stage: PetPropStage(carried: active), handling: true)
        }
        let prop = held ?? (fallback.flatMap { PetPropStage.handled.contains($0) ? nil : $0 })
        return PetPropHandlingFrame(pose: base, prop: prop, stage: PetPropStage(carried: held), handling: false)
    }

    private static func mix(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private static func carry(from a: CGPoint, to b: CGPoint, progress t: Double) -> CGPoint {
        let p = mix(a, b, t)
        // A short lift clears the support; easing lands with zero speed and no penetration.
        return CGPoint(x: p.x, y: p.y - CGFloat(sin(t * .pi)) * 8)
    }
}
