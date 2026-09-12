import SwiftUI

/// Rusty — a sleepy red panda with a big ringed tail.
public enum RedPandaPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let b = p.body
        let body = PetDraw.blobPath(b)

        // Big ringed tail behind the body.
        let start = CGPoint(x: b.center.x + b.width * 0.28, y: b.bottom - b.height * 0.14)
        let lift = CGFloat(p.rig.tailLift)
        let wag = CGFloat(p.live.tailWag)
        let angle = -lift * 1.1 + wag * 0.3
        let length = b.width * 0.55 * (1 - 0.35 * CGFloat(p.rig.lying))
        let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
        var tail = Path()
        tail.move(to: start)
        tail.addCurve(to: end, control1: CGPoint(x: start.x + length * 0.5, y: start.y + length * 0.15), control2: CGPoint(x: end.x + length * 0.3 * (1 - lift), y: end.y - length * 0.3 * lift))
        let tw = b.width * 0.19
        ctx.stroke(tail, with: .color(p.palette.bodyBottom), style: StrokeStyle(lineWidth: tw, lineCap: .round))
        // Rings along the tail.
        var rings = ctx
        rings.clip(to: tail.strokedPath(StrokeStyle(lineWidth: tw, lineCap: .round)))
        for i in 0..<3 {
            let t = 0.35 + CGFloat(i) * 0.24
            let pt = pointOnCubic(start, CGPoint(x: start.x + length * 0.5, y: start.y + length * 0.15), CGPoint(x: end.x + length * 0.3 * (1 - lift), y: end.y - length * 0.3 * lift), end, t)
            rings.fill(Path(ellipseIn: CGRect(x: pt.x - tw * 0.7, y: pt.y - tw * 0.32, width: tw * 1.4, height: tw * 0.64)), with: .color(p.palette.belly.opacity(0.7)))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: end.x - tw * 0.5, y: end.y - tw * 0.5, width: tw, height: tw)), with: .color(p.palette.belly))

        // Round ears with white inner and pale rims.
        let earLift = CGFloat(p.rig.earLift) + CGFloat(p.live.earTwitch)
        for side: CGFloat in [-1, 1] {
            let c = b.point(side * 0.38, -0.40 + (1 - earLift) * 0.1)
            let r = b.width * 0.13
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.08, y: c.y - r * 1.08, width: r * 2.16, height: r * 2.16)), with: .color(p.palette.marking.opacity(0.9)))
            PetDraw.roundEar(&ctx, p, center: c, radius: r, innerRatio: 0.55)
        }

        PetDraw.fillBody(&ctx, p, path: body)

        // Dark chest.
        var chest = ctx
        chest.clip(to: body)
        let chestRect = CGRect(x: b.center.x - b.width * 0.3, y: b.center.y + b.height * 0.16, width: b.width * 0.6, height: b.height * 0.5)
        chest.fill(Path(ellipseIn: chestRect), with: .color(p.palette.belly.opacity(0.9)))

        // Face mask: pale muzzle and cheeks, darker tear stripes.
        let muzzle = CGRect(x: b.center.x - b.width * 0.2, y: b.center.y - b.height * 0.02, width: b.width * 0.4, height: b.height * 0.24)
        ctx.fill(Path(ellipseIn: muzzle), with: .color(p.palette.marking.opacity(0.95)))
        for side: CGFloat in [-1, 1] {
            let cheek = CGRect(x: b.center.x + side * b.width * 0.3 - b.width * 0.12, y: b.center.y - b.height * 0.18, width: b.width * 0.24, height: b.height * 0.2)
            ctx.fill(Path(ellipseIn: cheek), with: .color(p.palette.marking.opacity(0.85)))
            var stripe = Path()
            let sx = b.center.x + side * b.width * 0.2
            stripe.move(to: CGPoint(x: sx, y: b.center.y - b.height * 0.06))
            stripe.addQuadCurve(to: CGPoint(x: sx + side * b.width * 0.06, y: b.center.y + b.height * 0.1), control: CGPoint(x: sx - side * b.width * 0.02, y: b.center.y + b.height * 0.03))
            ctx.stroke(stripe, with: .color(p.palette.belly.opacity(0.55)), style: StrokeStyle(lineWidth: b.width * 0.035, lineCap: .round))
        }

        // Paws.
        for side: CGFloat in [-1, 1] {
            let paw = CGRect(x: b.center.x + side * b.width * 0.17 - b.width * 0.1, y: b.bottom - b.height * 0.12, width: b.width * 0.2, height: b.height * 0.11)
            ctx.fill(Path(ellipseIn: paw), with: .color(p.palette.belly))
        }

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.22
        layout.eyeY = -0.12
        layout.eyeRadius = 0.075
        layout.mouthY = 0.13
        layout.mouthWidth = 0.1
        layout.blushX = 0.34
        layout.blushY = 0.02
        PetDraw.blush(&ctx, p, layout: layout)
        PetDraw.eyes(&ctx, p, layout: layout, lidColor: p.palette.bodyTop)
        PetDraw.brows(&ctx, p, layout: layout)

        // Nose.
        let nx = b.center.x, ny = b.center.y + b.height * 0.05
        let ns = b.width * 0.038
        ctx.fill(Path(roundedRect: CGRect(x: nx - ns, y: ny - ns * 0.6, width: ns * 2, height: ns * 1.3), cornerRadius: ns * 0.6), with: .color(p.palette.nose))

        PetDraw.mouth(&ctx, p, style: .cat, layout: layout)
        PetDraw.sweat(&ctx, p)
    }

    private static func pointOnCubic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x
        let y = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        return CGPoint(x: x, y: y)
    }
}
