import SwiftUI

/// Juniper — a barrel-bodied capybara. One loaf silhouette with a boxy head and tiny ears,
/// a paler blunt snout with a wide nose on top, small high-set eyes, and a yuzu on the head.
public enum CapybaraPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let h = p.head

        // Tiny ears on the top corners are part of the outline.
        let lift = CGFloat(p.rig.earLift)
        let earC = h.point(0.42, -0.4 + (1 - lift) * 0.06)
        let earR = h.width * 0.07
        let ear = Path(ellipseIn: CGRect(x: earC.x - earR, y: earC.y - earR, width: earR * 2, height: earR * 2))
        // The snout widens the lower head so the head reads as a box, not a ball.
        let sw = h.width * 0.96, sh = h.height * 0.64
        let snout = CGRect(x: h.center.x - sw / 2, y: h.center.y - h.height * 0.04, width: sw, height: sh)
        let snoutPath = Path(roundedRect: snout, cornerRadius: sh * 0.4)
        let silhouette = PetDraw.silhouette(p, extras: [PetDraw.symmetric(ear), snoutPath])
        PetDraw.plush(&ctx, silhouette, p)
        PetDraw.belly(&ctx, p, within: silhouette, widthFraction: 0.5, heightFraction: 0.46)
        PetDraw.arms(&ctx, p)
        PetDraw.paws(&ctx, p, color: p.palette.shade, spread: 0.22, width: 28, height: 14)

        var hc = PetDraw.headContext(ctx, p)
        // Ear insides.
        PetDraw.mirrored(&hc) { ctx, _ in
            let ir = earR * 0.5
            ctx.fill(Path(ellipseIn: CGRect(x: earC.x - ir, y: earC.y - ir + earR * 0.1, width: ir * 2, height: ir * 2)), with: .color(p.palette.earInner))
        }

        // Paler snout.
        let snoutFace = CGRect(x: h.center.x + p.faceShift * 0.8 - sw * 0.4, y: snout.minY + sh * 0.14, width: sw * 0.8, height: sh * 0.84)
        hc.fill(Path(roundedRect: snoutFace, cornerRadius: sh * 0.34), with: .color(p.palette.belly))

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.36
        layout.eyeY = -0.18
        layout.eyeRadius = p.anatomy.eyeRadius
        layout.mouthY = 0.42
        layout.mouthWidth = 0.11
        layout.blushX = 0.44
        layout.blushY = -0.04

        // Wide nose pad on top of the snout with two nostrils.
        let a = PetDraw.mouthAnchor(p, layout: layout)
        let ny = snoutFace.minY + sh * 0.18
        let nw = h.width * 0.3, nh = h.height * 0.09
        hc.fill(Path(roundedRect: CGRect(x: a.x - nw / 2, y: ny - nh / 2, width: nw, height: nh), cornerRadius: nh / 2), with: .color(p.palette.nose))
        if p.detail == .full {
            for side: CGFloat in [-1, 1] {
                hc.fill(Path(ellipseIn: CGRect(x: a.x + side * nw * 0.26 - 2, y: ny - 1.4, width: 4, height: 2.8)), with: .color(p.palette.ink.opacity(0.5)))
            }
        }

        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)
        PetDraw.mouth(&hc, p, style: .simple, layout: layout)
        PetProps.yuzu(&hc, p, at: h.point(0.14, -0.5), radius: h.width * 0.1)
        PetDraw.sweat(&hc, p)
    }
}
