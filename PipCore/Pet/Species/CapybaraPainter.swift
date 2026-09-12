import SwiftUI

/// Juniper — a barrel-bodied capybara with a long, boxy snout and tiny ears.
public enum CapybaraPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        PetDraw.body(&ctx, p, chestPatch: true, pawColor: p.palette.bodyBottom)

        var hc = PetDraw.headContext(ctx, p)
        let h = p.head

        // Tiny ears behind the head.
        let lift = CGFloat(p.rig.earLift) + CGFloat(p.live.earTwitch)
        for side: CGFloat in [-1, 1] {
            PetDraw.roundEar(&hc, p, center: h.point(side * 0.36, -0.42 + (1 - lift) * 0.06), radius: h.width * 0.075, innerRatio: 0.5)
        }

        let head = PetDraw.headPath(h)
        PetDraw.fillFur(&hc, p, path: head, rect: h.rect)

        // Boxy snout: a wide rounded block hanging off the front of the head.
        let sw = h.width * 0.72, sh = h.height * 0.58
        let snout = CGRect(x: h.center.x - sw / 2, y: h.center.y + h.height * 0.02, width: sw, height: sh)
        let snoutPath = Path(roundedRect: snout, cornerRadius: sh * 0.38)
        hc.fill(snoutPath, with: .linearGradient(Gradient(colors: [p.palette.bodyBottom, p.palette.marking]), startPoint: CGPoint(x: snout.midX, y: snout.minY), endPoint: CGPoint(x: snout.midX, y: snout.maxY)))
        var lighter = hc
        lighter.clip(to: snoutPath)
        lighter.fill(Path(ellipseIn: CGRect(x: snout.minX + sw * 0.1, y: snout.minY + sh * 0.3, width: sw * 0.8, height: sh * 0.75)), with: .color(p.palette.belly.opacity(0.28)))

        // Wide nose with nostrils on the top edge of the snout.
        let nx = h.center.x, ny = snout.minY + sh * 0.2
        let nw = h.width * 0.26, nh = h.height * 0.09
        hc.fill(Path(roundedRect: CGRect(x: nx - nw / 2, y: ny - nh / 2, width: nw, height: nh), cornerRadius: nh / 2), with: .color(p.palette.nose))
        for side: CGFloat in [-1, 1] {
            hc.fill(Path(ellipseIn: CGRect(x: nx + side * nw * 0.24 - 1.8, y: ny - 1.5, width: 3.6, height: 2.8)), with: .color(.black.opacity(0.3)))
        }

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.34
        layout.eyeY = -0.14
        layout.eyeRadius = 0.06
        layout.mouthY = 0.46
        layout.mouthWidth = 0.14
        layout.blushX = 0.44
        layout.blushY = 0.05
        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)
        PetDraw.mouth(&hc, p, style: .simple, layout: layout)
        PetDraw.sweat(&hc, p)
    }
}
