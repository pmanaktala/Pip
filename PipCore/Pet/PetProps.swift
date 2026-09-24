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
    /// You're listening to something (another app is playing audio).
    case headphones

    /// What the pet wears for a stance at a moment. Headphones win while it's awake; asleep it
    /// only ever wears the nightcap. Meditating wears nothing.
    public static func choose(for stance: PetStance, at date: Date, music: Bool, calendar: Calendar = .current) -> PetWear? {
        if stance == .meditating { return nil }
        if stance.isAsleep { return .nightcap }
        if music { return .headphones }
        return PetDay.isBedtime(date, calendar: calendar) ? .nightcap : nil
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
        }
    }

    static func worn(_ head: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, _ wear: PetWear) {
        switch wear {
        case .nightcap: nightcap(head, p, fig)
        case .headphones: headphones(head, p, fig)
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
        let c = CGPoint(x: 158, y: PetFigure.floor - 11)
        let ball = PetDraw.ellipse(c, 11, 11)
        PetDraw.solid(ctx, ball, p.palette.prop, rim: p.rim, depth: 4)
        var stripe = ctx
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
