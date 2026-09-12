import SwiftUI

/// Biscuit — a floppy-eared, relentlessly optimistic dog.
public enum DogPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let b = p.body
        let body = PetDraw.blobPath(b)

        // Short tail, wags a lot.
        PetDraw.tail(&ctx, p,
                     start: CGPoint(x: b.center.x + b.width * 0.32, y: b.bottom - b.height * 0.16),
                     length: b.width * 0.34, width: b.width * 0.12,
                     color: p.palette.bodyBottom, tip: p.palette.belly, curl: 0.6)

        PetDraw.fillBody(&ctx, p, path: body)

        // Floppy ears hang from the sides; earLift swings them out a little.
        let lift = CGFloat(p.rig.earLift) + CGFloat(p.live.earTwitch)
        for side: CGFloat in [-1, 1] {
            let top = b.point(side * 0.36, -0.36)
            let len = b.height * 0.5
            let swing = side * (0.12 + 0.35 * lift)
            let tip = CGPoint(x: top.x + sin(swing) * len, y: top.y + cos(swing) * len)
            let w = b.width * 0.19
            var ear = Path()
            ear.move(to: CGPoint(x: top.x - side * w * 0.2, y: top.y))
            ear.addCurve(to: CGPoint(x: tip.x, y: tip.y),
                         control1: CGPoint(x: top.x + side * w * 0.9, y: top.y + len * 0.2),
                         control2: CGPoint(x: tip.x + side * w * 0.6, y: tip.y - len * 0.05))
            ear.addCurve(to: CGPoint(x: top.x - side * w * 0.2, y: top.y),
                         control1: CGPoint(x: tip.x - side * w * 0.7, y: tip.y - len * 0.05),
                         control2: CGPoint(x: top.x - side * w * 0.3, y: top.y + len * 0.4))
            ear.closeSubpath()
            ctx.fill(ear, with: .linearGradient(Gradient(colors: [p.palette.marking, p.palette.earInner]), startPoint: top, endPoint: tip))
        }

        PetDraw.belly(&ctx, p, path: body, widthFraction: 0.52, heightFraction: 0.4, yOffset: 0.31, opacity: 0.9)

        // Muzzle patch.
        let muzzle = CGRect(x: b.center.x - b.width * 0.19, y: b.center.y + b.height * 0.0, width: b.width * 0.38, height: b.height * 0.22)
        ctx.fill(Path(ellipseIn: muzzle), with: .color(p.palette.belly.opacity(0.95)))

        // A patch over one eye — gives Biscuit a face you remember.
        var patch = ctx
        patch.clip(to: body)
        let patchRect = CGRect(x: b.center.x + b.width * 0.08, y: b.center.y - b.height * 0.28, width: b.width * 0.3, height: b.height * 0.3)
        patch.fill(Path(ellipseIn: patchRect), with: .color(p.palette.marking.opacity(0.55)))

        // Paws.
        for side: CGFloat in [-1, 1] {
            let paw = CGRect(x: b.center.x + side * b.width * 0.18 - b.width * 0.11, y: b.bottom - b.height * 0.13, width: b.width * 0.22, height: b.height * 0.12)
            ctx.fill(Path(ellipseIn: paw), with: .color(p.palette.bodyTop))
        }

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.21
        layout.eyeY = -0.11
        layout.mouthY = 0.13
        layout.mouthWidth = 0.12
        layout.blushY = 0.02
        PetDraw.blush(&ctx, p, layout: layout)
        PetDraw.eyes(&ctx, p, layout: layout)
        PetDraw.brows(&ctx, p, layout: layout)

        // Nose.
        let nx = b.center.x, ny = b.center.y + b.height * 0.045
        let ns = b.width * 0.045
        var nose = Path(roundedRect: CGRect(x: nx - ns, y: ny - ns * 0.7, width: ns * 2, height: ns * 1.4), cornerRadius: ns * 0.7)
        ctx.fill(nose, with: .color(p.palette.nose))
        nose = Path(ellipseIn: CGRect(x: nx - ns * 0.5, y: ny - ns * 0.5, width: ns * 0.5, height: ns * 0.35))
        ctx.fill(nose, with: .color(.white.opacity(0.35)))

        PetDraw.mouth(&ctx, p, style: .snout, layout: layout)
        PetDraw.sweat(&ctx, p)
    }
}
