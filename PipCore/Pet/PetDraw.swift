import SwiftUI

/// Drawing primitives shared by every species. One key light (upper left), one form shadow per
/// shape, a rim in a deeper tone of the shape's own colour, and eyes whose emotion comes from lids.
enum PetDraw {
    /// Fills a shape with a cel-shaded form shadow on the side away from the light and an
    /// optional rim. `depth` is how far the shadow crescent reaches.
    static func solid(_ ctx: GraphicsContext, _ path: Path, _ color: PetRGB, rim: CGFloat, depth: CGFloat = 5, shade: PetRGB? = nil) {
        if rim > 0 { ctx.stroke(path, color.rim, width: rim * 2) }
        ctx.fill(path, color)
        guard depth > 0 else { return }
        var inner = ctx
        inner.clip(to: path)
        // Shadow = the shape minus itself nudged toward the light.
        let lit = path.offsetBy(dx: -depth * 0.55, dy: -depth)
        inner.fill(path.subtracting(lit), shade ?? color.shade)
    }

    /// A soft highlight where the key light hits a rounded form.
    static func highlight(_ ctx: GraphicsContext, _ rect: CGRect, _ color: PetRGB, amount: Double = 0.28) {
        ctx.fill(Path(ellipseIn: rect), PetRGB(1, 1, 1, amount).mix(color.alpha(amount), 0.35))
    }

    static func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
    }

    /// Draws `body` for the right-hand side and again mirrored about `axis`, with the right and
    /// left parameter supplied to each call. Paired parts are only ever written once.
    static func mirrored(_ ctx: GraphicsContext, axis: CGFloat = 0, _ body: (GraphicsContext, _ side: CGFloat) -> Void) {
        body(ctx, 1)
        var m = ctx
        m.translateBy(x: axis, y: 0)
        m.scaleBy(x: -1, y: 1)
        m.translateBy(x: -axis, y: 0)
        body(m, -1)
    }

    /// A tapered limb along a gentle curve: root width to tip width.
    static func limb(from a: CGPoint, to b: CGPoint, bend: CGFloat, rootWidth: CGFloat, tipWidth: CGFloat) -> Path {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(hypot(dx, dy), 0.001)
        let nx = -dy / len, ny = dx / len
        let mid = CGPoint(x: (a.x + b.x) / 2 + nx * bend, y: (a.y + b.y) / 2 + ny * bend)
        // Offset the centre curve on both sides and cap both ends round.
        func side(_ s: CGFloat) -> (CGPoint, CGPoint, CGPoint) {
            (CGPoint(x: a.x + nx * rootWidth / 2 * s, y: a.y + ny * rootWidth / 2 * s),
             CGPoint(x: mid.x + nx * (rootWidth + tipWidth) / 4 * s, y: mid.y + ny * (rootWidth + tipWidth) / 4 * s),
             CGPoint(x: b.x + nx * tipWidth / 2 * s, y: b.y + ny * tipWidth / 2 * s))
        }
        let (a1, m1, b1) = side(1), (a2, m2, b2) = side(-1)
        var p = Path()
        p.move(to: a1)
        p.addQuadCurve(to: b1, control: m1)
        p.addArc(center: b, radius: tipWidth / 2, startAngle: .radians(atan2(b1.y - b.y, b1.x - b.x)), endAngle: .radians(atan2(b2.y - b.y, b2.x - b.x)), clockwise: true)
        p.addQuadCurve(to: a2, control: m2)
        p.addArc(center: a, radius: rootWidth / 2, startAngle: .radians(atan2(a2.y - a.y, a2.x - a.x)), endAngle: .radians(atan2(a1.y - a.y, a1.x - a.x)), clockwise: true)
        p.closeSubpath()
        return p
    }

    // MARK: Eyes

    struct EyeStyle {
        var width: CGFloat
        var height: CGFloat
        /// The colour around the eye; lids are drawn in it.
        var skin: PetRGB
        var ink: PetRGB
        var stroke: CGFloat
        var catchlight = true
    }

    /// One eye at `c` (right eye; draw the left through `mirrored`, which flips the slant).
    /// Emotion is carried by the lids: the upper lid lowers and slants, the lower lid rises into
    /// a smile; fully closed eyes become strokes.
    static func eye(_ ctx: GraphicsContext, at c: CGPoint, style s: EyeStyle, lid: Double, slant: Double, smile: Double, squeeze: Double, gazeX: Double, gazeY: Double, wide: Double, blink: Double = 0) {
        let w = s.width * (1 + wide)
        let h = s.height * (1 + wide * 0.9) * CGFloat(1 - min(blink, 1) * 0.92)
        let lid = blink > 0.85 ? 1 : lid
        if squeeze > 0.5 {
            // A squeezed "<": the right eye points inward, the mirror makes the left ">".
            var p = Path()
            p.move(to: CGPoint(x: c.x + w * 0.55, y: c.y - h * 0.38))
            p.addLine(to: CGPoint(x: c.x - w * 0.45, y: c.y))
            p.addLine(to: CGPoint(x: c.x + w * 0.55, y: c.y + h * 0.38))
            ctx.stroke(p, s.ink, width: s.stroke * 1.1)
            return
        }
        if smile > 0.82 {
            // Delighted: an upturned crescent, `^`.
            var p = Path()
            p.move(to: CGPoint(x: c.x - w * 0.62, y: c.y + h * 0.12))
            p.addQuadCurve(to: CGPoint(x: c.x + w * 0.62, y: c.y + h * 0.12), control: CGPoint(x: c.x, y: c.y - h * 0.52))
            ctx.stroke(p, s.ink, width: s.stroke * 1.1)
            return
        }
        if lid > 0.88 {
            // Closed and resting: a soft downward curve, `‿`, tilted with the slant.
            var p = Path()
            let tiltY = CGFloat(slant) * h * 0.12
            p.move(to: CGPoint(x: c.x - w * 0.6, y: c.y + h * 0.1 + tiltY))
            p.addQuadCurve(to: CGPoint(x: c.x + w * 0.6, y: c.y + h * 0.1 - tiltY), control: CGPoint(x: c.x, y: c.y + h * 0.42))
            ctx.stroke(p, s.ink, width: s.stroke)
            return
        }
        let gx = CGFloat(gazeX) * w * 0.28, gy = CGFloat(gazeY) * h * 0.18
        let eyeRect = CGRect(x: c.x - w / 2 + gx, y: c.y - h / 2 + gy, width: w, height: h)
        let eye = Path(ellipseIn: eyeRect)
        ctx.fill(eye, s.ink)
        if s.catchlight {
            let r = w * 0.2
            ctx.fill(Path(ellipseIn: CGRect(x: eyeRect.midX - w * 0.2 - r, y: eyeRect.minY + h * 0.2, width: r * 2, height: r * 2)), PetRGB(1, 1, 1, 0.95))
        }
        var lids = ctx
        lids.clip(to: eye.strokedPath(StrokeStyle(lineWidth: 1)).union(eye))
        // Upper lid: a line that drops with `lid` and slants (inner corner is toward −x for the right eye).
        let top = eyeRect.minY - 1
        let drop = CGFloat(lid) * h
        let slantY = CGFloat(slant) * h * 0.42
        let inner = CGPoint(x: eyeRect.minX - 1, y: top + drop + slantY)
        let outer = CGPoint(x: eyeRect.maxX + 1, y: top + drop - slantY)
        if lid > 0.02 || abs(slant) > 0.05 {
            var upper = Path()
            upper.move(to: CGPoint(x: eyeRect.minX - 2, y: top - 4))
            upper.addLine(to: CGPoint(x: eyeRect.maxX + 2, y: top - 4))
            upper.addLine(to: CGPoint(x: outer.x + 1, y: max(outer.y, top)))
            upper.addLine(to: CGPoint(x: inner.x - 1, y: max(inner.y, top)))
            upper.closeSubpath()
            lids.fill(upper, s.skin)
            if lid > 0.12 || abs(slant) > 0.2 {
                var edge = Path()
                edge.move(to: CGPoint(x: inner.x, y: max(inner.y, top)))
                edge.addLine(to: CGPoint(x: outer.x, y: max(outer.y, top)))
                lids.stroke(edge, s.ink, width: s.stroke * 0.7)
            }
        }
        if smile > 0.02 {
            // Lower lid rises as an arc: cheeks pushing the eye into a smile.
            let rise = CGFloat(smile) * h * 0.95
            var lower = Path()
            lower.move(to: CGPoint(x: eyeRect.minX - 2, y: eyeRect.maxY + 3))
            lower.addLine(to: CGPoint(x: eyeRect.minX - 2, y: eyeRect.maxY - rise * 0.35))
            lower.addQuadCurve(to: CGPoint(x: eyeRect.maxX + 2, y: eyeRect.maxY - rise * 0.35), control: CGPoint(x: eyeRect.midX, y: eyeRect.maxY - rise * 1.4))
            lower.addLine(to: CGPoint(x: eyeRect.maxX + 2, y: eyeRect.maxY + 3))
            lower.closeSubpath()
            lids.fill(lower, s.skin)
        }
    }

    /// A brow for the right eye: a short rounded mark, inner end at −x.
    static func brow(_ ctx: GraphicsContext, over c: CGPoint, width: CGFloat, show: Double, slant: Double, raise: Double, color: PetRGB, thickness: CGFloat) {
        guard show > 0.05 else { return }
        let y = c.y - CGFloat(raise) * 3
        let s = CGFloat(slant) * width * 0.4
        var p = Path()
        p.move(to: CGPoint(x: c.x - width / 2, y: y + s))
        p.addQuadCurve(to: CGPoint(x: c.x + width / 2, y: y - s), control: CGPoint(x: c.x, y: y - 1.6 - abs(s) * 0.2))
        ctx.stroke(p, color.alpha(color.a * show), width: thickness)
    }

    /// A small mouth: a smile/frown curve that opens into a soft shape. Centre at `c`.
    static func mouth(_ ctx: GraphicsContext, at c: CGPoint, width: CGFloat, smile: Double, open: Double, round: Double, ink: PetRGB, inside: PetRGB, tongue: PetRGB, stroke: CGFloat, catLike: Bool = false) {
        let w = width * CGFloat(1 - 0.45 * round)
        let curve = CGFloat(smile) * width * 0.34
        if open < 0.08 {
            var p = Path()
            if catLike && smile > -0.1 {
                // The "w" mouth: two small arcs meeting under the nose.
                p.move(to: CGPoint(x: c.x - w / 2, y: c.y - curve * 0.3))
                p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 1), control: CGPoint(x: c.x - w / 4, y: c.y + curve * 0.9 + 1.5))
                p.addQuadCurve(to: CGPoint(x: c.x + w / 2, y: c.y - curve * 0.3), control: CGPoint(x: c.x + w / 4, y: c.y + curve * 0.9 + 1.5))
            } else {
                p.move(to: CGPoint(x: c.x - w / 2, y: c.y - curve * 0.5))
                p.addQuadCurve(to: CGPoint(x: c.x + w / 2, y: c.y - curve * 0.5), control: CGPoint(x: c.x, y: c.y + curve))
            }
            ctx.stroke(p, ink, width: stroke)
            return
        }
        // Open: a rounded shape whose top edge follows the smile and whose depth follows `open`.
        let depth = CGFloat(open) * width * (0.55 + 0.25 * CGFloat(round))
        let top = c.y - curve * 0.4
        var p = Path()
        if round > 0.5 {
            let rw = w * 0.55, rh = max(depth * 0.7, 2)
            p = Path(ellipseIn: CGRect(x: c.x - rw / 2, y: top - rh * 0.2, width: rw, height: rh))
        } else {
            p.move(to: CGPoint(x: c.x - w / 2, y: top))
            p.addQuadCurve(to: CGPoint(x: c.x + w / 2, y: top), control: CGPoint(x: c.x, y: top + curve * 0.6))
            p.addQuadCurve(to: CGPoint(x: c.x - w / 2, y: top), control: CGPoint(x: c.x, y: top + depth * (smile >= 0 ? 1.7 : 1.1)))
            p.closeSubpath()
        }
        ctx.fill(p, inside)
        var t = ctx
        t.clip(to: p)
        if smile >= -0.2 {
            let b = p.boundingRect
            t.fill(Path(ellipseIn: CGRect(x: b.midX - b.width * 0.32, y: b.maxY - b.height * 0.42, width: b.width * 0.64, height: b.height * 0.6)), tongue)
        }
        ctx.stroke(p, ink, width: stroke * 0.8)
    }
}
