import SwiftUI

/// Articulated illustrated cast. Shares the production pose channels, grip coordinates,
/// costume anchors, floor and effects, so every state keeps the selected artwork style.
enum IllustratedPetArt {
    /// Quiet matte depth: broad tonal shading, no shiny highlight stickers or fur texture.
    static func soft(_ ctx: GraphicsContext, _ path: Path, _ color: PetRGB, rim: CGFloat = 0.55) {
        let b = path.boundingRect
        if rim > 0 { ctx.stroke(path, color.rim.mix(color, 0.6), width: rim * 2) }
        ctx.fill(path, with: .linearGradient(Gradient(colors: [
            color.mix(PetRGB(1, 1, 1), 0.06).color,
            color.color,
            color.mix(color.shade, 0.48).color
        ]), startPoint: CGPoint(x: b.minX, y: b.minY), endPoint: CGPoint(x: b.maxX, y: b.maxY)))
    }

    static func body(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pal = p.palette, pose = p.pose
        let penguin = p.species == .penguin
        let dog = p.species == .dog
        let breath = CGFloat(pose.breath)
        let cross = CGFloat(pose.crossLegs)
        let rest = CGFloat(pose.recline)
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * rest }
        let pajamas = pal.prop.mix(pal.cream, 0.38)
        let fabric = pal.coat.mix(pajamas, Double(rest))

        if !penguin {
            var tuckedTail = ctx
            tuckedTail.translateBy(x: 14 * rest, y: 170 * rest * 0.45)
            tuckedTail.scaleBy(x: 1, y: 1 - rest * 0.45)
            tail(tuckedTail, p)
        }
        if rest > 0 {
            // A small pillow lies on the same floor as the body, supporting the cheek.
            let pillow = PetDraw.ellipse(CGPoint(x: 64, y: 166), 38 * rest, 4 * rest)
            soft(ctx, pillow, pal.cream.mix(pal.prop, 0.12), rim: p.rim * rest)
            var seam = Path()
            seam.move(to: CGPoint(x: 34, y: 167))
            seam.addQuadCurve(to: CGPoint(x: 94, y: 167), control: CGPoint(x: 64, y: 170))
            var stitching = ctx
            stitching.clip(to: pillow)
            stitching.opacity = Double(rest) * 0.35
            stitching.stroke(seam, pal.prop, width: 0.6)
        }
        if !penguin {
            PetDraw.mirrored(ctx, axis: 100) { c, side in
                let haunch = PetDraw.ellipse(CGPoint(x: 100 + 25 + cross * 6 + CGFloat(pose.turn) * side * 2,
                                                    y: 154 + cross * 3), dog ? 13 : 12, 13 - cross * 2)
                var seated = c
                seated.opacity = Double(1 - rest)
                soft(seated, haunch, pal.coat, rim: p.rim)
            }
        }
        // The same contour morphs from the upright torso into the horizontal pajama body.
        let top = mix(penguin ? 92 : 103, 121)
        let width = mix(penguin ? 36 : (dog ? 27 : 28), 43) + breath * 0.8
        let cx = mix(100, 120)
        let bellyY = mix(penguin ? 138 : 142, 145)
        let bottom = mix(166, 168)
        var torso = Path()
        torso.move(to: CGPoint(x: cx, y: top - breath * 0.35))
        torso.addCurve(to: CGPoint(x: cx + width, y: bellyY),
                       control1: CGPoint(x: cx + mix(22, 30), y: top - breath * 0.35),
                       control2: CGPoint(x: cx + width, y: mix(119, 129)))
        torso.addCurve(to: CGPoint(x: cx, y: bottom),
                       control1: CGPoint(x: cx + width, y: mix(161, 165)),
                       control2: CGPoint(x: cx + mix(18, 25), y: bottom))
        torso.addCurve(to: CGPoint(x: cx - width, y: bellyY),
                       control1: CGPoint(x: cx - mix(18, 25), y: bottom),
                       control2: CGPoint(x: cx - width, y: mix(161, 165)))
        torso.addCurve(to: CGPoint(x: cx, y: top - breath * 0.35),
                       control1: CGPoint(x: cx - width, y: mix(119, 129)),
                       control2: CGPoint(x: cx - mix(22, 30), y: top - breath * 0.35))
        torso.closeSubpath()
        soft(ctx, torso, fabric, rim: p.rim)
        var chest = ctx
        chest.clip(to: torso)
        let bx = cx + CGFloat(pose.turn) * 5 * (1 - rest)
        let bib: Path
        if dog {
            bib = DogArt.tuft(at: CGPoint(x: bx, y: 129), size: 20, side: 1)
                .union(PetDraw.ellipse(CGPoint(x: bx, y: 143), 17 + breath, 17))
        } else {
            bib = PetDraw.ellipse(CGPoint(x: bx, y: penguin ? 136 : 137), penguin ? 26 : 16, penguin ? 28 : 25)
        }
        var awakeChest = chest
        awakeChest.opacity = Double(1 - rest)
        soft(awakeChest, bib, pal.cream, rim: 0)
        chest.fill(PetDraw.ellipse(CGPoint(x: bx, y: top + 5), 25, 6), pal.coat.shade.alpha(0.14 * Double(1 - rest)))
        if rest > 0 {
            var cloth = chest
            cloth.opacity = Double(rest)
            // Quiet vertical stripes stay clipped to the fabric as the chest breathes.
            for x: CGFloat in stride(from: 86, through: 166, by: 10) {
                var stripe = Path()
                stripe.move(to: CGPoint(x: x, y: 119))
                stripe.addQuadCurve(to: CGPoint(x: x + 2, y: 170), control: CGPoint(x: x - 3 - breath, y: 145))
                cloth.stroke(stripe, pal.cream.alpha(0.38), width: 2.3)
            }
            var placket = Path()
            placket.move(to: CGPoint(x: 104, y: 126))
            placket.addQuadCurve(to: CGPoint(x: 147, y: 156), control: CGPoint(x: 134, y: 130))
            cloth.stroke(placket, pal.prop.shade.alpha(0.45), width: 0.9)
            for point in [CGPoint(x: 121, y: 134), CGPoint(x: 136, y: 144)] {
                cloth.fill(PetDraw.ellipse(point, 1.5, 1.5), pal.cream)
            }
        }
        // Feet move around the floor into two short pajama legs; neither end floats.
        for side: CGFloat in [-1, 1] {
            let step = CGFloat(side > 0 ? pose.stepR : pose.stepL) * (1 - rest)
            let standingX = 100 + side * ((penguin ? 17 : 13) - cross * 9) + CGFloat(pose.turn) * 2
            let x = mix(standingX, side > 0 ? 167 : 153)
            let y = mix(165 - step - cross * 3, side > 0 ? 156 : 163)
            var foot = ctx
            foot.translateBy(x: x, y: y)
            foot.rotate(by: .degrees(Double(-cross * 25 * side * (1 - rest) + rest * (side > 0 ? -22 : -7))))
            if rest > 0 {
                soft(foot, PetDraw.ellipse(CGPoint(x: -4, y: -1), 11, 6), pajamas, rim: p.rim)
                foot.fill(Path(roundedRect: CGRect(x: 0, y: -6, width: 4, height: 11), cornerSize: CGSize(width: 1.5, height: 1.5)), pal.cream)
            }
            soft(foot, PetDraw.ellipse(CGPoint(x: 5 * rest, y: 0), penguin ? 12 : 10, 5), penguin ? pal.accent : pal.cream, rim: p.rim)
            if p.detail == .full {
                for dx: CGFloat in [-3, 3] {
                    var toe = Path()
                    toe.move(to: CGPoint(x: dx + 5 * rest, y: 0))
                    toe.addQuadCurve(to: CGPoint(x: dx - 0.6 + 5 * rest, y: 3), control: CGPoint(x: dx - 0.7 + 5 * rest, y: 1.5))
                    foot.stroke(toe, (penguin ? pal.accent : pal.coat).shade.alpha(0.55), width: 0.8)
                }
            }
        }
    }

    static func arm(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, angle: Double, side: CGFloat) {
        let penguin = p.species == .penguin
        let rest = CGFloat(p.pose.recline)
        let pajamas = p.palette.prop.mix(p.palette.cream, 0.38)
        let standingRoot: CGFloat = 100 + (penguin ? 33 : 23)
        let sleepingRoot: CGFloat = side > 0 ? 132 : 89
        let root = CGPoint(x: standingRoot + (sleepingRoot - standingRoot) * rest,
                           y: fig.shoulder.y + (140 - fig.shoulder.y) * rest)
        let offset = fig.paw(p.species, angle: angle, pose: p.pose, side: side)
        let sleepingPaw: CGFloat = side > 0 ? 108 : 104
        let tip = CGPoint(x: 100 + offset.x + (sleepingPaw - 100 - offset.x) * rest,
                          y: offset.y + (154 - offset.y) * rest)
        let limb = PetDraw.limb(from: root, to: tip, bend: angle < 0 ? -3 : -2,
                                rootWidth: penguin ? 13 : 12, tipWidth: penguin ? 8 : 12)
        soft(ctx, limb, p.palette.coat.mix(pajamas, Double(rest)), rim: p.rim)
        if rest > 0 {
            var cuff = ctx
            cuff.opacity = Double(rest)
            cuff.fill(PetDraw.ellipse(tip, 7.2, 6.8), p.palette.cream)
        }
        if !penguin || rest > 0 {
            let paw = PetDraw.ellipse(tip, 6.8, 6.2)
            soft(ctx, paw, p.species == .cat ? p.palette.cream : p.palette.coat, rim: p.rim * 0.6)
            if p.detail == .full, angle < -15 {
                var seam = Path()
                seam.move(to: CGPoint(x: tip.x - 2, y: tip.y + 1))
                seam.addQuadCurve(to: CGPoint(x: tip.x - 2, y: tip.y + 3), control: CGPoint(x: tip.x - 2.5, y: tip.y + 2))
                ctx.stroke(seam, p.palette.coat.shade.alpha(0.55), width: 0.9)
            }
        }
    }

    static func tail(_ ctx: GraphicsContext, _ p: PetPaint) {
        let pose = p.pose, pal = p.palette
        let swing = CGFloat(pose.tail), up = CGFloat(pose.tailUp)
        if p.species == .cat {
            var curve = Path()
            curve.move(to: CGPoint(x: 124, y: 156))
            curve.addCurve(to: CGPoint(x: 149 + swing * 12, y: 120 - up * 13),
                           control1: CGPoint(x: 166, y: 169), control2: CGPoint(x: 169 + swing * 6, y: 125 - up * 5))
            ctx.stroke(curve, pal.coat.rim.mix(pal.coat, 0.65), width: 11)
            ctx.stroke(curve, pal.coat, width: 10)
            var tip = Path()
            tip.move(to: CGPoint(x: 153 + swing * 11, y: 122 - up * 12))
            tip.addLine(to: CGPoint(x: 149 + swing * 12, y: 120 - up * 13))
            ctx.stroke(tip, pal.marking, width: 10)
        } else {
            var wag = ctx
            wag.translateBy(x: 125, y: 155)
            wag.rotate(by: .degrees(pose.tail * 30 - pose.tailUp * 18))
            let plume = DogArt.tuft(at: CGPoint(x: 12, y: -14), size: 12, side: 1)
                .union(PetDraw.ellipse(CGPoint(x: 4, y: -6), 8, 10))
            soft(wag, plume, pal.coat, rim: p.rim)
        }
    }

    static func head(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure) {
        let pal = p.palette, pose = p.pose
        let rx = fig.headRX, ry = fig.headRY
        let fx = CGFloat(pose.headTurn) * 7, fy = CGFloat(pose.headNod) * 5
        let badge = p.detail == .badge
        if p.species == .cat { catEars(ctx, p, fig, fx: fx, fy: fy) }
        if p.species == .dog { dogEars(ctx, p, fig, fx: fx, fy: fy) }

        // Broad crown and soft cheeks, with a tucked chin. The torso remains lighter.
        var skull = Path()
        skull.move(to: CGPoint(x: -rx * 0.08, y: -ry))
        skull.addCurve(to: CGPoint(x: rx, y: 3), control1: CGPoint(x: rx * 0.63, y: -ry * 1.03), control2: CGPoint(x: rx, y: -ry * 0.47))
        skull.addCurve(to: CGPoint(x: 1, y: ry), control1: CGPoint(x: rx * 1.02, y: ry * 0.65), control2: CGPoint(x: rx * 0.52, y: ry))
        skull.addCurve(to: CGPoint(x: -rx, y: 4), control1: CGPoint(x: -rx * 0.56, y: ry * 1.02), control2: CGPoint(x: -rx * 1.01, y: ry * 0.68))
        skull.addCurve(to: CGPoint(x: -rx * 0.08, y: -ry), control1: CGPoint(x: -rx, y: -ry * 0.48), control2: CGPoint(x: -rx * 0.68, y: -ry))
        skull.closeSubpath()
        if p.species == .dog {
            skull = skull.union(DogArt.tuft(at: CGPoint(x: -rx * 0.86, y: ry * 0.36), size: 7, side: -1))
                .union(DogArt.tuft(at: CGPoint(x: rx * 0.86, y: ry * 0.38), size: 7, side: 1))
                .union(DogArt.tuft(at: CGPoint(x: -4, y: -ry), size: 7, side: -1))
        }
        soft(ctx, skull, pal.coat, rim: p.rim)
        var face = ctx
        face.clip(to: skull)
        if p.species == .penguin {
            var mask = Path()
            mask.move(to: CGPoint(x: fx, y: fy - 17))
            mask.addCurve(to: CGPoint(x: fx + 35, y: fy - 1), control1: CGPoint(x: fx + 13, y: fy - 40), control2: CGPoint(x: fx + 36, y: fy - 29))
            mask.addCurve(to: CGPoint(x: fx, y: fy + 35), control1: CGPoint(x: fx + 37, y: fy + 24), control2: CGPoint(x: fx + 15, y: fy + 35))
            mask.addCurve(to: CGPoint(x: fx - 35, y: fy - 1), control1: CGPoint(x: fx - 15, y: fy + 35), control2: CGPoint(x: fx - 37, y: fy + 24))
            mask.addCurve(to: CGPoint(x: fx, y: fy - 17), control1: CGPoint(x: fx - 36, y: fy - 29), control2: CGPoint(x: fx - 13, y: fy - 40))
            mask.closeSubpath()
            soft(face, mask, pal.cream, rim: 0)
        } else if p.species == .cat {
            // Tapered tabby markings, not strokes pasted onto a spherical head.
            for (dx, length): (CGFloat, CGFloat) in [(-13, 11), (0, 15), (13, 10)] {
                var stripe = Path()
                let x = dx + fx * 0.5
                stripe.move(to: CGPoint(x: x - 3.5, y: -ry - 1))
                stripe.addQuadCurve(to: CGPoint(x: x * 0.8, y: -ry + length), control: CGPoint(x: x + 4, y: -ry + length * 0.55))
                stripe.addQuadCurve(to: CGPoint(x: x + 3.5, y: -ry - 1), control: CGPoint(x: x + 3, y: -ry + length * 0.35))
                stripe.closeSubpath()
                face.fill(stripe, pal.marking)
            }
        } else if !badge {
            // One broad forehead curl, kept above the eye line so every expression reads.
            var curl = Path()
            curl.move(to: CGPoint(x: -24 + fx * 0.3, y: -29))
            curl.addCurve(to: CGPoint(x: 5 + fx * 0.3, y: -19), control1: CGPoint(x: -7, y: -37), control2: CGPoint(x: 14, y: -28))
            curl.addQuadCurve(to: CGPoint(x: -10 + fx * 0.3, y: -16), control: CGPoint(x: -2, y: -12))
            face.stroke(curl, pal.marking.alpha(0.55), width: 1.5)
        }
        if p.species != .penguin {
            let m = CGPoint(x: fx * 1.15, y: fig.mouthY + fy * 1.2)
            let muzzle = PetDraw.ellipse(CGPoint(x: m.x - 6.5, y: m.y - 3), 12, 9)
                .union(PetDraw.ellipse(CGPoint(x: m.x + 6.5, y: m.y - 3), 12, 9))
            soft(face, muzzle, pal.cream, rim: 0)
        }
        expressions(ctx, p, fig, fx: fx, fy: fy)
        if p.species == .penguin {
            PenguinArt.beak(ctx, p, fig, at: CGPoint(x: fx * 1.15, y: fig.mouthY + fy * 1.2))
        } else {
            muzzle(ctx, p, fig, fx: fx, fy: fy)
        }
    }

    static func expressions(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, fx: CGFloat, fy: CGFloat) {
        let pose = p.pose, pal = p.palette
        let badge = p.detail == .badge
        let skin = p.species == .penguin ? pal.cream : pal.coat
        PetDraw.mirrored(ctx) { c, side in
            if pose.blush > 0.01 {
                c.fill(PetDraw.ellipse(CGPoint(x: 26 + fx * side, y: 12 + fy), 5.5, 3), pal.blush.alpha(pose.blush * 0.35))
            }
            let near = CGFloat(pose.headTurn) * side
            let x = fig.eyeX + fx * (near > 0 ? 0.85 : 1.1) * side
            let center = CGPoint(x: x, y: fig.eyeY + fy - 1)
            let style = PetDraw.EyeStyle(width: fig.eyeW * (badge ? 1.06 : 1) * (1 - max(0, -near) * 0.18),
                                        height: fig.eyeH, skin: skin, ink: pal.ink,
                                        stroke: p.ink, catchlight: !p.monochrome)
            PetDraw.eye(c, at: center, style: style, lid: side > 0 ? pose.lidR : pose.lidL,
                        slant: pose.lidSlant, smile: pose.smileEyes > 0.82 ? pose.smileEyes : pose.smileEyes * 0.5, squeeze: pose.squeeze,
                        gazeX: pose.gazeX * Double(side), gazeY: pose.gazeY, wide: pose.eyeWide, blink: pose.blink)
            PetDraw.brow(c, over: CGPoint(x: x, y: center.y - fig.eyeH * 0.64 - 3), width: badge ? 9 : 8,
                         show: max(pose.browShow, 0.18), slant: pose.browSlant, raise: pose.browRaise,
                         color: (p.species == .dog ? pal.marking.rim : pal.ink).alpha(0.65), thickness: p.ink * 0.7)
        }
    }

    static func muzzle(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, fx: CGFloat, fy: CGFloat) {
        let pal = p.palette, pose = p.pose
        let cat = p.species == .cat
        let m = CGPoint(x: fx * 1.15, y: fig.mouthY + fy * 1.2)
        var nose = Path()
        nose.move(to: CGPoint(x: m.x - 4.3, y: m.y - 10))
        nose.addQuadCurve(to: CGPoint(x: m.x + 4.3, y: m.y - 10), control: CGPoint(x: m.x, y: m.y - 12))
        nose.addQuadCurve(to: CGPoint(x: m.x, y: m.y - 5), control: CGPoint(x: m.x + 4, y: m.y - 7))
        nose.addQuadCurve(to: CGPoint(x: m.x - 4.3, y: m.y - 10), control: CGPoint(x: m.x - 4, y: m.y - 7))
        nose.closeSubpath()
        soft(ctx, nose, cat ? pal.pink : pal.ink.mix(pal.marking, 0.32), rim: 0)
        var line = Path()
        line.move(to: CGPoint(x: m.x, y: m.y - 5))
        line.addLine(to: CGPoint(x: m.x, y: m.y - 2))
        ctx.stroke(line, pal.ink.alpha(0.7), width: p.ink * 0.55)
        PetDraw.mouth(ctx, at: CGPoint(x: m.x, y: m.y - 1), width: cat ? 12 : 15,
                      smile: pose.smile, open: pose.mouthOpen, round: pose.mouthRound,
                      ink: pal.ink, inside: PetRGB(0.35, 0.17, 0.18), tongue: pal.pink,
                      stroke: p.ink * 0.75, catLike: cat)
        if cat, p.detail == .full {
            PetDraw.mirrored(ctx) { c, side in
                for dy: CGFloat in [-4, 1] {
                    var whisker = Path()
                    whisker.move(to: CGPoint(x: 19 + fx * side, y: m.y + dy))
                    whisker.addQuadCurve(to: CGPoint(x: 34 + fx * side, y: m.y + dy - 2), control: CGPoint(x: 26 + fx * side, y: m.y + dy - 3))
                    c.stroke(whisker, pal.cream.mix(pal.ink, 0.18), width: 1.1)
                }
            }
        }
    }

    static func catEars(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, fx: CGFloat, fy: CGFloat) {
        PetDraw.mirrored(ctx) { c, side in
            let e = side > 0 ? p.pose.earR : p.pose.earL
            var ear = c
            ear.translateBy(x: 28 - fx * side * 0.3, y: -25 - fy * 0.4)
            ear.rotate(by: .degrees(12 - e * 12 + max(0, -e) * 26))
            var shape = Path()
            shape.move(to: CGPoint(x: -15, y: 8))
            shape.addQuadCurve(to: CGPoint(x: 2, y: -24 - e * 3), control: CGPoint(x: -10, y: -21))
            shape.addQuadCurve(to: CGPoint(x: 17, y: 8), control: CGPoint(x: 14, y: -18))
            shape.closeSubpath()
            soft(ear, shape, p.palette.coat, rim: p.rim)
            var inner = Path()
            inner.move(to: CGPoint(x: -8, y: 3))
            inner.addQuadCurve(to: CGPoint(x: 2, y: -17 - e * 2), control: CGPoint(x: -4, y: -15))
            inner.addQuadCurve(to: CGPoint(x: 10, y: 4), control: CGPoint(x: 8, y: -10))
            inner.closeSubpath()
            soft(ear, inner, p.palette.pink, rim: 0)
        }
    }

    static func dogEars(_ ctx: GraphicsContext, _ p: PetPaint, _ fig: PetFigure, fx: CGFloat, fy: CGFloat) {
        PetDraw.mirrored(ctx) { c, side in
            let e = side > 0 ? p.pose.earR : p.pose.earL
            var ear = c
            ear.translateBy(x: 32 - fx * side * 0.2, y: -22 - fy * 0.3)
            ear.rotate(by: .degrees(-9 - e * 20 + p.pose.headTilt * Double(side) * 0.25))
            var shape = Path()
            shape.move(to: CGPoint(x: -9, y: 0))
            shape.addCurve(to: CGPoint(x: 21, y: 25), control1: CGPoint(x: 6, y: -15), control2: CGPoint(x: 23, y: 2))
            shape.addCurve(to: CGPoint(x: 9, y: 51), control1: CGPoint(x: 28, y: 39), control2: CGPoint(x: 22, y: 54))
            shape.addQuadCurve(to: CGPoint(x: -5, y: 45), control: CGPoint(x: -2, y: 58))
            shape.addCurve(to: CGPoint(x: -9, y: 0), control1: CGPoint(x: -15, y: 34), control2: CGPoint(x: -11, y: 11))
            shape.closeSubpath()
            soft(ear, shape, p.palette.marking.mix(p.palette.coat, 0.35), rim: p.rim)
            if p.detail != .badge {
                var fold = Path()
                fold.move(to: CGPoint(x: 10, y: 12))
                fold.addQuadCurve(to: CGPoint(x: 9, y: 40), control: CGPoint(x: 20, y: 26))
                ear.stroke(fold, p.palette.marking.shade.alpha(0.25), width: 1.3)
            }
        }
    }
}
