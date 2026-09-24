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
        if dog {
            // A fluffy chest instead of a smooth bib.
            PetDraw.solid(bib, PetDraw.fluffy(CGPoint(x: bx, y: 128), 20 + breathe, 22, bumps: 11, depth: 1.5), pal.cream, rim: 0, depth: 3)
        } else {
            PetDraw.solid(bib, chest, pal.cream, rim: 0, depth: 3)
        }
    }

    static func foreleg(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, angle: Double) {
        let pal = p.palette
        let shoulder = CGPoint(x: 100 + fig.shoulder.x, y: fig.shoulder.y)
        let off = fig.paw(p.species, angle: angle)
        var tip = CGPoint(x: 100 + off.x, y: off.y)
        let resting = angle > -12 && angle < 25
        // A standing paw lifts with a step.
        if resting { tip.y -= CGFloat(p.pose.stepR) * 0.6 }
        // A resting leg is mostly hidden by the chest: only its lower half shows, so it reads as
        // a paw on the floor rather than a column. A raised or folded leg shows all of it.
        // Folded arms start at the outside of the shoulder so they wrap round the chest (a hug),
        // not out from under the chin.
        let folded = angle < -12
        let root = resting ? CGPoint(x: shoulder.x + (tip.x - shoulder.x) * 0.45, y: shoulder.y + (tip.y - shoulder.y) * 0.45)
            : folded ? CGPoint(x: shoulder.x + 8, y: shoulder.y + 5) : shoulder
        let reach = hypot(tip.x - shoulder.x, tip.y - shoulder.y)
        let bend = resting ? -1 : folded ? -6 : -max(0, 46 - reach) * 0.45 - 1.5
        let width: CGFloat = resting ? 14 : 15
        let pawSize = CGSize(width: resting ? 9.5 : 8.6, height: resting ? 7.2 : 7.6)
        let pawCenter = CGPoint(x: tip.x, y: tip.y + (resting ? 1 : 0))
        // Leg and paw are one shape with one outline: no seam at the wrist.
        let paw = PetDraw.ellipse(pawCenter, pawSize.width, pawSize.height)
        let shape = PetDraw.limb(from: root, to: tip, bend: bend, rootWidth: width, tipWidth: width - 2).union(paw)
        if resting {
            PetDraw.solid(ctx, shape, pal.coat, rim: p.rim * 0.7, depth: 3)
        } else {
            PetDraw.solid(ctx, shape, pal.coat, rim: p.rim, depth: 3)
        }
        // The paw itself: a sock of cream on the cat, the same white on the dog; toe lines when
        // it rests on the floor.
        if p.species == .cat {
            var sock = ctx
            sock.clip(to: shape)
            sock.fill(PetDraw.ellipse(CGPoint(x: pawCenter.x, y: pawCenter.y + 1.5), pawSize.width * 1.05, pawSize.height), pal.cream)
        }
        if p.detail == .full && resting {
            for dx in [-2.8, 2.8] as [CGFloat] {
                var toe = Path()
                toe.move(to: CGPoint(x: tip.x + dx, y: tip.y + 3.5))
                toe.addLine(to: CGPoint(x: tip.x + dx, y: tip.y + 6.5))
                ctx.stroke(toe, pal.coat.shade, width: 1.2)
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
            // A fluffy plume that stands up and wags.
            let base = CGPoint(x: 128, y: 156)
            let angle = (-55 - Double(up) * 22 + Double(swing) * 30) * .pi / 180
            let len: CGFloat = 26
            let tip = CGPoint(x: base.x + cos(angle) * len, y: base.y + sin(angle) * len)
            let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
            let plume = PetDraw.fluffy(mid, 9, 9, bumps: 7, depth: 1.4).union(PetDraw.fluffy(tip, 10, 10, bumps: 7, depth: 1.6, phase: 0.5))
            PetDraw.solid(ctx, plume, pal.coat, rim: p.rim, depth: 3)
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
            if let brows {
                PetDraw.brow(c, over: CGPoint(x: center.x + 1, y: center.y - fig.eyeH * 1.05), width: 9, show: pose.browShow, slant: pose.browSlant, raise: pose.browRaise, color: brows, thickness: badge ? 3.2 : 2.6)
            }
        }
    }
}
