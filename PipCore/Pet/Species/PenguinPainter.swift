import SwiftUI

/// Pebble — an upright little penguin: egg body, white front, flippers, orange feet.
public enum PenguinPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso
        let lying = CGFloat(p.rig.lying)

        // Feet.
        for side: CGFloat in [-1, 1] {
            let foot = CGRect(x: t.centerX + side * t.hipWidth * 0.18 - 14, y: t.bottom - 7 + lying * 2, width: 28, height: 11)
            ctx.fill(Path(ellipseIn: foot), with: .color(p.palette.nose))
        }

        // Egg body.
        var egg = Path()
        let top = CGPoint(x: t.centerX, y: t.top)
        let bottomY = t.bottom - 3
        egg.move(to: top)
        egg.addCurve(to: CGPoint(x: t.centerX + t.hipWidth / 2, y: t.top + t.height * 0.62),
                     control1: CGPoint(x: t.centerX + t.chestWidth * 0.55, y: t.top),
                     control2: CGPoint(x: t.centerX + t.hipWidth / 2, y: t.top + t.height * 0.28))
        egg.addCurve(to: CGPoint(x: t.centerX, y: bottomY),
                     control1: CGPoint(x: t.centerX + t.hipWidth / 2, y: bottomY),
                     control2: CGPoint(x: t.centerX + t.hipWidth * 0.3, y: bottomY))
        egg.addCurve(to: CGPoint(x: t.centerX - t.hipWidth / 2, y: t.top + t.height * 0.62),
                     control1: CGPoint(x: t.centerX - t.hipWidth * 0.3, y: bottomY),
                     control2: CGPoint(x: t.centerX - t.hipWidth / 2, y: bottomY))
        egg.addCurve(to: top,
                     control1: CGPoint(x: t.centerX - t.hipWidth / 2, y: t.top + t.height * 0.28),
                     control2: CGPoint(x: t.centerX - t.chestWidth * 0.55, y: t.top))
        egg.closeSubpath()
        PetDraw.fillFur(&ctx, p, path: egg, rect: CGRect(x: t.centerX - t.hipWidth / 2, y: t.top, width: t.hipWidth, height: t.height))

        // White front.
        var front = ctx
        front.clip(to: egg)
        let fw = t.hipWidth * 0.7, fh = t.height * 0.8
        front.fill(Path(ellipseIn: CGRect(x: t.centerX - fw / 2, y: t.bottom - fh - 6, width: fw, height: fh)), with: .color(p.palette.belly))

        // Flippers: down when calm, up when excited, flap with the wag.
        let lift = CGFloat(p.rig.tailLift)
        let wag = CGFloat(p.live.tailWag)
        for side: CGFloat in [-1, 1] {
            let root = CGPoint(x: t.centerX + side * t.hipWidth * 0.46, y: t.top + t.height * 0.36)
            let angle = side * (0.3 - lift * 1.2 + wag * 0.5)
            let len = t.height * 0.44
            let tip = CGPoint(x: root.x + sin(angle) * len, y: root.y + cos(angle) * len)
            let w: CGFloat = 13
            var fl = Path()
            fl.move(to: CGPoint(x: root.x - side * w * 0.3, y: root.y - w * 0.4))
            fl.addQuadCurve(to: tip, control: CGPoint(x: root.x + side * w * 1.5 + (tip.x - root.x) * 0.5, y: root.y + (tip.y - root.y) * 0.4))
            fl.addQuadCurve(to: CGPoint(x: root.x - side * w * 0.3, y: root.y + w * 0.5), control: CGPoint(x: root.x - side * w * 0.1 + (tip.x - root.x) * 0.5, y: root.y + (tip.y - root.y) * 0.6))
            fl.closeSubpath()
            ctx.fill(fl, with: .linearGradient(Gradient(colors: [p.palette.bodyTop, p.palette.bodyBottom]), startPoint: root, endPoint: tip))
        }

        // Head sits on the egg.
        var hc = PetDraw.headContext(ctx, p)
        let h = p.head
        let head = PetDraw.headPath(h)
        PetDraw.fillFur(&hc, p, path: head, rect: h.rect)

        // White face mask.
        var mask = hc
        mask.clip(to: head)
        let mw = h.width * 0.78, mh = h.height * 0.72
        mask.fill(Path(ellipseIn: CGRect(x: h.center.x - mw / 2, y: h.center.y - mh * 0.34, width: mw, height: mh)), with: .color(p.palette.belly))

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.21
        layout.eyeY = 0.02
        layout.eyeRadius = 0.09
        layout.mouthY = 0.28
        layout.blushX = 0.34
        layout.blushY = 0.18
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout, lidColor: p.palette.belly)
        PetDraw.brows(&hc, p, layout: layout)

        // Beak.
        let open = CGFloat(p.rig.mouthOpen)
        let curve = CGFloat(p.rig.mouthCurve)
        let bx = h.center.x, by = h.center.y + h.height * layout.mouthY
        let bw = h.width * 0.15, bh = h.height * 0.09
        var upper = Path()
        upper.move(to: CGPoint(x: bx - bw, y: by - bh * 0.2 - curve * 2))
        upper.addQuadCurve(to: CGPoint(x: bx + bw, y: by - bh * 0.2 - curve * 2), control: CGPoint(x: bx, y: by - bh * 1.2))
        upper.addQuadCurve(to: CGPoint(x: bx - bw, y: by - bh * 0.2 - curve * 2), control: CGPoint(x: bx, y: by + bh * 0.6 - curve * bh * 0.6))
        hc.fill(upper, with: .color(p.palette.nose))
        if open > 0.08 {
            var lower = Path()
            lower.move(to: CGPoint(x: bx - bw * 0.8, y: by + bh * 0.1))
            lower.addQuadCurve(to: CGPoint(x: bx + bw * 0.8, y: by + bh * 0.1), control: CGPoint(x: bx, y: by + bh * (0.6 + 2.2 * open)))
            lower.closeSubpath()
            hc.fill(lower, with: .color(Color(red: 0.85, green: 0.5, blue: 0.2)))
        } else if p.rig.mouthWobble > 0.1 || curve < -0.3 {
            var line = Path()
            line.move(to: CGPoint(x: bx - bw * 0.5, y: by + bh * 0.9))
            line.addQuadCurve(to: CGPoint(x: bx + bw * 0.5, y: by + bh * 0.9), control: CGPoint(x: bx, y: by + bh * 0.9 + curve * bh * 1.2))
            hc.stroke(line, with: .color(p.palette.eye.opacity(0.6)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }

        PetDraw.sweat(&hc, p)
    }
}
