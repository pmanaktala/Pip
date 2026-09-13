import SwiftUI

/// Pebble — a little charcoal penguin. One egg silhouette, a white front that rises into
/// the face, two small eyes, a tiny orange beak, stubby flippers, orange feet, and a scarf.
public enum PenguinPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso
        let h = p.head
        let lying = CGFloat(p.rig.lying)

        // Egg body unioned with the head: one silhouette.
        var egg = Path()
        let top = CGPoint(x: t.centerX, y: t.top)
        egg.move(to: top)
        egg.addCurve(to: CGPoint(x: t.centerX + t.hipWidth / 2, y: t.top + t.height * 0.62),
                     control1: CGPoint(x: t.centerX + t.chestWidth * 0.62, y: t.top),
                     control2: CGPoint(x: t.centerX + t.hipWidth / 2, y: t.top + t.height * 0.26))
        egg.addCurve(to: CGPoint(x: t.centerX, y: t.bottom),
                     control1: CGPoint(x: t.centerX + t.hipWidth / 2, y: t.bottom),
                     control2: CGPoint(x: t.centerX + t.hipWidth * 0.34, y: t.bottom))
        egg.addCurve(to: CGPoint(x: t.centerX - t.hipWidth / 2, y: t.top + t.height * 0.62),
                     control1: CGPoint(x: t.centerX - t.hipWidth * 0.34, y: t.bottom),
                     control2: CGPoint(x: t.centerX - t.hipWidth / 2, y: t.bottom))
        egg.addCurve(to: top,
                     control1: CGPoint(x: t.centerX - t.hipWidth / 2, y: t.top + t.height * 0.26),
                     control2: CGPoint(x: t.centerX - t.chestWidth * 0.62, y: t.top))
        egg.closeSubpath()
        let silhouette = egg.union(PetDraw.headPath(h).applying(p.headTilt))
        ctx.fill(silhouette, with: .color(p.palette.base))

        // Front: a belly oval that rises into a rounded face patch. One shape, no seam.
        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.19
        layout.eyeY = -0.02
        layout.eyeRadius = p.anatomy.eyeRadius
        layout.mouthY = 0.2
        layout.blushX = 0.32
        layout.blushY = 0.13

        let bellyW = t.hipWidth * 0.7, bellyH = t.height * 0.84
        let belly = Path(ellipseIn: CGRect(x: t.centerX - bellyW / 2, y: t.bottom - bellyH - 3, width: bellyW, height: bellyH))
        let face = Path(ellipseIn: CGRect(x: h.center.x - h.width * 0.36, y: h.center.y - h.height * 0.24, width: h.width * 0.72, height: h.height * 0.8)).applying(p.headTilt)
        let bridge = Path(roundedRect: CGRect(x: h.center.x - h.width * 0.28, y: h.center.y + h.height * 0.2, width: h.width * 0.56, height: max(0, t.bottom - bellyH - (h.center.y + h.height * 0.2)) + 30), cornerRadius: h.width * 0.2)
        var front = ctx
        front.clip(to: silhouette)
        front.fill(belly.union(bridge).union(face), with: .color(p.palette.belly))

        // Flippers: short, tapered; hang at rest, lift with armRaise, flap with the swing.
        let raise = CGFloat(p.rig.armRaise).clamped(0, 1)
        let swing = CGFloat(p.live.armSwing)
        PetDraw.mirrored(&ctx) { ctx, _ in
            let root = CGPoint(x: t.centerX + t.hipWidth * 0.42, y: t.top + t.height * 0.3)
            let len = t.height * 0.46 * (1 - 0.2 * lying)
            let angle = 0.2 + raise * 1.55 + swing * 0.35 * (0.3 + raise)
            let dir = CGPoint(x: sin(angle), y: cos(angle))
            let normal = CGPoint(x: dir.y, y: -dir.x)
            let tip = CGPoint(x: root.x + dir.x * len, y: root.y + dir.y * len)
            let w: CGFloat = 14
            var fl = Path()
            fl.move(to: CGPoint(x: root.x - normal.x * w * 0.5, y: root.y - normal.y * w * 0.5))
            fl.addQuadCurve(to: tip, control: CGPoint(x: root.x - normal.x * w * 0.7 + dir.x * len * 0.55, y: root.y - normal.y * w * 0.7 + dir.y * len * 0.55))
            fl.addQuadCurve(to: CGPoint(x: root.x + normal.x * w * 0.5, y: root.y + normal.y * w * 0.5), control: CGPoint(x: root.x + normal.x * w * 0.5 + dir.x * len * 0.55, y: root.y + normal.y * w * 0.5 + dir.y * len * 0.55))
            fl.closeSubpath()
            ctx.fill(fl, with: .color(p.palette.shade))
        }

        // Feet: two orange ovals in front, toes forward.
        PetDraw.mirrored(&ctx) { ctx, _ in
            let fx = t.centerX + t.hipWidth * 0.16 + lying * 4
            let foot = CGRect(x: fx - 13, y: t.bottom - 8, width: 27, height: 11)
            ctx.fill(Path(ellipseIn: foot), with: .color(p.palette.nose))
        }

        // Face.
        var hc = PetDraw.headContext(ctx, p)
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout, lidColor: p.palette.belly)
        PetDraw.brows(&hc, p, layout: layout)
        beak(&hc, p, layout: layout)
        PetProps.scarf(&hc, p)
        PetDraw.sweat(&hc, p)
    }

    /// A tiny wedge of a beak. Smiles lift its corners; opening drops a small lower mandible.
    private static func beak(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: PetDraw.FaceLayout) {
        let h = p.head
        let a = PetDraw.mouthAnchor(p, layout: layout)
        let open = CGFloat(p.rig.mouthOpen)
        let curve = CGFloat(p.rig.mouthCurve)
        let bw = h.width * 0.075, bh = h.height * 0.065
        let lift = curve * bh * 0.4
        var beak = Path()
        beak.move(to: CGPoint(x: a.x - bw, y: a.y - lift))
        beak.addQuadCurve(to: CGPoint(x: a.x + bw, y: a.y - lift), control: CGPoint(x: a.x, y: a.y - bh * 1.2))
        beak.addQuadCurve(to: CGPoint(x: a.x - bw, y: a.y - lift), control: CGPoint(x: a.x, y: a.y + bh * 1.9))
        beak.closeSubpath()
        ctx.fill(beak, with: .color(p.palette.nose))

        if open > 0.2 {
            let depth = bh * (0.8 + 2.2 * (open - 0.2))
            var mandible = Path()
            mandible.move(to: CGPoint(x: a.x - bw * 0.75, y: a.y + bh * 0.4))
            mandible.addQuadCurve(to: CGPoint(x: a.x + bw * 0.75, y: a.y + bh * 0.4), control: CGPoint(x: a.x, y: a.y + bh * 0.4 + depth * 2.2))
            mandible.closeSubpath()
            ctx.fill(mandible, with: .color(Color(red: 0.42, green: 0.16, blue: 0.19)))
            ctx.fill(beak, with: .color(p.palette.nose))
        } else if curve < -0.25 || p.rig.mouthWobble > 0.1 {
            var line = Path()
            line.move(to: CGPoint(x: a.x - bw * 0.9, y: a.y + bh * 2.3))
            line.addQuadCurve(to: CGPoint(x: a.x + bw * 0.9, y: a.y + bh * 2.3), control: CGPoint(x: a.x, y: a.y + bh * 2.3 + curve * bh * 1.6))
            ctx.stroke(line, with: .color(p.ink.opacity(0.6)), style: StrokeStyle(lineWidth: p.inkWidth * 0.8, lineCap: .round))
        }
    }
}
