import SwiftUI

/// Biscuit — a sitting cream puppy with long floppy brown ears, a brown patch over one
/// eye, a round muzzle with a black nose, and a short tail that wags behind the haunch.
public enum DogPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso

        // Short tail behind the body, rising with tailLift and wagging.
        do {
            let lift = CGFloat(p.rig.tailLift)
            let wag = CGFloat(p.live.tailWag)
            let start = CGPoint(x: t.centerX + t.hipWidth * 0.38, y: t.bottom - t.height * 0.22)
            let angle = -0.2 - lift * 1.1 + wag * 0.45
            let len: CGFloat = 30
            let end = CGPoint(x: start.x + cos(angle) * len, y: start.y + sin(angle) * len)
            var tail = Path()
            tail.move(to: start)
            tail.addQuadCurve(to: end, control: CGPoint(x: start.x + len * 0.7, y: start.y + sin(angle) * len * 0.2))
            let stroked = tail.strokedPath(StrokeStyle(lineWidth: 12, lineCap: .round))
            PetDraw.form(&ctx, stroked, in: stroked.boundingRect, base: p.palette.marking, shade: p.palette.earInner, light: p.palette.base, strength: 0.8)
            var tip = ctx
            tip.clip(to: stroked)
            tip.fill(Path(ellipseIn: CGRect(x: end.x - 8, y: end.y - 8, width: 16, height: 16)), with: .color(p.palette.belly))
        }

        PetDraw.body(&ctx, p, pawColor: p.palette.belly)
        PetDraw.neckShadow(&ctx, p, within: PetDraw.torsoPath(p.torso))

        var hc = PetDraw.headContext(ctx, p)
        let h = p.head
        let head = PetDraw.headPath(h)

        // Floppy ears hang from the top corners; earLift swings them out, drooping ears hang straight.
        let lift = CGFloat(p.rig.earLift)
        PetDraw.mirrored(&hc) { ctx, side in
            let twitch = side == 1 ? CGFloat(p.live.earTwitch) * 0.15 : 0
            let top = h.point(0.36, -0.36)
            let len = h.height * 0.7
            let swing = 0.12 + 0.42 * lift + twitch
            let tip = CGPoint(x: top.x + sin(swing) * len, y: top.y + cos(swing) * len)
            let w = h.width * 0.21
            var ear = Path()
            ear.move(to: CGPoint(x: top.x - w * 0.35, y: top.y))
            ear.addCurve(to: tip,
                         control1: CGPoint(x: top.x + w * 0.95, y: top.y + len * 0.15),
                         control2: CGPoint(x: tip.x + w * 0.62, y: tip.y - len * 0.06))
            ear.addCurve(to: CGPoint(x: top.x - w * 0.35, y: top.y),
                         control1: CGPoint(x: tip.x - w * 0.7, y: tip.y - len * 0.02),
                         control2: CGPoint(x: top.x - w * 0.45, y: top.y + len * 0.45))
            ear.closeSubpath()
            PetDraw.form(&ctx, ear, in: ear.boundingRect, base: p.palette.marking, shade: p.palette.earInner, light: p.palette.base, strength: 1)
        }

        PetDraw.fur(&hc, p, head, in: h.rect)

        // Patch over the right eye — deliberately asymmetric.
        var patch = hc
        patch.clip(to: head)
        patch.fill(Path(ellipseIn: CGRect(x: h.center.x + h.width * 0.04, y: h.center.y - h.height * 0.26, width: h.width * 0.36, height: h.height * 0.4)), with: .color(p.palette.marking.opacity(0.45)))

        // Muzzle.
        let mz = CGRect(x: h.center.x + p.faceShift - h.width * 0.23, y: h.center.y + h.height * 0.08, width: h.width * 0.46, height: h.height * 0.34)
        PetDraw.form(&hc, Path(ellipseIn: mz), in: mz, base: p.palette.belly, shade: p.palette.shade, light: .white, strength: 0.5)

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.21
        layout.eyeY = -0.04
        layout.eyeRadius = p.anatomy.eyeRadius
        layout.mouthY = 0.27
        layout.mouthWidth = 0.14
        layout.blushX = 0.38
        layout.blushY = 0.12
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)

        // Nose: rounded, with a soft highlight.
        let a = PetDraw.mouthAnchor(p, layout: layout)
        let ns = h.width * 0.05
        let ny = mz.minY + mz.height * 0.32
        let noseRect = CGRect(x: a.x - ns, y: ny - ns * 0.7, width: ns * 2, height: ns * 1.4)
        hc.fill(Path(roundedRect: noseRect, cornerRadius: ns * 0.7), with: .color(p.palette.nose))
        if p.detail == .full {
            hc.fill(Path(ellipseIn: CGRect(x: a.x - ns * 0.55, y: ny - ns * 0.5, width: ns * 0.6, height: ns * 0.4)), with: .color(.white.opacity(0.35)))
        }

        PetDraw.mouth(&hc, p, style: .snout, layout: layout)
        PetDraw.sweat(&hc, p)
    }
}
