import SwiftUI

/// Rusty — a chubby red panda. One rust silhouette with round ears, a cream muzzle and
/// cheeks with rust tear-marks, dark paws, a ringed tail beside the body, and a leaf.
public enum RedPandaPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso
        let h = p.head

        // Big ringed tail behind the body.
        do {
            let lift = CGFloat(p.rig.tailLift)
            let wag = CGFloat(p.live.tailWag)
            let start = CGPoint(x: t.centerX + t.hipWidth * 0.28, y: t.bottom - 14)
            let length: CGFloat = 68 * (1 - 0.25 * CGFloat(p.rig.lying))
            let downEnd = CGPoint(x: start.x + length * 0.75, y: t.bottom - 16)
            let upEnd = CGPoint(x: start.x + length * 0.55 + wag * 8, y: t.bottom - length * 0.9)
            let end = PetDraw.lerp(downEnd, upEnd, lift)
            let c1 = CGPoint(x: start.x + length * 0.45, y: t.bottom - 4)
            let c2 = PetDraw.lerp(CGPoint(x: downEnd.x - length * 0.1, y: t.bottom + 4), CGPoint(x: upEnd.x + length * 0.35 + wag * 10, y: upEnd.y + length * 0.4), lift)
            var tail = Path()
            tail.move(to: start)
            tail.addCurve(to: end, control1: c1, control2: c2)
            let tw: CGFloat = 24
            let stroked = tail.strokedPath(StrokeStyle(lineWidth: tw, lineCap: .round))
            ctx.fill(stroked, with: .color(p.palette.base))
            var rings = ctx
            rings.clip(to: stroked)
            for i in 0..<3 {
                let u = 0.3 + CGFloat(i) * 0.24
                let pt = PetDraw.pointOnCubic(start, c1, c2, end, u)
                let next = PetDraw.pointOnCubic(start, c1, c2, end, u + 0.02)
                let angle = atan2(next.y - pt.y, next.x - pt.x)
                let ring = Path(ellipseIn: CGRect(x: -4, y: -tw * 0.7, width: 8, height: tw * 1.4)).applying(CGAffineTransform(translationX: pt.x, y: pt.y).rotated(by: angle))
                rings.fill(ring, with: .color(p.palette.marking))
            }
            rings.fill(Path(ellipseIn: CGRect(x: end.x - tw * 0.55, y: end.y - tw * 0.55, width: tw * 1.1, height: tw * 1.1)), with: .color(p.palette.shade))
        }

        // Round ears are part of the outline.
        let earLift = CGFloat(p.rig.earLift)
        let earC = h.point(0.4, -0.36 + (1 - earLift) * 0.1)
        let earR = h.width * 0.15
        let ear = Path(ellipseIn: CGRect(x: earC.x - earR, y: earC.y - earR, width: earR * 2, height: earR * 2))
        let silhouette = PetDraw.silhouette(p, extras: [PetDraw.symmetric(ear)])
        PetDraw.plush(&ctx, silhouette, p)
        PetDraw.arms(&ctx, p)
        PetDraw.paws(&ctx, p, color: p.palette.belly, spread: 0.2, width: 26, height: 14)

        var hc = PetDraw.headContext(ctx, p)
        // Ear insides.
        PetDraw.mirrored(&hc) { ctx, _ in
            let ir = earR * 0.55
            ctx.fill(Path(ellipseIn: CGRect(x: earC.x - ir, y: earC.y - ir + earR * 0.1, width: ir * 2, height: ir * 2)), with: .color(p.palette.earInner))
        }

        // Mask: cream muzzle and lower cheeks in one shape; rust tear-marks; cream brow spots.
        var mask = hc
        mask.clip(to: PetDraw.headPath(h))
        let fx = h.center.x + p.faceShift
        let cheeks = Path(ellipseIn: CGRect(x: fx - h.width * 0.42, y: h.center.y + h.height * 0.02, width: h.width * 0.84, height: h.height * 0.4))
        let muzzle = Path(ellipseIn: CGRect(x: fx - h.width * 0.2, y: h.center.y + h.height * 0.04, width: h.width * 0.4, height: h.height * 0.38))
        mask.fill(cheeks.union(muzzle), with: .color(p.palette.marking))
        PetDraw.mirrored(&mask) { ctx, _ in
            let brow = CGRect(x: h.center.x + h.width * 0.12, y: h.center.y - h.height * 0.26, width: h.width * 0.15, height: h.height * 0.1)
            ctx.fill(Path(ellipseIn: brow), with: .color(p.palette.marking))
            var tear = Path()
            let sx = h.center.x + h.width * 0.11
            tear.move(to: CGPoint(x: sx, y: h.center.y + h.height * 0.07))
            tear.addQuadCurve(to: CGPoint(x: sx + h.width * 0.08, y: h.center.y + h.height * 0.3), control: CGPoint(x: sx + h.width * 0.01, y: h.center.y + h.height * 0.2))
            ctx.stroke(tear, with: .color(p.palette.shade), style: StrokeStyle(lineWidth: h.width * 0.045, lineCap: .round))
        }

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.2
        layout.eyeY = -0.02
        layout.eyeRadius = p.anatomy.eyeRadius
        layout.mouthY = 0.24
        layout.mouthWidth = 0.09
        layout.blushX = 0.35
        layout.blushY = 0.13
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)

        let a = PetDraw.mouthAnchor(p, layout: layout)
        let ns = h.width * 0.036
        hc.fill(Path(roundedRect: CGRect(x: a.x - ns, y: a.y - ns * 2.2, width: ns * 2, height: ns * 1.4), cornerRadius: ns * 0.65), with: .color(p.palette.nose))

        PetDraw.mouth(&hc, p, style: .cat, layout: layout)
        PetProps.leaf(&hc, p, at: h.point(0.0, -0.5), size: h.width * 0.24, angle: -0.35)
        PetDraw.sweat(&hc, p)
    }
}
