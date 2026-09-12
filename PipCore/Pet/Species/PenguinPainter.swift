import SwiftUI

/// Pebble — an upright, chaotic little penguin. Flippers stand in for a tail.
public enum PenguinPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let b = p.body
        let body = PetDraw.blobPath(b)

        // Feet.
        for side: CGFloat in [-1, 1] {
            let foot = CGRect(x: b.center.x + side * b.width * 0.16 - b.width * 0.13, y: b.bottom - b.height * 0.06, width: b.width * 0.26, height: b.height * 0.1)
            ctx.fill(Path(ellipseIn: foot), with: .color(p.palette.nose))
        }

        PetDraw.fillBody(&ctx, p, path: body)

        // White face + belly patch.
        var inner = ctx
        inner.clip(to: body)
        let faceW = b.width * 0.72, faceH = b.height * 0.86
        var face = Path()
        let fr = CGRect(x: b.center.x - faceW / 2, y: b.center.y - b.height * 0.28, width: faceW, height: faceH)
        face.addEllipse(in: fr)
        inner.fill(face, with: .linearGradient(Gradient(colors: [p.palette.belly, p.palette.belly.opacity(0.92)]), startPoint: CGPoint(x: fr.midX, y: fr.minY), endPoint: CGPoint(x: fr.midX, y: fr.maxY)))

        // Flippers: hang when calm, lift when excited (tailLift) and flap with the wag.
        let lift = CGFloat(p.rig.tailLift)
        let wag = CGFloat(p.live.tailWag)
        for side: CGFloat in [-1, 1] {
            let root = b.point(side * 0.44, -0.02)
            let angle = side * (0.35 - lift * 1.1 + wag * 0.5) // radians from straight down
            let len = b.height * 0.42
            let tip = CGPoint(x: root.x + sin(angle) * len, y: root.y + cos(angle) * len)
            let w = b.width * 0.13
            var fl = Path()
            fl.move(to: CGPoint(x: root.x - side * w * 0.3, y: root.y - w * 0.3))
            fl.addQuadCurve(to: tip, control: CGPoint(x: root.x + side * w * 1.4 + (tip.x - root.x) * 0.5, y: root.y + (tip.y - root.y) * 0.4))
            fl.addQuadCurve(to: CGPoint(x: root.x - side * w * 0.3, y: root.y + w * 0.5), control: CGPoint(x: root.x - side * w * 0.1 + (tip.x - root.x) * 0.5, y: root.y + (tip.y - root.y) * 0.6))
            fl.closeSubpath()
            ctx.fill(fl, with: .linearGradient(Gradient(colors: [p.palette.bodyTop, p.palette.bodyBottom]), startPoint: root, endPoint: tip))
        }

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.2
        layout.eyeY = -0.12
        layout.eyeRadius = 0.078
        layout.mouthY = 0.06
        layout.blushX = 0.31
        layout.blushY = 0.0
        PetDraw.blush(&ctx, p, layout: layout)
        PetDraw.eyes(&ctx, p, layout: layout, lidColor: p.palette.belly)
        PetDraw.brows(&ctx, p, layout: layout)

        // Beak: a soft diamond that opens with the mouth.
        let open = CGFloat(p.rig.mouthOpen)
        let curve = CGFloat(p.rig.mouthCurve)
        let bx = b.center.x, by = b.center.y + b.height * layout.mouthY
        let bw = b.width * 0.13, bh = b.height * 0.07
        var upper = Path()
        upper.move(to: CGPoint(x: bx - bw, y: by - bh * 0.2 + curve * -2))
        upper.addQuadCurve(to: CGPoint(x: bx + bw, y: by - bh * 0.2 + curve * -2), control: CGPoint(x: bx, y: by - bh * 1.2))
        upper.addQuadCurve(to: CGPoint(x: bx - bw, y: by - bh * 0.2 + curve * -2), control: CGPoint(x: bx, y: by + bh * 0.6 - curve * bh * 0.6))
        ctx.fill(upper, with: .color(p.palette.nose))
        if open > 0.08 {
            var lower = Path()
            lower.move(to: CGPoint(x: bx - bw * 0.8, y: by + bh * 0.1))
            lower.addQuadCurve(to: CGPoint(x: bx + bw * 0.8, y: by + bh * 0.1), control: CGPoint(x: bx, y: by + bh * (0.6 + 2.2 * open)))
            lower.closeSubpath()
            ctx.fill(lower, with: .color(Color(red: 0.85, green: 0.5, blue: 0.2)))
        } else if p.rig.mouthWobble > 0.1 || curve < -0.3 {
            // A worried little line under the beak.
            var line = Path()
            line.move(to: CGPoint(x: bx - bw * 0.5, y: by + bh * 0.9))
            line.addQuadCurve(to: CGPoint(x: bx + bw * 0.5, y: by + bh * 0.9), control: CGPoint(x: bx, y: by + bh * 0.9 + curve * bh * 1.2))
            ctx.stroke(line, with: .color(p.palette.eye.opacity(0.6)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }

        PetDraw.sweat(&ctx, p)
    }
}
