import SwiftUI

/// Pebble. An egg of a body, a big round head with a cream heart of a face, flippers, apricot
/// feet and a small beak. No ears, so the flippers and lids do the talking.
enum PenguinArt {
    static func body(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pal = p.palette, pose = p.pose
        let floor = PetFigure.floor
        let breathe = CGFloat(pose.breath) * 1.6

        // Feet first; the body sits on them.
        let cross = CGFloat(pose.crossLegs)
        func feet() {
            PetDraw.mirrored(ctx, axis: 100) { c, side in
                let step = CGFloat(side > 0 ? pose.stepR : pose.stepL)
                // Cross-legged, the feet turn in and overlap in front of the belly.
                var f = c
                f.translateBy(x: 100 + 17 - cross * 11 + CGFloat(pose.turn) * 3 * side, y: floor - 2 - step - cross * 5)
                f.rotate(by: .degrees(Double(-cross * 30)))
                PetDraw.solid(f, PetDraw.ellipse(.zero, 12.5, 5.5), pal.accent, rim: p.rim, depth: 2.5)
            }
        }
        if cross < 0.3 { feet() }

        // The egg: widest low down, narrowing into the head.
        let w: CGFloat = 44 + breathe, top: CGFloat = 78 - breathe * 0.6, bottom = floor - 4
        var egg = Path()
        egg.move(to: CGPoint(x: 100, y: top))
        egg.addCurve(to: CGPoint(x: 100 + w, y: 132), control1: CGPoint(x: 100 + w * 0.55, y: top), control2: CGPoint(x: 100 + w, y: 100))
        egg.addCurve(to: CGPoint(x: 100, y: bottom), control1: CGPoint(x: 100 + w, y: 157), control2: CGPoint(x: 100 + w * 0.58, y: bottom))
        egg.addCurve(to: CGPoint(x: 100 - w, y: 132), control1: CGPoint(x: 100 - w * 0.58, y: bottom), control2: CGPoint(x: 100 - w, y: 157))
        egg.addCurve(to: CGPoint(x: 100, y: top), control1: CGPoint(x: 100 - w, y: 100), control2: CGPoint(x: 100 - w * 0.55, y: top))
        egg.closeSubpath()
        PetDraw.solid(ctx, egg, pal.coat, rim: p.rim, depth: 7)

        // Belly.
        var belly = ctx
        belly.clip(to: egg)
        let bx = 100 + CGFloat(pose.turn) * 6
        let bellyPath = PetDraw.ellipse(CGPoint(x: bx, y: 134), 31 + breathe * 0.8, 32 + breathe * 0.5)
        PetDraw.solid(belly, bellyPath, pal.cream, rim: 0, depth: 4)
        if cross >= 0.3 { feet() }
    }

    static func flipper(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, angle: Double) {
        let root = CGPoint(x: 100 + fig.shoulder.x - 3, y: fig.shoulder.y)
        let tipOffset = fig.paw(.penguin, angle: angle)
        let tip = CGPoint(x: 100 + tipOffset.x, y: tipOffset.y)
        // The flipper bows away from the body as it rises.
        let bend: CGFloat = angle < 0 ? -4 : -6 + CGFloat(min(angle, 90) / 90) * 2
        let path = PetDraw.limb(from: root, to: tip, bend: bend, rootWidth: 17, tipWidth: 9)
        PetDraw.solid(ctx, path, p.palette.coat, rim: p.rim, depth: 3.5)
    }

    static func head(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pal = p.palette, pose = p.pose
        let rx = fig.headRX, ry = fig.headRY
        let turn = CGFloat(pose.headTurn), nod = CGFloat(pose.headNod)
        let badge = p.detail == .badge

        let skull = PetDraw.ellipse(.zero, rx, ry)
        PetDraw.solid(ctx, skull, pal.coat, rim: p.rim, depth: 6)
        if !badge { PetDraw.highlight(ctx, CGRect(x: -rx * 0.62, y: -ry * 0.82, width: rx * 0.52, height: ry * 0.32), pal.coat, amount: 0.12) }

        // Face: two lobes around the eyes flowing into a rounded chin, sliding with the turn.
        let fx = turn * 7, fy = nod * 5
        var face = ctx
        face.clip(to: skull)
        let lobes = PetDraw.ellipse(CGPoint(x: fx + 13.5, y: fy - 1), 16.5, 17.5)
            .union(PetDraw.ellipse(CGPoint(x: fx - 13.5, y: fy - 1), 16.5, 17.5))
            .union(PetDraw.ellipse(CGPoint(x: fx, y: fy + 13), 23, 17))
        PetDraw.solid(face, lobes, pal.cream, rim: 0, depth: 3)

        // Cheeks.
        if pose.blush > 0.01 {
            PetDraw.mirrored(ctx) { c, side in
                c.fill(PetDraw.ellipse(CGPoint(x: fig.blushX + fx * (side > 0 ? 0.8 : 1.2) * side, y: fig.blushY + fy), 4.6, 2.8), pal.blush.alpha(pal.blush.a * pose.blush))
            }
        }

        eyes(ctx, p, fig, skin: pal.cream, fx: fx, fy: fy)
        beak(ctx, p, fig, at: CGPoint(x: fx * 1.15, y: fig.mouthY + fy * 1.2))
    }

    static func eyes(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, skin: PetRGB, fx: CGFloat, fy: CGFloat) {
        let pose = p.pose
        let badge = p.detail == .badge
        let style = PetDraw.EyeStyle(width: fig.eyeW * (badge ? 1.15 : 1), height: fig.eyeH * (badge ? 1.1 : 1), skin: skin, ink: p.palette.ink, stroke: p.ink, catchlight: true)
        PetDraw.mirrored(ctx) { c, side in
            // The far eye narrows and slides less as the head turns.
            let near = CGFloat(pose.headTurn) * side
            let x = fig.eyeX + fx * (near > 0 ? 0.85 : 1.1) * side
            var s = style
            s.width *= 1 - max(0, -near) * 0.18
            PetDraw.eye(c, at: CGPoint(x: x, y: fig.eyeY + fy), style: s,
                        lid: side > 0 ? pose.lidR : pose.lidL, slant: pose.lidSlant, smile: pose.smileEyes, squeeze: pose.squeeze,
                        gazeX: pose.gazeX * Double(side), gazeY: pose.gazeY, wide: pose.eyeWide, blink: pose.blink)
            PetDraw.brow(c, over: CGPoint(x: x + 0.5, y: fig.eyeY + fy - fig.eyeH * 1.02), width: badge ? 9 : 8, show: pose.browShow, slant: pose.browSlant, raise: pose.browRaise, color: p.palette.ink.alpha(0.85), thickness: badge ? 3 : 2.2)
        }
    }

    /// A small rounded beak that parts to show it is talking, humming or yawning.
    static func beak(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, at c: CGPoint) {
        let pal = p.palette, pose = p.pose
        let badge = p.detail == .badge
        let w: CGFloat = badge ? 14 : 12, h: CGFloat = badge ? 8 : 7
        let open = CGFloat(pose.mouthOpen) * 7
        // Lower mandible shows only when open.
        if open > 0.5 {
            var inside = Path()
            inside.addEllipse(in: CGRect(x: c.x - w * 0.34, y: c.y - 1, width: w * 0.68, height: open + 3))
            ctx.fill(inside, PetRGB(0.55, 0.22, 0.24))
            var lower = Path()
            lower.move(to: CGPoint(x: c.x - w * 0.36, y: c.y + open * 0.7))
            lower.addQuadCurve(to: CGPoint(x: c.x + w * 0.36, y: c.y + open * 0.7), control: CGPoint(x: c.x, y: c.y + open + 4))
            lower.closeSubpath()
            PetDraw.solid(ctx, lower, pal.accent, rim: p.rim * 0.6, depth: 0)
        }
        var upper = Path()
        let smileLift = CGFloat(pose.smile) * 1.2
        upper.move(to: CGPoint(x: c.x - w / 2, y: c.y - h * 0.35 - smileLift))
        upper.addQuadCurve(to: CGPoint(x: c.x + w / 2, y: c.y - h * 0.35 - smileLift), control: CGPoint(x: c.x, y: c.y - h * 0.95))
        upper.addQuadCurve(to: CGPoint(x: c.x, y: c.y + h * 0.62), control: CGPoint(x: c.x + w * 0.42, y: c.y + h * 0.2))
        upper.addQuadCurve(to: CGPoint(x: c.x - w / 2, y: c.y - h * 0.35 - smileLift), control: CGPoint(x: c.x - w * 0.42, y: c.y + h * 0.2))
        upper.closeSubpath()
        PetDraw.solid(ctx, upper, pal.accent, rim: p.rim * 0.7, depth: 2)
        if !badge {
            ctx.fill(PetDraw.ellipse(CGPoint(x: c.x - w * 0.16, y: c.y - h * 0.32), 1.8, 1.0), PetRGB(1, 1, 1, 0.45))
        }
    }
}
