import SwiftUI

/// Rusty — a chubby red panda with a masked face and a big ringed tail.
public enum RedPandaPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso

        // Big ringed tail behind the body.
        let start = CGPoint(x: t.centerX + t.hipWidth * 0.3, y: t.bottom - 16)
        let lift = CGFloat(p.rig.tailLift)
        let wag = CGFloat(p.live.tailWag)
        let angle = -lift * 1.15 + wag * 0.3
        let length: CGFloat = 66 * (1 - 0.3 * CGFloat(p.rig.lying))
        let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
        let c1 = CGPoint(x: start.x + length * 0.5, y: start.y + length * 0.15)
        let c2 = CGPoint(x: end.x + length * 0.3 * (1 - lift), y: end.y - length * 0.3 * lift)
        var tail = Path()
        tail.move(to: start)
        tail.addCurve(to: end, control1: c1, control2: c2)
        let tw: CGFloat = 22
        ctx.stroke(tail, with: .color(p.palette.bodyBottom), style: StrokeStyle(lineWidth: tw, lineCap: .round))
        var rings = ctx
        rings.clip(to: tail.strokedPath(StrokeStyle(lineWidth: tw, lineCap: .round)))
        for i in 0..<3 {
            let pt = pointOnCubic(start, c1, c2, end, 0.35 + CGFloat(i) * 0.24)
            rings.fill(Path(ellipseIn: CGRect(x: pt.x - tw * 0.7, y: pt.y - tw * 0.32, width: tw * 1.4, height: tw * 0.64)), with: .color(p.palette.belly.opacity(0.7)))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: end.x - tw * 0.5, y: end.y - tw * 0.5, width: tw, height: tw)), with: .color(p.palette.belly))

        PetDraw.body(&ctx, p, chestPatch: true, pawColor: p.palette.belly)

        var hc = PetDraw.headContext(ctx, p)
        let h = p.head

        // Round ears with pale rims.
        let earLift = CGFloat(p.rig.earLift) + CGFloat(p.live.earTwitch)
        for side: CGFloat in [-1, 1] {
            let c = h.point(side * 0.42, -0.36 + (1 - earLift) * 0.1)
            let r = h.width * 0.14
            hc.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.08, y: c.y - r * 1.08, width: r * 2.16, height: r * 2.16)), with: .color(p.palette.marking.opacity(0.9)))
            PetDraw.roundEar(&hc, p, center: c, radius: r, innerRatio: 0.55)
        }

        let head = PetDraw.headPath(h)
        PetDraw.fillFur(&hc, p, path: head, rect: h.rect)

        // Mask: pale muzzle and cheeks, darker tear stripes.
        let muzzle = CGRect(x: h.center.x - h.width * 0.22, y: h.center.y + h.height * 0.1, width: h.width * 0.44, height: h.height * 0.3)
        hc.fill(Path(ellipseIn: muzzle), with: .color(p.palette.marking.opacity(0.95)))
        for side: CGFloat in [-1, 1] {
            let cheek = CGRect(x: h.center.x + side * h.width * 0.33 - h.width * 0.13, y: h.center.y - h.height * 0.1, width: h.width * 0.26, height: h.height * 0.24)
            hc.fill(Path(ellipseIn: cheek), with: .color(p.palette.marking.opacity(0.85)))
            var stripe = Path()
            let sx = h.center.x + side * h.width * 0.21
            stripe.move(to: CGPoint(x: sx, y: h.center.y + h.height * 0.06))
            stripe.addQuadCurve(to: CGPoint(x: sx + side * h.width * 0.06, y: h.center.y + h.height * 0.24), control: CGPoint(x: sx - side * h.width * 0.02, y: h.center.y + h.height * 0.16))
            hc.stroke(stripe, with: .color(p.palette.belly.opacity(0.55)), style: StrokeStyle(lineWidth: h.width * 0.035, lineCap: .round))
        }

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.21
        layout.eyeY = 0.0
        layout.eyeRadius = 0.08
        layout.mouthY = 0.28
        layout.mouthWidth = 0.11
        layout.blushX = 0.36
        layout.blushY = 0.16
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)

        let nx = h.center.x, ny = h.center.y + h.height * 0.2
        let ns = h.width * 0.04
        hc.fill(Path(roundedRect: CGRect(x: nx - ns, y: ny - ns * 0.6, width: ns * 2, height: ns * 1.3), cornerRadius: ns * 0.6), with: .color(p.palette.nose))

        PetDraw.mouth(&hc, p, style: .cat, layout: layout)
        PetDraw.sweat(&hc, p)
    }

    private static func pointOnCubic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
        let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        return CGPoint(x: x, y: y)
    }
}
