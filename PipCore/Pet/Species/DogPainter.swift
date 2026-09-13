import SwiftUI

/// Biscuit — a sitting cream puppy. One silhouette, long floppy brown ears, a patch over
/// one eye, a pale muzzle with a small black nose, a short wagging tail and a bandana.
public enum DogPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso
        let h = p.head

        // Short tail behind the body.
        do {
            let lift = CGFloat(p.rig.tailLift)
            let wag = CGFloat(p.live.tailWag)
            let start = CGPoint(x: t.centerX + t.hipWidth * 0.36, y: t.bottom - t.height * 0.22)
            let angle = -0.2 - lift * 1.1 + wag * 0.45
            let len: CGFloat = 30
            let end = CGPoint(x: start.x + cos(angle) * len, y: start.y + sin(angle) * len)
            var tail = Path()
            tail.move(to: start)
            tail.addQuadCurve(to: end, control: CGPoint(x: start.x + len * 0.7, y: start.y + sin(angle) * len * 0.2))
            ctx.fill(tail.strokedPath(StrokeStyle(lineWidth: 12, lineCap: .round)), with: .color(p.palette.marking))
        }

        let silhouette = PetDraw.silhouette(p)
        ctx.fill(silhouette, with: .color(p.palette.base))
        PetDraw.belly(&ctx, p, within: silhouette, widthFraction: 0.5, heightFraction: 0.5)
        PetDraw.paws(&ctx, p, color: p.palette.belly)

        // Floppy ears hang from the top corners; drooping ears hang straighter.
        let lift = CGFloat(p.rig.earLift)
        PetDraw.mirrored(&ctx) { ctx, side in
            let twitch = side == 1 ? CGFloat(p.live.earTwitch) * 0.15 : 0
            let top = h.point(0.38, -0.34)
            let len = h.height * 0.66
            let swing = 0.1 + 0.4 * lift + twitch
            let tip = CGPoint(x: top.x + sin(swing) * len, y: top.y + cos(swing) * len)
            let w = h.width * 0.2
            var ear = Path()
            ear.move(to: CGPoint(x: top.x - w * 0.4, y: top.y))
            ear.addCurve(to: tip,
                         control1: CGPoint(x: top.x + w * 0.9, y: top.y + len * 0.15),
                         control2: CGPoint(x: tip.x + w * 0.6, y: tip.y - len * 0.06))
            ear.addCurve(to: CGPoint(x: top.x - w * 0.4, y: top.y),
                         control1: CGPoint(x: tip.x - w * 0.7, y: tip.y - len * 0.02),
                         control2: CGPoint(x: top.x - w * 0.5, y: top.y + len * 0.45))
            ear.closeSubpath()
            ctx.fill(ear.applying(p.headTilt), with: .color(p.palette.marking))
        }

        var hc = PetDraw.headContext(ctx, p)

        // Patch over the right eye — deliberately asymmetric.
        var patch = hc
        patch.clip(to: PetDraw.headPath(h))
        patch.fill(Path(ellipseIn: CGRect(x: h.center.x + h.width * 0.03, y: h.center.y - h.height * 0.24, width: h.width * 0.34, height: h.height * 0.38)), with: .color(p.palette.marking.opacity(0.55)))

        // Muzzle.
        let mz = CGRect(x: h.center.x + p.faceShift - h.width * 0.2, y: h.center.y + h.height * 0.1, width: h.width * 0.4, height: h.height * 0.3)
        hc.fill(Path(ellipseIn: mz), with: .color(p.palette.belly))

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.2
        layout.eyeY = -0.03
        layout.eyeRadius = p.anatomy.eyeRadius
        layout.mouthY = 0.28
        layout.mouthWidth = 0.1
        layout.blushX = 0.36
        layout.blushY = 0.12
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)

        let a = PetDraw.mouthAnchor(p, layout: layout)
        let ns = h.width * 0.04
        hc.fill(Path(ellipseIn: CGRect(x: a.x - ns, y: mz.minY + mz.height * 0.22 - ns * 0.7, width: ns * 2, height: ns * 1.4)), with: .color(p.palette.nose))

        PetDraw.mouth(&hc, p, style: .snout, layout: layout)
        PetProps.bandana(&hc, p)
        PetDraw.sweat(&hc, p)
    }
}
