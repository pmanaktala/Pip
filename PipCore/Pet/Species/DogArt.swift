import SwiftUI

/// Biscuit: a small white fluffy dog (a Maltese-poodle sort). A smooth round head that gets its
/// fluff from a few deliberate tufts — soft bangs and cheek fluff — long drop ears with a wavy
/// hem and a hint of apricot, round dark eyes close to a rosy nose, and a small beard.
enum DogArt {
    static func head(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pal = p.palette, pose = p.pose
        let rx = fig.headRX, ry = fig.headRY
        let fx = CGFloat(pose.headTurn) * 7, fy = CGFloat(pose.headNod) * 5
        let badge = p.detail == .badge

        // Head: round, a little wider at the cheeks, with two tufts of cheek fluff.
        var skull = Path()
        skull.move(to: CGPoint(x: 0, y: -ry))
        skull.addCurve(to: CGPoint(x: rx, y: 2), control1: CGPoint(x: rx * 0.72, y: -ry), control2: CGPoint(x: rx, y: -ry * 0.5))
        skull.addCurve(to: CGPoint(x: 0, y: ry), control1: CGPoint(x: rx, y: ry * 0.62), control2: CGPoint(x: rx * 0.6, y: ry))
        skull.addCurve(to: CGPoint(x: -rx, y: 2), control1: CGPoint(x: -rx * 0.6, y: ry), control2: CGPoint(x: -rx, y: ry * 0.62))
        skull.addCurve(to: CGPoint(x: 0, y: -ry), control1: CGPoint(x: -rx, y: -ry * 0.5), control2: CGPoint(x: -rx * 0.72, y: -ry))
        skull.closeSubpath()
        var head = skull
        for side in [CGFloat(1), -1] {
            head = head.union(tuft(at: CGPoint(x: side * rx * 0.86, y: ry * 0.42), size: 9, side: side))
        }
        // A little cowlick at the crown.
        head = head.union(tuft(at: CGPoint(x: -3 + fx * 0.3, y: -ry + 1), size: 7.5, side: -1))
            .union(tuft(at: CGPoint(x: 4 + fx * 0.3, y: -ry + 2), size: 6, side: 1))
        PetDraw.solid(ctx, head, pal.coat, rim: p.rim, depth: 5)
        if !badge { PetDraw.highlight(ctx, CGRect(x: -rx * 0.55, y: -ry * 0.8, width: rx * 0.45, height: ry * 0.26), pal.coat, amount: 0.35) }

        // Soft bangs over the brow, parted a little by the head turn.
        var bangs = Path()
        let by = -ry * 0.52 + fy * 0.3
        bangs.move(to: CGPoint(x: -rx * 0.55 + fx * 0.3, y: -ry * 0.8))
        let points: [CGFloat] = [-0.5, -0.22, 0.06, 0.34, 0.58]
        for (i, u) in points.enumerated() {
            let x = rx * u + fx * 0.4
            bangs.addQuadCurve(to: CGPoint(x: x + rx * 0.14, y: by - CGFloat(i % 2) * 2),
                               control: CGPoint(x: x + rx * 0.07, y: by + 7))
        }
        bangs.addQuadCurve(to: CGPoint(x: -rx * 0.55 + fx * 0.3, y: -ry * 0.8), control: CGPoint(x: fx * 0.3, y: -ry * 1.12))
        bangs.closeSubpath()
        var inHead = ctx
        inHead.clip(to: skull)
        inHead.fill(bangs, pal.coat.shade.mix(pal.coat, 0.55))
        inHead.fill(bangs.offsetBy(dx: 0, dy: -1.8), pal.coat)

        // Muzzle: a soft lighter oval with a small beard below.
        let m = CGPoint(x: fx * 1.15, y: fig.mouthY + fy * 1.2)
        let muzzle = PetDraw.ellipse(CGPoint(x: m.x, y: m.y - 6), 16, 12)
            .union(tuft(at: CGPoint(x: m.x - 5, y: m.y + 4), size: 6, side: -1))
            .union(tuft(at: CGPoint(x: m.x + 5, y: m.y + 4), size: 6, side: 1))
        inHead.fill(muzzle, pal.cream)

        QuadrupedArt.face(ctx, p, fig, fx: fx, fy: fy, skin: pal.coat, brows: nil)

        // Brow tufts: little curls over the eyes that rise, tilt and knit with the mood.
        PetDraw.mirrored(ctx) { c, side in
            let near = CGFloat(pose.headTurn) * side
            let x = fig.eyeX + fx * (near > 0 ? 0.85 : 1.1) * side + 1
            let y = fig.eyeY + fy - fig.eyeH - 1 - CGFloat(pose.browRaise) * 2.5
            var brow = c
            brow.translateBy(x: x, y: y)
            brow.rotate(by: .degrees(pose.browSlant * 24))
            brow.fill(PetDraw.ellipse(.zero, badge ? 4.6 : 4, badge ? 2.6 : 2.1), pal.marking.mix(pal.coat.shade, 0.5).alpha(0.9))
        }

        // Nose and mouth.
        let nose = PetDraw.ellipse(CGPoint(x: m.x, y: m.y - 9), badge ? 6.2 : 5.4, badge ? 4.4 : 3.8)
        ctx.fill(nose, pal.accent)
        if !badge { ctx.fill(PetDraw.ellipse(CGPoint(x: m.x - 1.8, y: m.y - 10.3), 1.6, 0.9), PetRGB(1, 1, 1, 0.55)) }
        var philtrum = Path()
        philtrum.move(to: CGPoint(x: m.x, y: m.y - 5.5))
        philtrum.addLine(to: CGPoint(x: m.x, y: m.y - 2))
        ctx.stroke(philtrum, pal.ink.alpha(0.7), width: p.ink * 0.55)
        PetDraw.mouth(ctx, at: CGPoint(x: m.x, y: m.y - 1), width: 12, smile: pose.smile, open: pose.mouthOpen, round: pose.mouthRound,
                      ink: pal.ink, inside: PetRGB(0.5, 0.18, 0.2), tongue: pal.pink, stroke: p.ink * 0.75)

        // Ears: a column of soft curls hanging from the crown. They swing out when perked and
        // hang straight when low.
        PetDraw.mirrored(ctx) { c, side in
            let e = CGFloat(side > 0 ? pose.earR : pose.earL)
            var ear = c
            ear.translateBy(x: rx * 0.74 - fx * 0.2 * side + min(0, e) * 2, y: -ry * 0.52 - fy * 0.3 - min(0, e) * 4)
            ear.rotate(by: .degrees(Double(-6 - max(0, e) * 24 - min(0, e) * 6 + CGFloat(pose.headTilt) * 0.3 * side)))
            let curls: [(CGFloat, CGFloat, CGFloat)] = [(0, 0, 9.5), (3, 11, 10.5), (4.5, 22.5, 11), (3, 34, 9.5), (-0.5, 43, 7)]
            var shape = Path()
            for (i, (x, y, r)) in curls.enumerated() {
                let curl = PetDraw.fluffy(CGPoint(x: x, y: y), r, r, bumps: 6, depth: 1.1, phase: Double(i))
                shape = i == 0 ? curl : shape.union(curl)
            }
            PetDraw.solid(ear, shape, pal.marking, rim: p.rim, depth: 3.5)
        }
    }

    /// A small tuft of fur: three soft points fanning outward.
    static func tuft(at c: CGPoint, size s: CGFloat, side: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x - s * 0.9 * side, y: c.y - s * 0.7))
        p.addQuadCurve(to: CGPoint(x: c.x + s * 0.9 * side, y: c.y - s * 0.2), control: CGPoint(x: c.x + s * 0.5 * side, y: c.y - s * 1.1))
        p.addQuadCurve(to: CGPoint(x: c.x + s * 0.5 * side, y: c.y + s * 0.5), control: CGPoint(x: c.x + s * 1.1 * side, y: c.y + s * 0.3))
        p.addQuadCurve(to: CGPoint(x: c.x - s * 0.1 * side, y: c.y + s * 0.8), control: CGPoint(x: c.x + s * 0.3 * side, y: c.y + s * 0.9))
        p.addQuadCurve(to: CGPoint(x: c.x - s * 0.9 * side, y: c.y - s * 0.7), control: CGPoint(x: c.x - s * 0.9 * side, y: c.y + s * 0.3))
        p.closeSubpath()
        return p
    }
}
