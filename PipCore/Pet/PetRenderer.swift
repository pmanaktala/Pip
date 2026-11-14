import SwiftUI

public enum PetArtStyle: String, Codable, CaseIterable, Sendable {
    case original, illustrated
}

/// How much of the pet to draw, and at what level of detail.
public enum PetDetail: Sendable {
    /// Whole pet, every mark (≥ 90 pt).
    case full
    /// Head and shoulders (40–90 pt): no props on the floor, no whiskers.
    case face
    /// Head only, simplified and heavier (≤ 40 pt): badges, complications, the Dynamic Island.
    case badge
}

/// Everything the renderer needs besides the canvas.
public struct PetPaint {
    public var species: PetSpecies
    public var style: PetArtStyle
    public var pose: PetPose
    public var prop: PetProp?
    public var wear: PetWear?
    public var neck: PetNeck?
    public var extra: PetExtra?
    public var sign: PetSign?
    public var detail: PetDetail
    /// Seconds, for things that drift (steam, notes, zzz). `nil` draws them at rest.
    public var time: Double?
    public var palette: PetPalette

    public init(species: PetSpecies, pose: PetPose, prop: PetProp? = nil, wear: PetWear? = nil, detail: PetDetail = .full, time: Double? = nil, monochrome: Bool = false,
                neck: PetNeck? = nil, extra: PetExtra? = nil, sign: PetSign? = nil, style: PetArtStyle = .illustrated) {
        self.style = style
        self.neck = neck
        self.extra = extra
        self.sign = sign
        self.species = species
        self.pose = PetContact.pose(pose.clamped(), holding: prop, species: species)
        self.prop = prop
        self.wear = wear
        self.detail = detail
        self.time = time
        self.palette = monochrome ? .monochrome(for: species) : .palette(for: species)
        self.monochrome = monochrome
    }

    /// Tinted watch faces: everything, hats included, is drawn in greys so the tint reads.
    public var monochrome = false

    /// Rim width in design units: heavier as the pet gets smaller so it still reads.
    var rim: CGFloat { style == .illustrated ? (detail == .badge ? 1.1 : 0.55) : (detail == .badge ? 2.2 : 1.5) }
    var ink: CGFloat { style == .illustrated ? (detail == .badge ? 2.6 : 1.8) : (detail == .badge ? 3.6 : 2.4) }
}

/// Where a species' parts sit in the 200 × 200 design space (floor at y = 170).
struct PetFigure {
    var headCenter: CGPoint
    var headRX: CGFloat
    var headRY: CGFloat
    /// The head tilts about this point.
    var neck: CGPoint
    var shoulder: CGPoint
    var eyeX: CGFloat
    var eyeY: CGFloat
    var eyeW: CGFloat
    var eyeH: CGFloat
    var mouthY: CGFloat
    var blushX: CGFloat
    var blushY: CGFloat

    var style: PetArtStyle = .original

    static let floor: CGFloat = 170

    static func of(_ species: PetSpecies, style: PetArtStyle = .original) -> PetFigure {
        var figure: PetFigure = switch species {
        case .penguin:
            PetFigure(headCenter: CGPoint(x: 100, y: 70), headRX: 37, headRY: 36.5, neck: CGPoint(x: 100, y: 100), shoulder: CGPoint(x: 36, y: 104),
                      eyeX: 14.5, eyeY: 1, eyeW: 7.2, eyeH: 9.6, mouthY: 13, blushX: 18.5, blushY: 11.5)
        case .cat:
            PetFigure(headCenter: CGPoint(x: 100, y: 76), headRX: 46, headRY: 33.5, neck: CGPoint(x: 100, y: 104), shoulder: CGPoint(x: 29, y: 112),
                      eyeX: 19, eyeY: 0, eyeW: 8, eyeH: 10.5, mouthY: 16, blushX: 25, blushY: 10)
        case .dog:
            PetFigure(headCenter: CGPoint(x: 100, y: 75), headRX: 43, headRY: 38, neck: CGPoint(x: 100, y: 104), shoulder: CGPoint(x: 30, y: 112),
                      eyeX: 15.5, eyeY: 0, eyeW: 9, eyeH: 10.6, mouthY: 20, blushX: 23, blushY: 10)
        }
        figure.style = style
        if style == .illustrated {
            figure.headRX = species == .penguin ? 43 : (species == .cat ? 44 : 42)
            figure.headRY = species == .penguin ? 41 : (species == .cat ? 37 : 39)
            figure.eyeX = species == .cat ? 18 : 17
            figure.eyeW = species == .penguin ? 13 : 14
            figure.eyeH = species == .penguin ? 19 : 20
        }
        return figure
    }

    /// Where the right paw (or flipper tip) is for an arm angle, as an offset from the centre
    /// line. Arms follow a designed arc of key positions rather than a rigid rotation, so a paw
    /// at the chest bends the elbow and a paw overhead reaches.
    func paw(_ species: PetSpecies, angle: Double) -> CGPoint {
        let keys: [(Double, CGPoint)]
        switch species {
        case .penguin:
            keys = [(-130, CGPoint(x: 13, y: 72)), (-110, CGPoint(x: 15, y: 80)), (-80, CGPoint(x: 10, y: 106)), (-55, CGPoint(x: 15, y: 123)),
                    (-40, CGPoint(x: 20, y: 132)), (-20, CGPoint(x: 30, y: 140)), (0, CGPoint(x: 46, y: 139)), (45, CGPoint(x: 66, y: 128)), (90, CGPoint(x: 73, y: 104)),
                    (135, CGPoint(x: 63, y: 78)), (175, CGPoint(x: 44, y: 66))]
        case .cat, .dog:
            // Mitten arms: hanging at the side, onto the belly, to the chest, to the face; out and up.
            keys = [(-130, CGPoint(x: 15, y: 70)), (-110, CGPoint(x: 19, y: 80)), (-85, CGPoint(x: 11, y: 108)), (-55, CGPoint(x: 13, y: 124)),
                    (-40, CGPoint(x: 17, y: 130)), (-20, CGPoint(x: 26, y: 138)), (0, CGPoint(x: 36, y: 140)), (45, CGPoint(x: 54, y: 128)),
                    (90, CGPoint(x: 66, y: 106)), (135, CGPoint(x: 64, y: 82)), (175, CGPoint(x: 54, y: 62))]
        }
        if style == .illustrated, species != .penguin, angle > -20, angle < 45 {
            let t = CGFloat((angle + 20) / 65)
            let start = keys.first(where: { $0.0 == -20 })!.1
            let rest = CGPoint(x: 21, y: 158)
            let raised = CGPoint(x: 54, y: 128)
            if t < 20.0 / 65 {
                let u = t / (20.0 / 65)
                return CGPoint(x: start.x + (rest.x - start.x) * u, y: start.y + (rest.y - start.y) * u)
            }
            let u = (t - 20.0 / 65) / (45.0 / 65)
            return CGPoint(x: rest.x + (raised.x - rest.x) * u, y: rest.y + (raised.y - rest.y) * u)
        }
        let a = angle.clamped(keys.first!.0, keys.last!.0)
        for i in 0..<(keys.count - 1) where a <= keys[i + 1].0 {
            let (a0, p0) = keys[i], (a1, p1) = keys[i + 1]
            let t = CGFloat(PetMath.smoothstep((a - a0) / (a1 - a0)) * 0.35 + (a - a0) / (a1 - a0) * 0.65)
            return CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t)
        }
        return keys.last!.1
    }
}

/// Draws a pet. Shared by every surface: the live views, widgets, Live Activities, the watch,
/// complications and the icon.
public enum PetRenderer {
    public static func draw(_ ctx: GraphicsContext, _ source: PetPaint, showsShadow: Bool = true) {
        var p = source
        let sleeping = p.style == .illustrated && p.pose.recline > 0
        let recline = sleeping && p.detail == .full ? p.pose.recline : 0
        if sleeping {
            // Face crops stay centered on the face, even when the full-body pose lies down.
            if p.detail != .full { p.pose.recline = 0 }
            // This cast sleeps in pajamas; a blanket must not stand upright over its lying body.
            if p.prop == .blanket { p.prop = nil }
            if p.wear == nil { p.wear = .nightcap }
        }
        var pose = p.pose
        pose.lift *= 1 - recline
        pose.lean *= 1 - recline
        pose.squash *= 1 - recline
        pose.slump *= 1 - recline
        let fig = PetFigure.of(p.species, style: p.style)
        let floor = PetFigure.floor

        if showsShadow && p.detail == .full {
            let spread = CGFloat(1 - min(pose.lift, 30) / 60)
            let w: CGFloat = ((p.species == .penguin ? 62 : 74) + CGFloat(recline) * 16) * spread * CGFloat(1 + pose.squash * 0.2)
            ctx.fill(PetDraw.ellipse(CGPoint(x: 100 + pose.x, y: floor + 1.5), w, 5.5 * spread), PetRGB(0.10, 0.08, 0.16, 0.16 * Double(spread)))
        }

        // The body transform: lift, then a lean sheared over the feet, then squash about the floor.
        var body = ctx
        body.translateBy(x: CGFloat(pose.x), y: -CGFloat(pose.lift))
        let lean = CGFloat(pose.lean * .pi / 180)
        body.concatenate(CGAffineTransform(a: 1, b: 0, c: -tan(lean) * 0.75, d: 1, tx: tan(lean) * 0.75 * floor, ty: 0))
        body.translateBy(x: 100, y: floor)
        body.rotate(by: .radians(Double(lean) * 0.25))
        let sq = CGFloat(pose.squash) * 0.14
        body.scaleBy(x: 1 + sq, y: 1 - sq - CGFloat(pose.slump) * 0.05)
        body.translateBy(x: -100, y: -floor)

        // The head settles onto its pillow as the body reclines. Its floor contact
        // is fixed; breathing moves the chest, rather than lifting a sleeping pet.
        var head = body
        let rest = CGFloat(recline)
        let headDrop = CGFloat(pose.headBob + pose.slump * 9 - pose.breath * 1.4) * (1 - rest)
        head.translateBy(x: CGFloat(pose.turn) * 2 * (1 - rest) - 36 * rest,
                         y: headDrop + (133 - fig.headCenter.y) * rest)
        head.translateBy(x: fig.neck.x, y: fig.neck.y)
        head.rotate(by: .degrees((pose.headTilt + pose.lean * 0.35) * (1 - recline) + (-7 + (pose.headTilt + 12) * 0.12) * recline))
        head.translateBy(x: -fig.neck.x, y: -fig.neck.y)
        head.translateBy(x: fig.headCenter.x, y: fig.headCenter.y)
        head.scaleBy(x: 1 - 0.26 * rest, y: 1 - 0.26 * rest)

        switch p.detail {
        case .badge:
            drawHead(head, p, fig)
        case .face, .full:
            if p.style == .illustrated {
                IllustratedPetArt.body(body, p, fig)
            } else {
                switch p.species {
                case .penguin: PenguinArt.body(body, p, fig)
                case .cat, .dog: QuadrupedArt.body(body, p, fig)
                }
            }
            // Floor props stay on the floor: they are drawn in the room, not with the body, so a
            // hop or a lean never lifts them. Held props go through the body transform with the paws.
            if let extra = p.extra, p.detail == .full { PetPropArt.extra(ctx, p, extra) }
            if let prop = p.prop, prop.onFloor, prop.drawnBehindArms { PetPropArt.held(ctx, p, fig, prop) }
            if let prop = p.prop, !prop.onFloor, prop.drawnBehindArms { PetPropArt.held(body, p, fig, prop) }
            drawArms(body, p, fig, front: false)
            if let neck = p.neck, p.prop != .blanket || neck == .travelPillow { PetPropArt.neck(body, p, fig, neck) }
            drawHead(head, p, fig)
            if let prop = p.prop, !prop.drawnBehindArms, !prop.drawnInFront { PetPropArt.held(body, p, fig, prop) }
            drawArms(body, p, fig, front: true)
            if let prop = p.prop, prop.drawnInFront { PetPropArt.held(prop.onFloor ? ctx : body, p, fig, prop) }
        }
        var effectFigure = fig
        effectFigure.headCenter.x -= 36 * CGFloat(recline)
        effectFigure.headCenter.y += (133 - fig.headCenter.y) * CGFloat(recline)
        effectFigure.headRY *= 1 - 0.26 * CGFloat(recline)
        PetEffects.draw(ctx, body: body, head: head, p, effectFigure)
    }

    static func drawHead(_ head: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        if p.style == .illustrated {
            IllustratedPetArt.head(head, p, fig)
        } else {
            switch p.species {
            case .penguin: PenguinArt.head(head, p, fig)
            case .cat: CatArt.head(head, p, fig)
            case .dog: DogArt.head(head, p, fig)
            }
        }
        if let wear = p.wear {
            var worn = head
            if p.monochrome { worn.addFilter(.saturation(0)) }
            PetPropArt.worn(worn, p, fig, wear)
        }
    }

    /// Arms at the side (angle ≥ 0) sit under the head; folded arms (angle < 0) cross in front of it.
    static func drawArms(_ body: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, front: Bool) {
        let pose = p.pose
        PetDraw.mirrored(body, axis: 100) { ctx, side in
            let angle = side > 0 ? pose.armR : pose.armL
            guard (angle < -8) == front else { return }
            if p.style == .illustrated {
                IllustratedPetArt.arm(ctx, p, fig, angle: angle, side: side)
            } else {
                switch p.species {
                case .penguin: PenguinArt.flipper(ctx, p, fig, angle: angle)
                case .cat, .dog: QuadrupedArt.foreleg(ctx, p, fig, angle: angle)
                }
            }
        }
    }
}
