import SwiftUI

/// Rusty — a chubby red panda. Rust fur with dark legs and belly, a cream mask with
/// rust tear-marks, round cream-rimmed ears, and a big ringed tail rising beside the body.
public enum RedPandaPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let t = p.torso

        // Big ringed tail behind the body.
        do {
            let lift = CGFloat(p.rig.tailLift)
            let wag = CGFloat(p.live.tailWag)
            let start = CGPoint(x: t.centerX + t.hipWidth * 0.28, y: t.bottom - 14)
            let length: CGFloat = 70 * (1 - 0.25 * CGFloat(p.rig.lying))
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
            PetDraw.fur(&ctx, p, stroked, in: stroked.boundingRect, strength: 0.9)
            var rings = ctx
            rings.clip(to: stroked)
            for i in 0..<3 {
                let u = 0.3 + CGFloat(i) * 0.24
                let pt = PetDraw.pointOnCubic(start, c1, c2, end, u)
                let next = PetDraw.pointOnCubic(start, c1, c2, end, u + 0.02)
                let angle = atan2(next.y - pt.y, next.x - pt.x)
                var ring = Path(ellipseIn: CGRect(x: -4, y: -tw * 0.7, width: 8, height: tw * 1.4))
                ring = ring.applying(CGAffineTransform(translationX: pt.x, y: pt.y).rotated(by: angle))
                rings.fill(ring, with: .color(p.palette.marking.opacity(0.75)))
            }
            rings.fill(Path(ellipseIn: CGRect(x: end.x - tw * 0.55, y: end.y - tw * 0.55, width: tw * 1.1, height: tw * 1.1)), with: .color(p.palette.shade))
        }

        PetDraw.body(&ctx, p, belly: false, pawColor: p.palette.belly, legColor: p.palette.belly)
        PetDraw.neckShadow(&ctx, p, within: PetDraw.torsoPath(p.torso))

        var hc = PetDraw.headContext(ctx, p)
        let h = p.head

        // Round ears with cream rims, behind the head.
        let earLift = CGFloat(p.rig.earLift)
        PetDraw.mirrored(&hc) { ctx, side in
            let twitch = side == 1 ? CGFloat(p.live.earTwitch) * 0.04 : 0
            let c = h.point(0.4, -0.36 + (1 - earLift) * 0.1 - twitch)
            PetDraw.roundEar(&ctx, p, center: c, radius: h.width * 0.145, innerRatio: 0.55, rim: p.palette.marking)
        }

        let head = PetDraw.headPath(h)
        PetDraw.fur(&hc, p, head, in: h.rect)

        // Mask: one cream shape — muzzle plus the lower cheeks — with rust tear-marks running
        // from the inner eye corners, and a cream spot above each eye.
        var mask = hc
        mask.clip(to: head)
        let fx = h.center.x + p.faceShift
        let cheeks = Path(ellipseIn: CGRect(x: fx - h.width * 0.44, y: h.center.y + h.height * 0.0, width: h.width * 0.88, height: h.height * 0.42))
        let muzzle = Path(ellipseIn: CGRect(x: fx - h.width * 0.22, y: h.center.y + h.height * 0.04, width: h.width * 0.44, height: h.height * 0.4))
        let maskShape = cheeks.union(muzzle)
        PetDraw.form(&mask, maskShape, in: maskShape.boundingRect, base: p.palette.marking, shade: p.palette.shade, light: .white, strength: 0.35)
        PetDraw.mirrored(&mask) { ctx, _ in
            let brow = CGRect(x: h.center.x + h.width * 0.12, y: h.center.y - h.height * 0.28, width: h.width * 0.17, height: h.height * 0.11)
            ctx.fill(Path(ellipseIn: brow), with: .color(p.palette.marking.opacity(0.9)))
            var tear = Path()
            let sx = h.center.x + h.width * 0.12
            tear.move(to: CGPoint(x: sx, y: h.center.y + h.height * 0.06))
            tear.addQuadCurve(to: CGPoint(x: sx + h.width * 0.08, y: h.center.y + h.height * 0.3), control: CGPoint(x: sx + h.width * 0.01, y: h.center.y + h.height * 0.2))
            ctx.stroke(tear, with: .color(p.palette.shade.opacity(0.8)), style: StrokeStyle(lineWidth: h.width * 0.05, lineCap: .round))
        }

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.21
        layout.eyeY = -0.02
        layout.eyeRadius = p.anatomy.eyeRadius
        layout.mouthY = 0.25
        layout.mouthWidth = 0.12
        layout.blushX = 0.37
        layout.blushY = 0.14
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout, lidColor: p.palette.base)
        PetDraw.brows(&hc, p, layout: layout)

        let a = PetDraw.mouthAnchor(p, layout: layout)
        let ns = h.width * 0.042
        hc.fill(Path(roundedRect: CGRect(x: a.x - ns, y: a.y - ns * 2.1, width: ns * 2, height: ns * 1.4), cornerRadius: ns * 0.65), with: .color(p.palette.nose))

        PetDraw.mouth(&hc, p, style: .cat, layout: layout)
        PetDraw.sweat(&hc, p)
    }
}
