import SwiftUI

/// The sitting body shared by Mochi and Biscuit: haunches, a chest bib, forelegs that are also
/// arms, back paws peeking out, and a tail. The heads are drawn by `CatArt` and `DogArt`.
enum QuadrupedArt {
    static func body(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pal = p.palette, pose = p.pose
        let floor = PetFigure.floor
        let dog = p.species == .dog
        let breathe = CGFloat(pose.breath) * 1.5

        tail(ctx, p)

        // Back paws, just visible in front of the haunches.
        PetDraw.mirrored(ctx, axis: 100) { c, side in
            let foot = PetDraw.ellipse(CGPoint(x: 100 + 36 + CGFloat(pose.turn) * 3 * side, y: floor - 4), 12, 6)
            PetDraw.solid(c, foot, dog ? pal.coat : pal.coat, rim: p.rim, depth: 2.5)
        }

        // Torso: narrow at the shoulders, broad over the haunches.
        let shoulder: CGFloat = (dog ? 31 : 28) + breathe, hip: CGFloat = dog ? 47 : 44
        let top: CGFloat = 100 - breathe * 0.5
        var torso = Path()
        torso.move(to: CGPoint(x: 100, y: top))
        torso.addCurve(to: CGPoint(x: 100 + hip, y: 146), control1: CGPoint(x: 100 + shoulder, y: top), control2: CGPoint(x: 100 + hip * 0.9, y: 118))
        torso.addCurve(to: CGPoint(x: 100, y: floor - 3), control1: CGPoint(x: 100 + hip * 1.05, y: 166), control2: CGPoint(x: 100 + hip * 0.6, y: floor - 3))
        torso.addCurve(to: CGPoint(x: 100 - hip, y: 146), control1: CGPoint(x: 100 - hip * 0.6, y: floor - 3), control2: CGPoint(x: 100 - hip * 1.05, y: 166))
        torso.addCurve(to: CGPoint(x: 100, y: top), control1: CGPoint(x: 100 - hip * 0.9, y: 118), control2: CGPoint(x: 100 - shoulder, y: top))
        torso.closeSubpath()
        PetDraw.solid(ctx, torso, pal.coat, rim: p.rim, depth: 7)

        // Haunch lines: a soft crease so the pet reads as sitting.
        if p.detail == .full {
            PetDraw.mirrored(ctx, axis: 100) { c, _ in
                var crease = Path()
                crease.move(to: CGPoint(x: 100 + 25, y: 166))
                crease.addQuadCurve(to: CGPoint(x: 100 + 30, y: 136), control: CGPoint(x: 100 + 19, y: 150))
                c.stroke(crease, pal.coat.shade.mix(pal.coat.rim, 0.3), width: 1.6)
            }
        }

        // Chest bib.
        var bib = ctx
        bib.clip(to: torso)
        let bx = 100 + CGFloat(pose.turn) * 5
        var chest = Path()
        chest.move(to: CGPoint(x: bx, y: 104))
        chest.addQuadCurve(to: CGPoint(x: bx + 21 + breathe, y: 134), control: CGPoint(x: bx + 22, y: 108))
        chest.addQuadCurve(to: CGPoint(x: bx, y: 162), control: CGPoint(x: bx + 18, y: 158))
        chest.addQuadCurve(to: CGPoint(x: bx - 21 - breathe, y: 134), control: CGPoint(x: bx - 18, y: 158))
        chest.addQuadCurve(to: CGPoint(x: bx, y: 104), control: CGPoint(x: bx - 22, y: 108))
        PetDraw.solid(bib, chest, pal.cream, rim: 0, depth: 3)
    }

    static func foreleg(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, angle: Double) {
        let pal = p.palette
        let root = CGPoint(x: 100 + fig.shoulder.x, y: fig.shoulder.y)
        let off = fig.paw(p.species, angle: angle)
        var tip = CGPoint(x: 100 + off.x, y: off.y)
        // A standing paw lifts with a step.
        if angle > -10 && angle < 20 { tip.y -= CGFloat(p.pose.stepR) * 0.6 }
        let reach = hypot(tip.x - root.x, tip.y - root.y)
        let folded = angle < -20
        // The elbow bows outward more the more the leg is folded.
        let bend = -max(0, 46 - reach) * 0.45 - 1.5
        let leg = PetDraw.limb(from: root, to: tip, bend: bend, rootWidth: 15, tipWidth: folded ? 11 : 13)
        PetDraw.solid(ctx, leg, pal.coat, rim: p.rim, depth: 3)
        let paw = PetDraw.ellipse(CGPoint(x: tip.x, y: tip.y + (angle > -20 && angle < 30 ? 1 : 0)), folded ? 7 : 8.5, folded ? 6 : 7)
        PetDraw.solid(ctx, paw, pal.cream, rim: p.rim, depth: 2)
        if p.detail == .full && angle > -20 && angle < 30 {
            // Two toe lines on a paw that rests on the floor.
            for dx in [-2.6, 2.6] as [CGFloat] {
                var toe = Path()
                toe.move(to: CGPoint(x: tip.x + dx, y: tip.y + 3.5))
                toe.addLine(to: CGPoint(x: tip.x + dx, y: tip.y + 6))
                ctx.stroke(toe, pal.cream.shade, width: 1.2)
            }
        }
    }

    static func tail(_ ctx: GraphicsContext, _ p: PetPaint) {
        let pal = p.palette, pose = p.pose
        let swing = CGFloat(pose.tail), up = CGFloat(pose.tailUp)
        var path = Path()
        if p.species == .cat {
            // A long tail that curls up beside the body; the tip carries the swing.
            let base = CGPoint(x: 134, y: 160)
            let mid = CGPoint(x: 160 + swing * 6, y: 150 - up * 8)
            let tip = CGPoint(x: 158 + swing * 16, y: 118 - up * 16 + abs(swing) * 4)
            path.move(to: base)
            path.addCurve(to: tip, control1: CGPoint(x: 156, y: 166), control2: CGPoint(x: mid.x + 10, y: mid.y))
            ctx.stroke(path, pal.coat.rim, width: 12 + p.rim * 2)
            ctx.stroke(path, pal.coat, width: 12)
            // Striped tip.
            var tipPath = Path()
            tipPath.move(to: CGPoint(x: tip.x + (mid.x + 10 - tip.x) * 0.22, y: tip.y + (mid.y - tip.y) * 0.22))
            tipPath.addLine(to: tip)
            ctx.stroke(tipPath, pal.marking, width: 12)
        } else {
            // A short, thick tail that stands up and wags.
            let base = CGPoint(x: 128, y: 158)
            let angle = (-50 - Double(up) * 22 + Double(swing) * 30) * .pi / 180
            let len: CGFloat = 30
            let tip = CGPoint(x: base.x + cos(angle) * len, y: base.y + sin(angle) * len)
            path = PetDraw.limb(from: base, to: tip, bend: -4 - swing * 3, rootWidth: 14, tipWidth: 9)
            PetDraw.solid(ctx, path, pal.coat, rim: p.rim, depth: 2.5)
            ctx.fill(PetDraw.ellipse(tip, 4.5, 4.5), pal.cream)
        }
    }

    /// Shared parts of both heads: blush, eyes, brows.
    static func face(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, fx: CGFloat, fy: CGFloat, skin: PetRGB, brows: PetRGB?) {
        let pose = p.pose
        let badge = p.detail == .badge
        if pose.blush > 0.01 {
            PetDraw.mirrored(ctx) { c, side in
                c.fill(PetDraw.ellipse(CGPoint(x: fig.blushX + fx * side * 0.9, y: fig.blushY + fy), 6, 3.4), p.palette.blush.alpha(p.palette.blush.a * pose.blush))
            }
        }
        let style = PetDraw.EyeStyle(width: fig.eyeW * (badge ? 1.18 : 1), height: fig.eyeH * (badge ? 1.1 : 1), skin: skin, ink: p.palette.ink, stroke: p.ink, catchlight: true)
        PetDraw.mirrored(ctx) { c, side in
            let near = CGFloat(pose.headTurn) * side
            var s = style
            s.width *= 1 - max(0, -near) * 0.18
            let center = CGPoint(x: fig.eyeX + fx * (near > 0 ? 0.85 : 1.1) * side, y: fig.eyeY + fy)
            PetDraw.eye(c, at: center, style: s,
                        lid: side > 0 ? pose.lidR : pose.lidL, slant: pose.lidSlant, smile: pose.smileEyes, squeeze: pose.squeeze,
                        gazeX: pose.gazeX * Double(side), gazeY: pose.gazeY, wide: pose.eyeWide, blink: pose.blink)
            if let brows, !badge {
                PetDraw.brow(c, over: CGPoint(x: center.x + 1, y: center.y - fig.eyeH * 1.05), width: 9, show: pose.browShow, slant: pose.browSlant, raise: pose.browRaise, color: brows, thickness: 2.6)
            }
        }
    }
}
