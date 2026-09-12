import SwiftUI

/// Biscuit — a sitting, floppy-eared dog with a muzzle and a patch over one eye.
public enum DogPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso

        PetDraw.tail(&ctx, p,
                     start: CGPoint(x: t.centerX + t.hipWidth * 0.36, y: t.bottom - 16),
                     length: 40, width: 13, color: p.palette.bodyBottom, tip: p.palette.belly, curl: 0.6)

        PetDraw.body(&ctx, p, pawColor: p.palette.belly)

        var hc = PetDraw.headContext(ctx, p)
        let h = p.head
        let head = PetDraw.headPath(h)

        PetDraw.fillFur(&hc, p, path: head, rect: h.rect)

        // Floppy ears hang beside the head; earLift swings them out.
        let lift = CGFloat(p.rig.earLift) + CGFloat(p.live.earTwitch)
        for side: CGFloat in [-1, 1] {
            let top = h.point(side * 0.4, -0.34)
            let len = h.height * 0.62
            let swing = side * (0.1 + 0.4 * lift)
            let tip = CGPoint(x: top.x + sin(swing) * len, y: top.y + cos(swing) * len)
            let w = h.width * 0.2
            var ear = Path()
            ear.move(to: CGPoint(x: top.x - side * w * 0.3, y: top.y))
            ear.addCurve(to: tip,
                         control1: CGPoint(x: top.x + side * w * 0.9, y: top.y + len * 0.2),
                         control2: CGPoint(x: tip.x + side * w * 0.6, y: tip.y - len * 0.05))
            ear.addCurve(to: CGPoint(x: top.x - side * w * 0.3, y: top.y),
                         control1: CGPoint(x: tip.x - side * w * 0.7, y: tip.y - len * 0.05),
                         control2: CGPoint(x: top.x - side * w * 0.4, y: top.y + len * 0.4))
            ear.closeSubpath()
            hc.fill(ear, with: .linearGradient(Gradient(colors: [p.palette.marking, p.palette.earInner]), startPoint: top, endPoint: tip))
        }

        // Patch over one eye.
        var patch = hc
        patch.clip(to: head)
        patch.fill(Path(ellipseIn: CGRect(x: h.center.x + h.width * 0.06, y: h.center.y - h.height * 0.22, width: h.width * 0.34, height: h.height * 0.36)), with: .color(p.palette.marking.opacity(0.5)))

        // Muzzle.
        let mz = CGRect(x: h.center.x - h.width * 0.22, y: h.center.y + h.height * 0.1, width: h.width * 0.44, height: h.height * 0.32)
        hc.fill(Path(ellipseIn: mz), with: .color(p.palette.belly.opacity(0.95)))

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.2
        layout.eyeY = -0.02
        layout.eyeRadius = 0.082
        layout.mouthY = 0.3
        layout.mouthWidth = 0.13
        layout.blushX = 0.36
        layout.blushY = 0.14
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)

        let nx = h.center.x, ny = mz.minY + mz.height * 0.3
        let ns = h.width * 0.05
        hc.fill(Path(roundedRect: CGRect(x: nx - ns, y: ny - ns * 0.7, width: ns * 2, height: ns * 1.4), cornerRadius: ns * 0.7), with: .color(p.palette.nose))
        hc.fill(Path(ellipseIn: CGRect(x: nx - ns * 0.5, y: ny - ns * 0.5, width: ns * 0.5, height: ns * 0.35)), with: .color(.white.opacity(0.35)))

        PetDraw.mouth(&hc, p, style: .snout, layout: layout)
        PetDraw.sweat(&hc, p)
    }
}
