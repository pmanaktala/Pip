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
        PetDraw.plush(&ctx, silhouette, p)

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
        front.fill(belly.union(bridge).union(face), with: .linearGradient(Gradient(colors: [.white, p.palette.belly, Color(red: 0.85, green: 0.87, blue: 0.87)]), startPoint: CGPoint(x: h.center.x - 20, y: h.top), endPoint: CGPoint(x: t.centerX + 35, y: t.bottom + 30)))

        // Flippers: short, tapered. Rest hangs beside the body; the same blend as `PetDraw.armEnd`
        // drives them so every pose (cheer, hold, type, wipe) means the same thing on a penguin.
        PetDraw.mirrored(&ctx) { ctx, side in
            let f = flipper(p, side: side)
            let normal = CGPoint(x: f.dir.y, y: -f.dir.x)
            let w: CGFloat = 14
            var fl = Path()
            fl.move(to: CGPoint(x: f.root.x - normal.x * w * 0.5, y: f.root.y - normal.y * w * 0.5))
            fl.addQuadCurve(to: f.tip, control: CGPoint(x: f.root.x - normal.x * w * 0.7 + f.dir.x * f.length * 0.55, y: f.root.y - normal.y * w * 0.7 + f.dir.y * f.length * 0.55))
            fl.addQuadCurve(to: CGPoint(x: f.root.x + normal.x * w * 0.5, y: f.root.y + normal.y * w * 0.5), control: CGPoint(x: f.root.x + normal.x * w * 0.5 + f.dir.x * f.length * 0.55, y: f.root.y + normal.y * w * 0.5 + f.dir.y * f.length * 0.55))
            fl.closeSubpath()
            ctx.fill(fl, with: .linearGradient(Gradient(colors: [p.palette.base, p.palette.shade]),
                startPoint: CGPoint(x: f.root.x, y: f.root.y - 8), endPoint: f.tip))
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

    /// Right-side flipper geometry for the rig. Angles are from straight down: rest 0.2, a full raise
    /// ~2.2 (up past horizontal; a half raise stays below it), a spread ~0.7, forward folds it down and
    /// in (foreshortened), a hold brings it across the chest, "to face" swings it up and inward.
    static func flipper(_ p: PetPaintContext, side: CGFloat) -> (root: CGPoint, tip: CGPoint, dir: CGPoint, length: CGFloat) {
        let t = p.torso, rig = p.rig
        let lying = CGFloat(rig.lying)
        let cross = CGFloat(rig.armCross).clamped(0, 1)
        let sym = CGFloat(rig.armSymmetric).clamped(0, 1)
        let raise = CGFloat(rig.armRaise).clamped(0, 1) * (side == 1 ? 1 : 0.3 + 0.7 * sym)
        let out = CGFloat(rig.armOut).clamped(0, 1)
        let forward = CGFloat(rig.armForward).clamped(0, 1)
        let hold = CGFloat(rig.armHold).clamped(0, 1)
        let face = side == -1 ? CGFloat(rig.armToFace).clamped(0, 1) : 0
        let swing = CGFloat(p.live.armSwing)
        let lift = swing * side * forward + swing * (1 - forward)

        let root = CGPoint(x: t.centerX + t.hipWidth * 0.42, y: t.top + t.height * 0.3)
        var len = t.height * 0.46 * (1 - 0.2 * lying)
        var angle: CGFloat = 0.2 + raise * 2.0 + out * 0.5 + lift * 0.3 * (0.3 + raise + out)
        angle = angle * (1 - forward) + (-0.05 + max(0, lift) * 0.25) * forward
        len *= 1 - 0.2 * forward
        // Held across the chest; a raise inside the hold bends the tip up toward the page's top corner.
        let climb = CGFloat(rig.armRaise).clamped(0, 1) * (side == 1 ? 1 : sym)
        angle = angle * (1 - hold) + (-0.75 - climb * 0.6) * hold
        len *= 1 - 0.1 * hold - 0.15 * hold * climb
        angle = angle * (1 - face) + 3.7 * face
        len *= 1 - 0.2 * face
        angle = angle * (1 - cross) + (-0.55) * cross
        let dir = CGPoint(x: sin(angle), y: cos(angle))
        let tip = CGPoint(x: root.x + dir.x * len, y: root.y + dir.y * len)
        return (root, tip, dir, len)
    }

    /// A flipper's tip as right-side geometry (the hand, for held props); the caller mirrors for the left.
    public static func flipperTip(_ p: PetPaintContext, side: CGFloat) -> CGPoint {
        flipper(p, side: side).tip
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
