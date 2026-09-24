import SwiftUI

/// The few things a pet holds. Each belongs to a stance (Bible §4) and is drawn in the pet's own
/// transform so it moves with the body, in the paws. At most one at a time.
public enum PetProp: String, Codable, Sendable, Hashable, CaseIterable {
    /// A warm mug held at the chest (calm, the evening). Rises to the mouth for a sip.
    case mug
    /// A book held open in both paws (reading).
    case book
    /// A blanket round the shoulders (tired, sad).
    case blanket
    /// A ball on the floor beside the pet (playing).
    case ball
    /// A small laptop on the floor, lid toward the pet (working).
    case laptop
    /// The ball, carried back in its paws.
    case heldBall

    /// Drawn after the body and before the arms (the paws go over or beside it).
    var drawnBehindArms: Bool { self == .blanket || self == .ball }
    /// Drawn over everything else: the pet works behind it.
    var drawnInFront: Bool { self == .laptop }
    /// Rests on the floor rather than in the paws.
    var onFloor: Bool { self == .laptop || self == .ball }
}

/// The one thing a pet may wear on its head, on top of any held prop.
public enum PetWear: String, Codable, Sendable, Hashable, CaseIterable {
    /// Bedtime: from 21:30 until morning, and whenever it sleeps.
    case nightcap
    /// You're listening to something, or have headphones in.
    case headphones
    /// New Year, and the anniversary of the day you met.
    case partyHat

    /// What the pet wears on its head (see `PetDressing.choose` for the whole outfit).
    public static func choose(for stance: PetStance, at date: Date, music: Bool, calendar: Calendar = .current) -> PetWear? {
        var context = PetContext()
        context.audioPlaying = music
        return PetDressing.choose(for: stance, at: date, context: context, calendar: calendar).head
    }
}

enum PetPropArt {
    static func held(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, _ prop: PetProp) {
        switch prop {
        case .mug: mug(ctx, p, fig)
        case .book: book(ctx, p, fig)
        case .blanket: blanket(ctx, p, fig)
        case .ball: ball(ctx, p)
        case .laptop: laptop(ctx, p)
        case .heldBall:
            let c = between(p, fig)
            let ball = PetDraw.ellipse(CGPoint(x: c.x, y: c.y - 4), 10, 10)
            PetDraw.solid(ctx, ball, p.palette.prop, rim: p.rim, depth: 3)
        }
    }

    static func worn(_ head: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, _ wear: PetWear) {
        switch wear {
        case .nightcap: nightcap(head, p, fig)
        case .headphones: headphones(head, p, fig)
        case .partyHat: partyHat(head, p, fig)
        }
    }

    /// A striped cone with a pompom, a little to one side.
    static func partyHat(_ head: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let ry = fig.headRY
        var hat = head
        hat.translateBy(x: fig.headRX * 0.28, y: -ry * 0.82)
        hat.rotate(by: .degrees(14))
        var cone = Path()
        cone.move(to: CGPoint(x: -13, y: 4))
        cone.addLine(to: CGPoint(x: 0, y: -30))
        cone.addLine(to: CGPoint(x: 13, y: 4))
        cone.addQuadCurve(to: CGPoint(x: -13, y: 4), control: CGPoint(x: 0, y: 9))
        let blue = PetRGB(0.42, 0.62, 0.95), pink = PetRGB(0.98, 0.52, 0.62)
        PetDraw.solid(hat, cone, blue, rim: p.rim, depth: 3)
        var stripes = hat
        stripes.clip(to: cone)
        for y in stride(from: -24.0, through: 4.0, by: 9.0) {
            stripes.fill(Path(CGRect(x: -16, y: y, width: 32, height: 3.6)), pink)
        }
        PetDraw.solid(hat, PetDraw.fluffy(CGPoint(x: 0, y: -31), 4.5, 4.5, bumps: 6, depth: 0.8), PetRGB(1.0, 0.84, 0.35), rim: p.rim * 0.8, depth: 1.5)
    }

    /// Round the neck, under the chin: drawn after the body and before the head.
    static func neck(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, _ neck: PetNeck) {
        let y = fig.neck.y + 1 + CGFloat(p.pose.headBob * 0.5 + p.pose.slump * 6)
        let w = fig.headRX * 0.86
        switch neck {
        case .scarf:
            let red = PetRGB(0.90, 0.36, 0.34)
            let band = Path(roundedRect: CGRect(x: 100 - w, y: y - 6, width: w * 2, height: 12), cornerSize: CGSize(width: 6, height: 6), style: .continuous)
            PetDraw.solid(ctx, band, red, rim: p.rim, depth: 3)
            var tail = Path()
            tail.move(to: CGPoint(x: 100 + w * 0.35, y: y + 2))
            tail.addLine(to: CGPoint(x: 100 + w * 0.62, y: y + 2))
            tail.addLine(to: CGPoint(x: 100 + w * 0.58, y: y + 24))
            tail.addLine(to: CGPoint(x: 100 + w * 0.36, y: y + 22))
            tail.closeSubpath()
            PetDraw.solid(ctx, tail, red, rim: p.rim, depth: 2)
            // Knit stripes and a fringe.
            for dx in stride(from: -w + 6, to: w - 3, by: 8) {
                var knit = Path()
                knit.move(to: CGPoint(x: 100 + dx, y: y - 4))
                knit.addLine(to: CGPoint(x: 100 + dx + 2, y: y + 4))
                ctx.stroke(knit, red.shade, width: 1.2)
            }
            for i in 0..<3 {
                var fringe = Path()
                let x = 100 + w * 0.4 + CGFloat(i) * 3.2
                fringe.move(to: CGPoint(x: x, y: y + 22))
                fringe.addLine(to: CGPoint(x: x, y: y + 27))
                ctx.stroke(fringe, red, width: 1.6)
            }
        case .travelPillow:
            let blue = PetRGB(0.55, 0.70, 0.92)
            var u = Path()
            u.move(to: CGPoint(x: 100 - w * 1.02, y: y - 12))
            u.addQuadCurve(to: CGPoint(x: 100 + w * 1.02, y: y - 12), control: CGPoint(x: 100, y: y + 26))
            ctx.stroke(u, blue.rim, width: 15 + p.rim * 2)
            ctx.stroke(u, blue, width: 15)
            var shine = Path()
            shine.move(to: CGPoint(x: 100 - w * 0.9, y: y - 12))
            shine.addQuadCurve(to: CGPoint(x: 100 - w * 0.3, y: y + 6), control: CGPoint(x: 100 - w * 0.75, y: y + 4))
            ctx.stroke(shine, PetRGB(1, 1, 1, 0.45), width: 3)
        }
    }

    /// On the floor to the pet's right (our left).
    static func extra(_ ctx: GraphicsContext, _ p: PetPaint, _ extra: PetExtra) {
        let floor = PetFigure.floor
        switch extra {
        case .suitcase:
            let body = CGRect(x: 18, y: floor - 30, width: 34, height: 28)
            let color = PetRGB(0.86, 0.52, 0.36)
            var handle = Path()
            handle.addRoundedRect(in: CGRect(x: 28, y: floor - 36, width: 14, height: 9), cornerSize: CGSize(width: 4, height: 4))
            ctx.stroke(handle, color.rim, width: 4.4)
            ctx.stroke(handle, PetRGB(0.35, 0.28, 0.26), width: 2.6)
            let box = Path(roundedRect: body, cornerSize: CGSize(width: 5, height: 5), style: .continuous)
            PetDraw.solid(ctx, box, color, rim: p.rim, depth: 4)
            for x in [body.minX + 8, body.maxX - 8] {
                ctx.fill(Path(CGRect(x: x - 1.5, y: body.minY, width: 3, height: body.height)), color.shade)
            }
            // A sticker from somewhere.
            ctx.fill(PetDraw.ellipse(CGPoint(x: body.midX + 1, y: body.midY + 2), 5, 4), PetRGB(0.98, 0.94, 0.86))
            ctx.fill(PetDraw.ellipse(CGPoint(x: body.midX + 1, y: body.midY + 2), 2.2, 2.2), p.palette.prop)
        case .cake:
            let t = p.time ?? 0.3
            let plate = PetDraw.ellipse(CGPoint(x: 36, y: floor - 3), 20, 4)
            PetDraw.solid(ctx, plate, PetRGB(0.96, 0.96, 0.98), rim: p.rim, depth: 1.5)
            let cake = Path(roundedRect: CGRect(x: 21, y: floor - 24, width: 30, height: 20), cornerSize: CGSize(width: 4, height: 4), style: .continuous)
            PetDraw.solid(ctx, cake, PetRGB(0.98, 0.82, 0.86), rim: p.rim, depth: 3)
            var icing = Path()
            icing.move(to: CGPoint(x: 21, y: floor - 19))
            for i in 0..<5 {
                let x = 21 + CGFloat(i) * 6
                icing.addQuadCurve(to: CGPoint(x: x + 6, y: floor - 19), control: CGPoint(x: x + 3, y: floor - 14))
            }
            icing.addLine(to: CGPoint(x: 51, y: floor - 24))
            icing.addLine(to: CGPoint(x: 21, y: floor - 24))
            icing.closeSubpath()
            ctx.fill(icing, PetRGB(1, 1, 0.98))
            ctx.fill(Path(roundedRect: CGRect(x: 34.5, y: floor - 36, width: 3, height: 12), cornerSize: CGSize(width: 1, height: 1)), PetRGB(0.42, 0.62, 0.95))
            let flicker = CGFloat(sin(t * 13) * 0.6)
            var flame = Path()
            flame.move(to: CGPoint(x: 36 + flicker, y: floor - 44))
            flame.addQuadCurve(to: CGPoint(x: 36, y: floor - 36), control: CGPoint(x: 39.5, y: floor - 38))
            flame.addQuadCurve(to: CGPoint(x: 36 + flicker, y: floor - 44), control: CGPoint(x: 32.5, y: floor - 38))
            ctx.fill(flame, PetRGB(1.0, 0.72, 0.25))
        }
    }

    /// A little laptop on the floor with its lid toward the pet: we see the back of the screen
    /// (a paw on it) and the pet peeks over the top.
    static func laptop(_ ctx: GraphicsContext, _ p: PetPaint) {
        let floor = PetFigure.floor
        let metal = PetRGB(0.86, 0.88, 0.92)
        let base = Path(roundedRect: CGRect(x: 60, y: floor - 9, width: 80, height: 8), cornerSize: CGSize(width: 3, height: 3), style: .continuous)
        PetDraw.solid(ctx, base, metal.mix(PetRGB(0.5, 0.52, 0.6), 0.25), rim: p.rim, depth: 2)
        let lid = Path(roundedRect: CGRect(x: 66, y: floor - 44, width: 68, height: 37), cornerSize: CGSize(width: 5, height: 5), style: .continuous)
        PetDraw.solid(ctx, lid, metal, rim: p.rim, depth: 5)
        // A tiny paw print on the lid, in the pet's own colour.
        let c = CGPoint(x: 100, y: floor - 26)
        let mark = p.palette.prop.alpha(0.85)
        ctx.fill(PetDraw.ellipse(CGPoint(x: c.x, y: c.y + 2), 4.2, 3.4), mark)
        for (dx, dy) in [(-4.6, -3.2), (-1.6, -5.4), (1.6, -5.4), (4.6, -3.2)] as [(CGFloat, CGFloat)] {
            ctx.fill(PetDraw.ellipse(CGPoint(x: c.x + dx, y: c.y + dy), 1.5, 1.8), mark)
        }
    }

    /// Headphones: a band over the crown and a cup over each side of the head.
    static func headphones(_ head: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let rx = fig.headRX, ry = fig.headRY
        let color = p.palette.prop.mix(PetRGB(0.2, 0.2, 0.28), 0.15)
        var band = Path()
        band.move(to: CGPoint(x: -rx * 0.96, y: -ry * 0.05))
        band.addCurve(to: CGPoint(x: rx * 0.96, y: -ry * 0.05), control1: CGPoint(x: -rx * 0.98, y: -ry * 1.38), control2: CGPoint(x: rx * 0.98, y: -ry * 1.38))
        head.stroke(band, color.rim, width: 6 + p.rim * 2)
        head.stroke(band, color, width: 6)
        PetDraw.mirrored(head) { c, _ in
            let cup = Path(roundedRect: CGRect(x: rx * 0.84, y: -ry * 0.3, width: 12, height: 22), cornerSize: CGSize(width: 6, height: 6), style: .continuous)
            PetDraw.solid(c, cup, color, rim: p.rim, depth: 3)
            c.fill(Path(roundedRect: CGRect(x: rx * 0.84 - 2, y: -ry * 0.3 + 3, width: 4, height: 16), cornerSize: CGSize(width: 2, height: 2)), PetRGB(0.98, 0.96, 0.92))
        }
    }

    /// Between the two paws, so it is always in the hands.
    static func between(_ p: PetPaint, _ fig: PetFigure) -> CGPoint {
        let r = fig.paw(p.species, angle: p.pose.armR), l = fig.paw(p.species, angle: p.pose.armL)
        return CGPoint(x: 100 + (r.x - l.x) / 2, y: (r.y + l.y) / 2)
    }

    static func mug(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let c = between(p, fig)
        let body = CGRect(x: c.x - 11, y: c.y - 14, width: 22, height: 20)
        let cup = Path(roundedRect: body, cornerSize: CGSize(width: 5, height: 5), style: .continuous)
        var handle = Path()
        handle.addEllipse(in: CGRect(x: body.maxX - 4, y: body.minY + 4, width: 11, height: 11))
        ctx.stroke(handle, PetRGB(0.97, 0.95, 0.92).rim, width: 4.6)
        ctx.stroke(handle, PetRGB(0.97, 0.95, 0.92), width: 2.8)
        PetDraw.solid(ctx, cup, PetRGB(0.98, 0.96, 0.92), rim: p.rim, depth: 3)
        var band = ctx
        band.clip(to: cup)
        band.fill(Path(CGRect(x: body.minX, y: body.minY + 7, width: body.width, height: 5)), p.palette.prop)
        // Cocoa at the rim.
        ctx.fill(PetDraw.ellipse(CGPoint(x: body.midX, y: body.minY + 1.2), 9.5, 2.2), PetRGB(0.52, 0.33, 0.24))
        // Steam, rising and fading.
        let t = p.time ?? 0.6
        for i in 0..<2 {
            let phase = (t * 0.45 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
            let x = body.midX + CGFloat(i == 0 ? -3.5 : 3.5) + CGFloat(sin(phase * 6 + Double(i))) * 2
            let y = body.minY - 4 - CGFloat(phase) * 18
            var wisp = Path()
            wisp.move(to: CGPoint(x: x, y: y + 6))
            wisp.addQuadCurve(to: CGPoint(x: x, y: y - 3), control: CGPoint(x: x + 4, y: y + 1.5))
            ctx.stroke(wisp, PetRGB(1, 1, 1, 0.75 * sin(phase * .pi)), width: 2)
        }
    }

    static func book(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let c = between(p, fig)
        let w: CGFloat = 44, h: CGFloat = 28
        let r = CGRect(x: c.x - w / 2, y: c.y - h + 6, width: w, height: h)
        // Page edges peeking over the top, then the cover facing us.
        let pages = Path(roundedRect: r.offsetBy(dx: 0, dy: -2.5).insetBy(dx: 2, dy: 0), cornerSize: CGSize(width: 3, height: 3))
        ctx.fill(pages, PetRGB(0.99, 0.97, 0.92))
        ctx.stroke(pages, PetRGB(0.85, 0.82, 0.76), width: 1)
        let cover = Path(roundedRect: r, cornerSize: CGSize(width: 3.5, height: 3.5), style: .continuous)
        PetDraw.solid(ctx, cover, p.palette.prop, rim: p.rim, depth: 3)
        var spine = Path()
        spine.move(to: CGPoint(x: r.midX, y: r.minY + 1))
        spine.addLine(to: CGPoint(x: r.midX, y: r.maxY - 1))
        ctx.stroke(spine, p.palette.prop.rim.alpha(0.6), width: 1.6)
        ctx.fill(Path(roundedRect: CGRect(x: r.midX + 6, y: r.minY + 7, width: 12, height: 3), cornerSize: CGSize(width: 1.5, height: 1.5)), PetRGB(1, 1, 1, 0.55))
    }

    static func blanket(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let floor = PetFigure.floor
        let top = fig.neck.y - 4 + CGFloat(p.pose.slump) * 4
        let w: CGFloat = p.species == .penguin ? 50 : 52
        let color = PetRGB(0.62, 0.66, 0.80).mix(p.palette.prop, 0.25)
        PetDraw.mirrored(ctx, axis: 100) { c, _ in
            // One side of the drape: over the shoulder, down the side, open at the front.
            var side = Path()
            side.move(to: CGPoint(x: 100 + 4, y: top))
            side.addQuadCurve(to: CGPoint(x: 100 + w, y: top + 34), control: CGPoint(x: 100 + w * 0.8, y: top - 2))
            side.addQuadCurve(to: CGPoint(x: 100 + w + 2, y: floor - 1), control: CGPoint(x: 100 + w + 6, y: top + 60))
            side.addLine(to: CGPoint(x: 100 + 16, y: floor - 1))
            side.addQuadCurve(to: CGPoint(x: 100 + 4, y: top), control: CGPoint(x: 100 + 26, y: top + 30))
            side.closeSubpath()
            PetDraw.solid(c, side, color, rim: p.rim, depth: 6)
            // A knit stripe near the hem.
            var hem = c
            hem.clip(to: side)
            hem.fill(Path(CGRect(x: 100, y: floor - 14, width: w + 10, height: 4)), PetRGB(0.98, 0.96, 0.92, 0.75))
        }
    }

    static func ball(_ ctx: GraphicsContext, _ p: PetPaint) {
        // It rolls a little back and forth (the pet's eyes follow it); the stripe turns with it.
        let t = p.time ?? 0
        let roll = CGFloat(sin(t * 1.1)) * 5
        let c = CGPoint(x: 158 + roll, y: PetFigure.floor - 11)
        var spun = ctx
        spun.translateBy(x: c.x, y: c.y)
        spun.rotate(by: .radians(Double(roll / 11)))
        spun.translateBy(x: -c.x, y: -c.y)
        let ball = PetDraw.ellipse(c, 11, 11)
        PetDraw.solid(ctx, ball, p.palette.prop, rim: p.rim, depth: 4)
        var stripe = spun
        stripe.clip(to: ball)
        var s = Path()
        s.move(to: CGPoint(x: c.x - 12, y: c.y + 3))
        s.addQuadCurve(to: CGPoint(x: c.x + 12, y: c.y - 3), control: CGPoint(x: c.x, y: c.y - 5))
        stripe.stroke(s, PetRGB(1, 1, 1, 0.9), width: 3)
    }

    /// Worn on the head; the tip droops toward the lean.
    static func nightcap(_ head: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let ry = fig.headRY
        let color = PetRGB(0.52, 0.56, 0.84)
        var cap = Path()
        cap.move(to: CGPoint(x: -fig.headRX * 0.78, y: -ry * 0.5))
        cap.addQuadCurve(to: CGPoint(x: fig.headRX * 0.78, y: -ry * 0.5), control: CGPoint(x: 0, y: -ry * 1.35))
        cap.addQuadCurve(to: CGPoint(x: fig.headRX * 0.95, y: -ry * 0.1), control: CGPoint(x: fig.headRX * 1.1, y: -ry * 0.62))
        cap.closeSubpath()
        var cone = Path()
        cone.move(to: CGPoint(x: -fig.headRX * 0.72, y: -ry * 0.62))
        cone.addQuadCurve(to: CGPoint(x: fig.headRX * 1.05, y: -ry * 0.05), control: CGPoint(x: fig.headRX * 0.2, y: -ry * 1.9))
        cone.addQuadCurve(to: CGPoint(x: fig.headRX * 0.7, y: -ry * 0.55), control: CGPoint(x: fig.headRX * 0.85, y: -ry * 0.5))
        cone.closeSubpath()
        PetDraw.solid(head, cone, color, rim: p.rim, depth: 5)
        // Band.
        var band = Path()
        band.move(to: CGPoint(x: -fig.headRX * 0.8, y: -ry * 0.52))
        band.addQuadCurve(to: CGPoint(x: fig.headRX * 0.78, y: -ry * 0.52), control: CGPoint(x: 0, y: -ry * 0.92))
        head.stroke(band, PetRGB(0.98, 0.96, 0.92).rim, width: 9 + p.rim * 2)
        head.stroke(band, PetRGB(0.98, 0.96, 0.92), width: 9)
        let pom = PetDraw.ellipse(CGPoint(x: fig.headRX * 1.08, y: -ry * 0.02), 6, 6)
        PetDraw.solid(head, pom, PetRGB(0.98, 0.96, 0.92), rim: p.rim, depth: 2)
    }
}
