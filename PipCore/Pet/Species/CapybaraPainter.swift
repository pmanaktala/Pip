import SwiftUI

/// Juniper — a wide, unbothered capybara.
public enum CapybaraPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        let b = p.body
        let body = PetDraw.blobPath(b)

        // Tiny round ears on the top corners.
        let lift = CGFloat(p.rig.earLift) + CGFloat(p.live.earTwitch)
        for side: CGFloat in [-1, 1] {
            let c = b.point(side * 0.33, -0.43 + (1 - lift) * 0.05)
            PetDraw.roundEar(&ctx, p, center: c, radius: b.width * 0.075, innerRatio: 0.5)
        }

        PetDraw.fillBody(&ctx, p, path: body)
        PetDraw.belly(&ctx, p, path: body, widthFraction: 0.6, heightFraction: 0.36, yOffset: 0.34, opacity: 0.55)

        // Long muzzle: a rounded block on the lower face.
        let mw = b.width * 0.46, mh = b.height * 0.34
        let muzzle = CGRect(x: b.center.x - mw / 2, y: b.center.y - b.height * 0.02, width: mw, height: mh)
        var mz = ctx
        mz.clip(to: body)
        mz.fill(Path(roundedRect: muzzle, cornerRadius: mh * 0.45), with: .color(p.palette.belly.opacity(0.75)))

        // Wide nose with two nostrils.
        let nx = b.center.x, ny = muzzle.minY + mh * 0.22
        let nw = b.width * 0.16, nh = b.height * 0.07
        ctx.fill(Path(roundedRect: CGRect(x: nx - nw / 2, y: ny - nh / 2, width: nw, height: nh), cornerRadius: nh / 2), with: .color(p.palette.nose))
        for side: CGFloat in [-1, 1] {
            ctx.fill(Path(ellipseIn: CGRect(x: nx + side * nw * 0.22 - 1.6, y: ny - 1.4, width: 3.2, height: 2.6)), with: .color(.black.opacity(0.3)))
        }

        // Stubby legs.
        for side: CGFloat in [-1, 1] {
            let paw = CGRect(x: b.center.x + side * b.width * 0.24 - b.width * 0.1, y: b.bottom - b.height * 0.11, width: b.width * 0.2, height: b.height * 0.11)
            ctx.fill(Path(ellipseIn: paw), with: .color(p.palette.bodyBottom))
        }

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.27
        layout.eyeY = -0.16
        layout.eyeRadius = 0.062
        layout.mouthY = 0.2
        layout.mouthWidth = 0.1
        layout.blushX = 0.4
        layout.blushY = -0.02
        PetDraw.blush(&ctx, p, layout: layout)
        PetDraw.eyes(&ctx, p, layout: layout, lidColor: p.palette.bodyTop)
        PetDraw.brows(&ctx, p, layout: layout)
        PetDraw.mouth(&ctx, p, style: .simple, layout: layout)
        PetDraw.sweat(&ctx, p)
    }
}
