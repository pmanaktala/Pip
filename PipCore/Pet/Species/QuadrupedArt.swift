import SwiftUI

/// The body shared by Mochi and Biscuit, built like Pebble's: a soft bean of a body sitting
/// on its haunches, two round front feet on the floor, and short mitten arms at the sides that
/// wave, hug and hold things the way a chibi character's do. The heads are `CatArt` and `DogArt`.
enum QuadrupedArt {
    static func body(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pal = p.palette, pose = p.pose
        let floor = PetFigure.floor
        let dog = p.species == .dog
        let breathe = CGFloat(pose.breath) * 1.5

        tail(ctx, p)

        // Haunches: a rounded thigh at each side, so it reads as sitting; cross-legged, the
        // knees spread wide and low.
        let cross = CGFloat(pose.crossLegs)
        PetDraw.mirrored(ctx, axis: 100) { c, side in
            let thigh = PetDraw.ellipse(CGPoint(x: 100 + 30 + cross * 8 + CGFloat(pose.turn) * 2 * side, y: floor - 16 + cross * 5), 17 + cross * 3, 15 - cross * 4)
            PetDraw.solid(c, thigh, pal.coat, rim: p.rim, depth: 4)
        }

        // The bean: narrow under the head, full at the belly.
        let w: CGFloat = (dog ? 40 : 38) + breathe, top: CGFloat = 96 - breathe * 0.5, bottom = floor - 5
        var bean = Path()
        bean.move(to: CGPoint(x: 100, y: top))
        bean.addCurve(to: CGPoint(x: 100 + w, y: 138), control1: CGPoint(x: 100 + w * 0.62, y: top), control2: CGPoint(x: 100 + w, y: 110))
        bean.addCurve(to: CGPoint(x: 100, y: bottom), control1: CGPoint(x: 100 + w, y: 160), control2: CGPoint(x: 100 + w * 0.6, y: bottom))
        bean.addCurve(to: CGPoint(x: 100 - w, y: 138), control1: CGPoint(x: 100 - w * 0.6, y: bottom), control2: CGPoint(x: 100 - w, y: 160))
        bean.addCurve(to: CGPoint(x: 100, y: top), control1: CGPoint(x: 100 - w, y: 110), control2: CGPoint(x: 100 - w * 0.62, y: top))
        bean.closeSubpath()
        PetDraw.solid(ctx, bean, pal.coat, rim: p.rim, depth: 6)

        // Chest and belly.
        var inside = ctx
        inside.clip(to: bean)
        let bx = 100 + CGFloat(pose.turn) * 5
        if dog {
            PetDraw.solid(inside, PetDraw.fluffy(CGPoint(x: bx, y: 132), 22 + breathe, 25, bumps: 12, depth: 1.4), pal.cream, rim: 0, depth: 3)
        } else {
            PetDraw.solid(inside, PetDraw.ellipse(CGPoint(x: bx, y: 136), 22 + breathe * 0.8, 26), pal.cream, rim: 0, depth: 3)
        }

        // Front feet on the floor, toes forward; cross-legged, they tuck in and overlap.
        PetDraw.mirrored(ctx, axis: 100) { c, side in
            let step = CGFloat(side > 0 ? pose.stepR : pose.stepL)
            let center = CGPoint(x: 100 + 15 - cross * 10 + CGFloat(pose.turn) * 3 * side, y: floor - 5 - step - cross * 2)
            var f = c
            f.translateBy(x: center.x, y: center.y)
            f.rotate(by: .degrees(Double(-cross * 25)))
            f.translateBy(x: -center.x, y: -center.y)
            let foot = PetDraw.ellipse(center, 11, 7)
            PetDraw.solid(f, foot, dog ? pal.coat : pal.cream, rim: p.rim, depth: 2.5)
            if p.detail == .full {
                for dx in [-3.2, 3.2] as [CGFloat] {
                    var toe = Path()
                    toe.move(to: CGPoint(x: center.x + dx, y: center.y + 2))
                    toe.addLine(to: CGPoint(x: center.x + dx, y: center.y + 5.5))
                    f.stroke(toe, pal.coat.shade, width: 1.2)
                }
            }
        }
    }

    /// A short mitten arm: one rounded shape from the side of the body to a soft paw, the same
    /// construction as Pebble's flippers, following the same designed arc of paw positions.
    static func foreleg(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, angle: Double) {
        let pal = p.palette
        let root = CGPoint(x: 100 + fig.shoulder.x, y: fig.shoulder.y)
        let off = fig.paw(p.species, angle: angle)
        let tip = CGPoint(x: 100 + off.x, y: off.y)
        let bend: CGFloat = angle < -12 ? -3 : -4
        let arm = PetDraw.limb(from: root, to: tip, bend: bend, rootWidth: 16, tipWidth: 13)
            .union(PetDraw.ellipse(tip, 7.6, 7.2))
        PetDraw.solid(ctx, arm, pal.coat, rim: p.rim, depth: 3)
        if p.species == .cat {
            // A cream mitten on the cat.
            var mitten = ctx
            mitten.clip(to: arm)
            mitten.fill(PetDraw.ellipse(tip, 8.4, 8), pal.cream)
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
