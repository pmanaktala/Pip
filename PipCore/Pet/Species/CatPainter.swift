import SwiftUI

/// Mochi — a sitting orange tabby. Tall triangular ears, forehead stripes, a pale
/// muzzle with an ω mouth, and a tail that wraps around the front paws when relaxed.
public enum CatPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        PetDraw.body(&ctx, p, pawColor: p.palette.light)

        // Tail in front of the haunch, wrapping around the paws when down.
        PetDraw.tail(&ctx, p, width: 14, length: 64, color: p.palette.base, tip: p.palette.marking)

        var hc = PetDraw.headContext(ctx, p)
        let h = p.head
        let head = PetDraw.headPath(h)

        // Ears sit behind the head.
        PetDraw.mirrored(&hc) { ctx, side in
            PetDraw.pointedEar(&ctx, p, side: side, baseInner: h.point(0.16, -0.46), baseOuter: h.point(0.44, -0.2), length: 32)
        }

        PetDraw.neckShadow(&ctx, p, within: PetDraw.torsoPath(p.torso))
        PetDraw.fur(&hc, p, head, in: h.rect)

        // Tabby stripes: an "M" on the forehead and one bar on each cheek.
        if p.detail == .full {
            var stripes = hc
            stripes.clip(to: head)
            let stripeStyle = StrokeStyle(lineWidth: 3.4, lineCap: .round)
            let stripeColor = p.palette.marking.opacity(0.55)
            var mid = Path()
            mid.move(to: CGPoint(x: h.center.x, y: h.top + 2))
            mid.addLine(to: CGPoint(x: h.center.x, y: h.top + h.height * 0.2))
            stripes.stroke(mid, with: .color(stripeColor), style: stripeStyle)
            PetDraw.mirrored(&stripes) { ctx, _ in
                var s = Path()
                s.move(to: CGPoint(x: h.center.x + h.width * 0.11, y: h.top + 1))
                s.addQuadCurve(to: CGPoint(x: h.center.x + h.width * 0.13, y: h.top + h.height * 0.17), control: CGPoint(x: h.center.x + h.width * 0.1, y: h.top + h.height * 0.08))
                ctx.stroke(s, with: .color(stripeColor), style: stripeStyle)
                var cheek = Path()
                cheek.move(to: CGPoint(x: h.center.x + h.width * 0.5, y: h.center.y - 1))
                cheek.addLine(to: CGPoint(x: h.center.x + h.width * 0.4, y: h.center.y + 3))
                ctx.stroke(cheek, with: .color(stripeColor.opacity(0.8)), style: stripeStyle)
            }
        }

        // Muzzle: a paler patch around nose and mouth.
        let mz = CGRect(x: h.center.x + p.faceShift - h.width * 0.2, y: h.center.y + h.height * 0.1, width: h.width * 0.4, height: h.height * 0.26)
        hc.fill(Path(ellipseIn: mz), with: .color(p.palette.belly.opacity(0.7)))

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.21
        layout.eyeY = -0.02
        layout.eyeRadius = p.anatomy.eyeRadius
        layout.mouthY = 0.24
        layout.mouthWidth = 0.14
        layout.blushX = 0.37
        layout.blushY = 0.13
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)

        // Nose: a small rounded triangle just above the mouth.
        let a = PetDraw.mouthAnchor(p, layout: layout)
        let ns = h.width * 0.034
        let ny = a.y - ns * 1.4
        var nose = Path()
        nose.move(to: CGPoint(x: a.x - ns, y: ny - ns * 0.5))
        nose.addLine(to: CGPoint(x: a.x + ns, y: ny - ns * 0.5))
        nose.addQuadCurve(to: CGPoint(x: a.x, y: ny + ns * 0.9), control: CGPoint(x: a.x + ns * 0.8, y: ny + ns * 0.7))
        nose.addQuadCurve(to: CGPoint(x: a.x - ns, y: ny - ns * 0.5), control: CGPoint(x: a.x - ns * 0.8, y: ny + ns * 0.7))
        hc.fill(nose, with: .color(p.palette.nose))

        PetDraw.mouth(&hc, p, style: .cat, layout: layout)

        // Whiskers: three per side, mirrored, fading toward the tips.
        if p.detail == .full {
            PetDraw.mirrored(&hc) { ctx, _ in
                var whiskers = Path()
                for (i, dy) in [-0.03, 0.03, 0.09].enumerated() {
                    let x0 = h.center.x + h.width * 0.3
                    let y0 = h.center.y + h.height * (0.17 + dy)
                    let angle = CGFloat(i - 1) * 0.17
                    let len = h.width * 0.24
                    whiskers.move(to: CGPoint(x: x0, y: y0))
                    whiskers.addLine(to: CGPoint(x: x0 + cos(angle) * len, y: y0 + sin(angle) * len))
                }
                ctx.stroke(whiskers, with: .color(p.palette.shade.opacity(0.45)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }

        PetDraw.sweat(&hc, p)
    }
}
