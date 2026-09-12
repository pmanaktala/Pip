import SwiftUI

/// Pebble — a little upright penguin. One continuous silhouette (head flows into the
/// egg body), a white front that rises into two lobes around the eyes, stubby flippers
/// that lift with mood, and orange feet in front.
public enum PenguinPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso
        let h = p.head
        let lying = CGFloat(p.rig.lying)

        // Head path in body space, tilted about the neck so the silhouette stays whole.
        let neck = CGPoint(x: h.center.x, y: h.bottom - 8)
        let tilt = CGAffineTransform(translationX: neck.x, y: neck.y).rotated(by: CGFloat(p.rig.tilt) * .pi / 180).translatedBy(x: -neck.x, y: -neck.y)
        let headPath = PetDraw.headPath(h).applying(tilt)

        // Egg body.
        var egg = Path()
        let top = CGPoint(x: t.centerX, y: t.top)
        let bottomY = t.bottom - 2
        egg.move(to: top)
        egg.addCurve(to: CGPoint(x: t.centerX + t.hipWidth / 2, y: t.top + t.height * 0.6),
                     control1: CGPoint(x: t.centerX + t.chestWidth * 0.6, y: t.top),
                     control2: CGPoint(x: t.centerX + t.hipWidth / 2, y: t.top + t.height * 0.25))
        egg.addCurve(to: CGPoint(x: t.centerX, y: bottomY),
                     control1: CGPoint(x: t.centerX + t.hipWidth / 2, y: bottomY),
                     control2: CGPoint(x: t.centerX + t.hipWidth * 0.32, y: bottomY))
        egg.addCurve(to: CGPoint(x: t.centerX - t.hipWidth / 2, y: t.top + t.height * 0.6),
                     control1: CGPoint(x: t.centerX - t.hipWidth * 0.32, y: bottomY),
                     control2: CGPoint(x: t.centerX - t.hipWidth / 2, y: bottomY))
        egg.addCurve(to: top,
                     control1: CGPoint(x: t.centerX - t.hipWidth / 2, y: t.top + t.height * 0.25),
                     control2: CGPoint(x: t.centerX - t.chestWidth * 0.6, y: t.top))
        egg.closeSubpath()

        let silhouette = egg.union(headPath)
        let bounds = CGRect(x: t.centerX - t.hipWidth / 2, y: h.top, width: t.hipWidth, height: t.bottom - h.top)
        PetDraw.fur(&ctx, p, silhouette, in: bounds)

        // White front: belly oval rising into a face patch with a lobe around each eye.
        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.2
        layout.eyeY = -0.04
        layout.eyeRadius = p.anatomy.eyeRadius
        layout.mouthY = 0.2
        layout.blushX = 0.33
        layout.blushY = 0.14

        var hc = PetDraw.headContext(ctx, p)
        let bellyW = t.hipWidth * 0.72, bellyH = t.height * 0.86
        let belly = Path(ellipseIn: CGRect(x: t.centerX - bellyW / 2, y: t.bottom - bellyH - 4, width: bellyW, height: bellyH))
        var facePatch = Path(ellipseIn: CGRect(x: h.center.x - h.width * 0.34, y: h.center.y - h.height * 0.14, width: h.width * 0.68, height: h.height * 0.72))
        for side: CGFloat in [-1, 1] {
            let c = CGPoint(x: h.center.x + side * h.width * layout.eyeSpacing, y: h.center.y + h.height * layout.eyeY)
            let r = h.width * 0.22
            facePatch = facePatch.union(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 1.12, width: r * 2, height: r * 2)))
        }
        // One continuous front: the face patch is bridged into the belly so there is no pinch at the neck.
        let bridge = Path(roundedRect: CGRect(x: h.center.x - h.width * 0.3, y: h.center.y + h.height * 0.2, width: h.width * 0.6, height: (t.bottom - bellyH) - (h.center.y + h.height * 0.2) + 24), cornerRadius: h.width * 0.2)
        let frontShape = belly.union(bridge).union(facePatch.applying(tilt))
        var front = ctx
        front.clip(to: silhouette)
        PetDraw.form(&front, frontShape, in: frontShape.boundingRect, base: p.palette.belly, shade: Color(red: 0.78, green: 0.76, blue: 0.74), light: .white, strength: 0.5)

        // Flippers: hang beside the body; rise with armRaise, flap with the swing.
        let raise = CGFloat(p.rig.armRaise).clamped(0, 1)
        let swing = CGFloat(p.live.armSwing)
        PetDraw.mirrored(&ctx) { ctx, _ in
            let root = CGPoint(x: t.centerX + t.hipWidth * 0.4, y: t.top + t.height * 0.3)
            let len = t.height * 0.5 * (1 - 0.2 * lying)
            let angle = 0.22 + raise * 1.6 + swing * 0.35 * (0.3 + raise)
            // Angle measured from straight down, rotating outward/upward.
            let dir = CGPoint(x: sin(angle), y: cos(angle))
            let normal = CGPoint(x: dir.y, y: -dir.x)
            let tip = CGPoint(x: root.x + dir.x * len, y: root.y + dir.y * len)
            let w: CGFloat = 15
            var fl = Path()
            fl.move(to: CGPoint(x: root.x - normal.x * w * 0.55, y: root.y - normal.y * w * 0.55))
            fl.addCurve(to: tip,
                        control1: CGPoint(x: root.x - normal.x * w * 0.9 + dir.x * len * 0.45, y: root.y - normal.y * w * 0.9 + dir.y * len * 0.45),
                        control2: CGPoint(x: tip.x - normal.x * w * 0.5 - dir.x * 4, y: tip.y - normal.y * w * 0.5 - dir.y * 4))
            fl.addCurve(to: CGPoint(x: root.x + normal.x * w * 0.55, y: root.y + normal.y * w * 0.55),
                        control1: CGPoint(x: tip.x + normal.x * w * 0.45 - dir.x * 4, y: tip.y + normal.y * w * 0.45 - dir.y * 4),
                        control2: CGPoint(x: root.x + normal.x * w * 0.7 + dir.x * len * 0.45, y: root.y + normal.y * w * 0.7 + dir.y * len * 0.45))
            fl.closeSubpath()
            // A touch darker than the body so it separates from the dark back.
            PetDraw.form(&ctx, fl, in: fl.boundingRect, base: p.palette.base, shade: p.palette.shade, light: p.palette.light, strength: 1.4)
            var edge = ctx
            edge.clip(to: fl)
            edge.fill(fl, with: .linearGradient(Gradient(colors: [p.palette.shade.opacity(0.45), p.palette.shade.opacity(0)]),
                                                startPoint: CGPoint(x: root.x - normal.x * w * 0.6, y: root.y - normal.y * w * 0.6),
                                                endPoint: CGPoint(x: root.x + normal.x * w * 0.4, y: root.y + normal.y * w * 0.4)))
        }

        // Feet: in front of the belly, toes forward.
        PetDraw.mirrored(&ctx) { ctx, _ in
            let fx = t.centerX + t.hipWidth * 0.17 + lying * 4
            let foot = CGRect(x: fx - 13, y: t.bottom - 9, width: 27, height: 12)
            var path = Path(roundedRect: foot, cornerRadius: 6)
            path = path.union(Path(ellipseIn: CGRect(x: foot.midX - 15, y: foot.minY + 1, width: 30, height: 10)))
            PetDraw.form(&ctx, path, in: foot, base: p.palette.nose, shade: Color(red: 0.82, green: 0.46, blue: 0.16), light: Color(red: 1, green: 0.8, blue: 0.5), strength: 0.8)
            if p.detail == .full {
                var toes = Path()
                for tx in [-0.25, 0.25] {
                    toes.move(to: CGPoint(x: foot.midX + CGFloat(tx) * foot.width, y: foot.midY + 1))
                    toes.addLine(to: CGPoint(x: foot.midX + CGFloat(tx) * foot.width * 1.1, y: foot.maxY - 1))
                }
                ctx.stroke(toes, with: .color(Color(red: 0.7, green: 0.38, blue: 0.12).opacity(0.5)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }

        // Face.
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout, lidColor: p.palette.belly)
        PetDraw.brows(&hc, p, layout: layout)
        beak(&hc, p, layout: layout)
        PetDraw.sweat(&hc, p)
    }

    private static func beak(_ ctx: inout GraphicsContext, _ p: PetPaintContext, layout: PetDraw.FaceLayout) {
        let h = p.head
        let a = PetDraw.mouthAnchor(p, layout: layout)
        let open = CGFloat(p.rig.mouthOpen)
        let curve = CGFloat(p.rig.mouthCurve)
        let bw = h.width * 0.15, bh = h.height * 0.085
        let dark = Color(red: 0.82, green: 0.46, blue: 0.16)

        // Upper mandible: a soft diamond, corners lifting with a smile.
        var upper = Path()
        upper.move(to: CGPoint(x: a.x - bw, y: a.y - curve * 1.5))
        upper.addQuadCurve(to: CGPoint(x: a.x + bw, y: a.y - curve * 1.5), control: CGPoint(x: a.x, y: a.y - bh * 1.6))
        upper.addQuadCurve(to: CGPoint(x: a.x - bw, y: a.y - curve * 1.5), control: CGPoint(x: a.x, y: a.y + bh * (1.1 - curve * 0.5)))
        upper.closeSubpath()
        PetDraw.form(&ctx, upper, in: upper.boundingRect, base: p.palette.nose, shade: dark, light: Color(red: 1, green: 0.82, blue: 0.5), strength: 0.7)

        if open > 0.08 {
            var lower = Path()
            lower.move(to: CGPoint(x: a.x - bw * 0.85, y: a.y + bh * 0.3))
            lower.addQuadCurve(to: CGPoint(x: a.x + bw * 0.85, y: a.y + bh * 0.3), control: CGPoint(x: a.x, y: a.y + bh * (0.8 + 2.6 * open)))
            lower.closeSubpath()
            ctx.fill(lower, with: .color(dark))
            var inner = ctx
            inner.clip(to: lower)
            inner.fill(Path(ellipseIn: CGRect(x: a.x - bw * 0.4, y: a.y + bh * 0.9, width: bw * 0.8, height: bh * 1.8 * open)), with: .color(Color(red: 0.98, green: 0.56, blue: 0.6)))
        } else if curve < -0.25 || p.rig.mouthWobble > 0.1 {
            // A small line under the beak carries the frown.
            var line = Path()
            line.move(to: CGPoint(x: a.x - bw * 0.55, y: a.y + bh * 1.2))
            line.addQuadCurve(to: CGPoint(x: a.x + bw * 0.55, y: a.y + bh * 1.2), control: CGPoint(x: a.x, y: a.y + bh * 1.2 + curve * bh * 1.4))
            ctx.stroke(line, with: .color(p.ink.opacity(0.55)), style: StrokeStyle(lineWidth: p.inkWidth * 0.8, lineCap: .round))
        }
    }
}
