import SwiftUI

/// Biscuit: a small white fluffy dog (a Maltese-poodle sort). A round, soft-edged head with a
/// top-knot, long curly ears that swing, a bearded muzzle, round dark eyes, a rosy nose, and
/// little tufts over the eyes that move with every feeling.
enum DogArt {
    static func head(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pal = p.palette, pose = p.pose
        let rx = fig.headRX, ry = fig.headRY
        let fx = CGFloat(pose.headTurn) * 7, fy = CGFloat(pose.headNod) * 5
        let badge = p.detail == .badge

        // Ears first where they join the head; the curls hang in front of the cheeks (drawn last).
        // Head: soft, with a top-knot of three curls.
        let skull = PetDraw.fluffy(.zero, rx, ry, bumps: badge ? 10 : 16, depth: badge ? 1.6 : 1.8, phase: 0.2)
            .union(PetDraw.fluffy(CGPoint(x: fx * 0.4, y: -ry + 2), 15, 10, bumps: 7, depth: 1.6))
        PetDraw.solid(ctx, skull, pal.coat, rim: p.rim, depth: 6)
        if !badge { PetDraw.highlight(ctx, CGRect(x: -rx * 0.55, y: -ry * 0.78, width: rx * 0.5, height: ry * 0.28), pal.coat, amount: 0.3) }

        // Muzzle: a fluffy, whiter beard around a rosy nose.
        let m = CGPoint(x: fx * 1.15, y: fig.mouthY + fy * 1.2)
        let beard = PetDraw.fluffy(CGPoint(x: m.x, y: m.y - 4), 19, 14, bumps: badge ? 8 : 12, depth: 1.5, phase: 0.3)
        PetDraw.solid(ctx, beard, pal.cream, rim: 0, depth: 2.5)

        QuadrupedArt.face(ctx, p, fig, fx: fx, fy: fy, skin: pal.coat, brows: nil)

        // Eyebrow tufts: little curls over the eyes that rise, tilt and knit with the mood.
        PetDraw.mirrored(ctx) { c, side in
            let near = CGFloat(pose.headTurn) * side
            let x = fig.eyeX + fx * (near > 0 ? 0.85 : 1.1) * side + 1
            let y = fig.eyeY + fy - fig.eyeH - 1.5 - CGFloat(pose.browRaise) * 2.5
            var tuft = c
            tuft.translateBy(x: x, y: y)
            tuft.rotate(by: .degrees(pose.browSlant * 24))
            tuft.fill(PetDraw.fluffy(.zero, badge ? 5 : 4.6, badge ? 3 : 2.6, bumps: 5, depth: 0.7), pal.marking.mix(pal.coat.shade, 0.35))
        }

        // Nose and mouth.
        let nose = PetDraw.ellipse(CGPoint(x: m.x, y: m.y - 9), badge ? 7 : 6.2, badge ? 5 : 4.4)
        ctx.fill(nose, pal.accent)
        if !badge { ctx.fill(PetDraw.ellipse(CGPoint(x: m.x - 2, y: m.y - 10.5), 2, 1.1), PetRGB(1, 1, 1, 0.55)) }
        var philtrum = Path()
        philtrum.move(to: CGPoint(x: m.x, y: m.y - 5))
        philtrum.addLine(to: CGPoint(x: m.x, y: m.y - 1.5))
        ctx.stroke(philtrum, pal.ink.alpha(0.8), width: p.ink * 0.6)
        PetDraw.mouth(ctx, at: CGPoint(x: m.x, y: m.y), width: 13, smile: pose.smile, open: pose.mouthOpen, round: pose.mouthRound,
                      ink: pal.ink, inside: PetRGB(0.5, 0.18, 0.2), tongue: pal.pink, stroke: p.ink * 0.8)

        // Ears: a column of curls hanging from the crown. They swing out when perked and hang
        // straight when low.
        PetDraw.mirrored(ctx) { c, side in
            let e = CGFloat(side > 0 ? pose.earR : pose.earL)
            var ear = c
            ear.translateBy(x: rx * 0.72 - fx * 0.2 * side + min(0, e) * 2, y: -ry * 0.5 - fy * 0.3 - min(0, e) * 4)
            ear.rotate(by: .degrees(Double(-6 - max(0, e) * 24 - min(0, e) * 6 + CGFloat(pose.headTilt) * 0.3 * side)))
            let curls: [(CGFloat, CGFloat, CGFloat)] = [(0, 0, 10), (3, 11, 11), (5, 23, 11.5), (3, 35, 10), (-1, 44, 7.5)]
            var shape = Path()
            for (i, (x, y, r)) in curls.enumerated() {
                shape = i == 0 ? PetDraw.fluffy(CGPoint(x: x, y: y), r, r, bumps: 6, depth: 1.2, phase: Double(i))
                               : shape.union(PetDraw.fluffy(CGPoint(x: x, y: y), r, r, bumps: 6, depth: 1.2, phase: Double(i)))
            }
            PetDraw.solid(ear, shape, pal.marking, rim: p.rim, depth: 3.5)
        }
    }
}
