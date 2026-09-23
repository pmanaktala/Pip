import SwiftUI

/// Mochi's head: wide and cheeky, triangle ears that flatten and perk, three forehead stripes,
/// a small pink nose over a "w" mouth, and whiskers at full size.
enum CatArt {
    static func head(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pal = p.palette, pose = p.pose
        let rx = fig.headRX, ry = fig.headRY
        let fx = CGFloat(pose.headTurn) * 7, fy = CGFloat(pose.headNod) * 5
        let badge = p.detail == .badge

        // Ears, behind the head. Perked ears stand tall; flattened ones swing out and down.
        PetDraw.mirrored(ctx) { c, side in
            let e = CGFloat(side > 0 ? pose.earR : pose.earL)
            var ear = c
            ear.translateBy(x: 27 - fx * 0.3 * side, y: -26 - fy * 0.4)
            ear.rotate(by: .degrees(Double(14 - e * 12 + max(0, -e) * 26)))
            let h: CGFloat = 30 + e * 3
            var outer = Path()
            outer.move(to: CGPoint(x: -15, y: 6))
            outer.addQuadCurve(to: CGPoint(x: 2, y: -h), control: CGPoint(x: -10, y: -h * 0.6))
            outer.addQuadCurve(to: CGPoint(x: 17, y: 6), control: CGPoint(x: 14, y: -h * 0.5))
            outer.closeSubpath()
            PetDraw.solid(ear, outer, pal.coat, rim: p.rim, depth: 3)
            if !badge || true {
                var inner = Path()
                inner.move(to: CGPoint(x: -8, y: 4))
                inner.addQuadCurve(to: CGPoint(x: 2, y: -h * 0.66), control: CGPoint(x: -5, y: -h * 0.4))
                inner.addQuadCurve(to: CGPoint(x: 10, y: 4), control: CGPoint(x: 8, y: -h * 0.3))
                inner.closeSubpath()
                ear.fill(inner, pal.pink)
            }
        }

        // The head: wider than tall, with full cheeks.
        var skull = Path()
        skull.move(to: CGPoint(x: 0, y: -ry))
        skull.addCurve(to: CGPoint(x: rx, y: 4), control1: CGPoint(x: rx * 0.78, y: -ry), control2: CGPoint(x: rx, y: -ry * 0.45))
        skull.addCurve(to: CGPoint(x: 0, y: ry), control1: CGPoint(x: rx, y: ry * 0.62), control2: CGPoint(x: rx * 0.62, y: ry))
        skull.addCurve(to: CGPoint(x: -rx, y: 4), control1: CGPoint(x: -rx * 0.62, y: ry), control2: CGPoint(x: -rx, y: ry * 0.62))
        skull.addCurve(to: CGPoint(x: 0, y: -ry), control1: CGPoint(x: -rx, y: -ry * 0.45), control2: CGPoint(x: -rx * 0.78, y: -ry))
        skull.closeSubpath()
        PetDraw.solid(ctx, skull, pal.coat, rim: p.rim, depth: 6)
        if !badge { PetDraw.highlight(ctx, CGRect(x: -rx * 0.6, y: -ry * 0.8, width: rx * 0.5, height: ry * 0.3), pal.coat, amount: 0.16) }

        var face = ctx
        face.clip(to: skull)
        // Forehead stripes.
        for (dx, len) in [(CGFloat(-10), CGFloat(8)), (0, 11), (10, 8)] {
            var s = Path()
            s.move(to: CGPoint(x: dx + fx * 0.6, y: -ry + 1 + fy * 0.3))
            s.addLine(to: CGPoint(x: dx * 0.9 + fx * 0.6, y: -ry + 1 + len + fy * 0.3))
            face.stroke(s, pal.marking, width: badge ? 4 : 3.4)
        }
        // Muzzle: two cream puffs under the nose and a small chin.
        let m = CGPoint(x: fx * 1.15, y: fig.mouthY - 3 + fy * 1.2)
        let muzzle = PetDraw.ellipse(CGPoint(x: m.x - 7, y: m.y + 2), 10, 7.5).union(PetDraw.ellipse(CGPoint(x: m.x + 7, y: m.y + 2), 10, 7.5))
        face.fill(muzzle, pal.cream)

        QuadrupedArt.face(ctx, p, fig, fx: fx, fy: fy, skin: pal.coat, brows: pal.ink.alpha(0.8))

        // Nose and mouth.
        var nose = Path()
        nose.move(to: CGPoint(x: m.x - 4, y: m.y - 3.2))
        nose.addQuadCurve(to: CGPoint(x: m.x + 4, y: m.y - 3.2), control: CGPoint(x: m.x, y: m.y - 4.6))
        nose.addQuadCurve(to: CGPoint(x: m.x, y: m.y + 0.8), control: CGPoint(x: m.x + 3, y: m.y - 1))
        nose.addQuadCurve(to: CGPoint(x: m.x - 4, y: m.y - 3.2), control: CGPoint(x: m.x - 3, y: m.y - 1))
        ctx.fill(nose, pal.pink.mix(PetRGB(0.8, 0.35, 0.4), 0.3))
        PetDraw.mouth(ctx, at: CGPoint(x: m.x, y: m.y + 4), width: 11, smile: pose.smile, open: pose.mouthOpen, round: pose.mouthRound,
                      ink: pal.ink, inside: PetRGB(0.52, 0.2, 0.24), tongue: pal.pink, stroke: p.ink * 0.8, catLike: true)

        // Whiskers at full size only.
        if p.detail == .full {
            PetDraw.mirrored(ctx) { c, side in
                for (i, dy) in [CGFloat(-1), 4].enumerated() {
                    var w = Path()
                    let sx = 20 + fx * side * 0.6
                    w.move(to: CGPoint(x: sx, y: m.y + dy))
                    w.addQuadCurve(to: CGPoint(x: sx + 17, y: m.y + dy - 3 + CGFloat(i) * 5), control: CGPoint(x: sx + 9, y: m.y + dy - 2))
                    c.stroke(w, pal.ink.alpha(0.35), width: 1.1)
                }
            }
        }
    }
}
