import SwiftUI

/// Biscuit's head: round, with a cream muzzle, a dark button nose, brown brow spots that move
/// with every feeling, and long ears that swing.
enum DogArt {
    static func head(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pal = p.palette, pose = p.pose
        let rx = fig.headRX, ry = fig.headRY
        let fx = CGFloat(pose.headTurn) * 7, fy = CGFloat(pose.headNod) * 5
        let badge = p.detail == .badge

        let skull = PetDraw.ellipse(.zero, rx, ry)
        PetDraw.solid(ctx, skull, pal.coat, rim: p.rim, depth: 6)
        if !badge { PetDraw.highlight(ctx, CGRect(x: -rx * 0.58, y: -ry * 0.82, width: rx * 0.5, height: ry * 0.3), pal.coat, amount: 0.16) }

        var face = ctx
        face.clip(to: skull)
        // A cream blaze down the forehead into the muzzle.
        var blaze = Path()
        blaze.move(to: CGPoint(x: fx * 0.5 - 4, y: -ry))
        blaze.addQuadCurve(to: CGPoint(x: fx - 9, y: fig.mouthY - 12 + fy), control: CGPoint(x: fx * 0.7 - 7, y: -10 + fy))
        blaze.addLine(to: CGPoint(x: fx + 9, y: fig.mouthY - 12 + fy))
        blaze.addQuadCurve(to: CGPoint(x: fx * 0.5 + 4, y: -ry), control: CGPoint(x: fx * 0.7 + 7, y: -10 + fy))
        face.fill(blaze, pal.cream)

        let m = CGPoint(x: fx * 1.15, y: fig.mouthY + fy * 1.2)
        let muzzle = PetDraw.ellipse(CGPoint(x: m.x, y: m.y - 5), 20, 14.5)
        PetDraw.solid(face, muzzle, pal.cream, rim: 0, depth: 3)

        QuadrupedArt.face(ctx, p, fig, fx: fx, fy: fy, skin: pal.coat, brows: nil)

        // Brow spots: two small marks above the eyes that rise, tilt and knit with the mood.
        if !badge {
            PetDraw.mirrored(ctx) { c, side in
                let near = CGFloat(pose.headTurn) * side
                let x = fig.eyeX + fx * (near > 0 ? 0.85 : 1.1) * side + 1
                let y = fig.eyeY + fy - fig.eyeH - 1.5 - CGFloat(pose.browRaise) * 2.5
                var spot = c
                spot.translateBy(x: x, y: y)
                spot.rotate(by: .degrees(pose.browSlant * 24))
                spot.fill(PetDraw.ellipse(.zero, 4.6, 2.9), pal.marking)
            }
        }

        // Nose and mouth.
        let nose = PetDraw.ellipse(CGPoint(x: m.x, y: m.y - 9), badge ? 7.5 : 6.5, badge ? 5 : 4.4)
        ctx.fill(nose, pal.accent)
        if !badge { ctx.fill(PetDraw.ellipse(CGPoint(x: m.x - 2, y: m.y - 10.5), 2, 1.1), PetRGB(1, 1, 1, 0.5)) }
        var philtrum = Path()
        philtrum.move(to: CGPoint(x: m.x, y: m.y - 5))
        philtrum.addLine(to: CGPoint(x: m.x, y: m.y - 1))
        ctx.stroke(philtrum, pal.ink, width: p.ink * 0.7)
        PetDraw.mouth(ctx, at: CGPoint(x: m.x, y: m.y), width: 14, smile: pose.smile, open: pose.mouthOpen, round: pose.mouthRound,
                      ink: pal.ink, inside: PetRGB(0.5, 0.18, 0.2), tongue: pal.pink, stroke: p.ink * 0.8)

        // Ears last, over the sides of the head: they hang from the crown and swing out when perked.
        PetDraw.mirrored(ctx) { c, side in
            let e = CGFloat(side > 0 ? pose.earR : pose.earL)
            var ear = c
            // Perked ears swing out; low ears hang straight down against the head.
            ear.translateBy(x: rx * 0.66 - fx * 0.2 * side + min(0, e) * 2, y: -ry * 0.62 - fy * 0.3 - min(0, e) * 5)
            ear.rotate(by: .degrees(Double(-8 - max(0, e) * 26 - min(0, e) * 8 + CGFloat(pose.headTilt) * 0.3 * side)))
            let len: CGFloat = 44 - max(0, e) * 6
            var flap = Path()
            flap.move(to: CGPoint(x: -8, y: -4))
            flap.addQuadCurve(to: CGPoint(x: 14, y: len - 6), control: CGPoint(x: 20, y: len * 0.2))
            flap.addQuadCurve(to: CGPoint(x: 0, y: len), control: CGPoint(x: 12, y: len + 3))
            flap.addQuadCurve(to: CGPoint(x: -8, y: -4), control: CGPoint(x: -12, y: len * 0.45))
            flap.closeSubpath()
            PetDraw.solid(ear, flap, pal.marking, rim: p.rim, depth: 3)
        }
    }
}
