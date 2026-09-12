import SwiftUI

/// Juniper — a barrel-bodied capybara. Wide, boxy head with a long blunt snout, small
/// high-set eyes, tiny ears, nostrils on top of the nose and stubby legs.
public enum CapybaraPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        PetDraw.body(&ctx, p, belly: true, pawColor: p.palette.shade, legColor: p.palette.base)
        PetDraw.neckShadow(&ctx, p, within: PetDraw.torsoPath(p.torso))

        var hc = PetDraw.headContext(ctx, p)
        let h = p.head

        // Tiny ears behind the head.
        let lift = CGFloat(p.rig.earLift)
        PetDraw.mirrored(&hc) { ctx, side in
            let twitch = side == 1 ? CGFloat(p.live.earTwitch) * 0.05 : 0
            PetDraw.roundEar(&ctx, p, center: h.point(0.38, -0.44 + (1 - lift) * 0.06 - twitch), radius: h.width * 0.08, innerRatio: 0.5)
        }

        let head = PetDraw.headPath(h)
        PetDraw.fur(&hc, p, head, in: h.rect)

        // Snout: a wide rounded block on the lower half of the head, slightly paler.
        let sw = h.width * 0.74, sh = h.height * 0.56
        let snout = CGRect(x: h.center.x + p.faceShift * 0.8 - sw / 2, y: h.center.y + h.height * 0.0, width: sw, height: sh)
        let snoutPath = Path(roundedRect: snout, cornerRadius: sh * 0.4)
        PetDraw.form(&hc, snoutPath, in: snout, base: p.palette.belly, shade: p.palette.shade, light: p.palette.light, strength: 0.9)

        var layout = PetDraw.FaceLayout()
        layout.eyeSpacing = 0.33
        layout.eyeY = -0.16
        layout.eyeRadius = p.anatomy.eyeRadius
        layout.mouthY = 0.42
        layout.mouthWidth = 0.15
        layout.blushX = 0.43
        layout.blushY = 0.02

        // Nose: a wide dark pad on the top of the snout with two nostrils.
        let a = PetDraw.mouthAnchor(p, layout: layout)
        let ny = snout.minY + sh * 0.2
        let nw = h.width * 0.28, nh = h.height * 0.1
        let noseRect = CGRect(x: a.x - nw / 2, y: ny - nh / 2, width: nw, height: nh)
        PetDraw.form(&hc, Path(roundedRect: noseRect, cornerRadius: nh / 2), in: noseRect, base: p.palette.nose, shade: p.palette.ink, light: p.palette.marking, strength: 0.6)
        if p.detail == .full {
            for side: CGFloat in [-1, 1] {
                hc.fill(Path(ellipseIn: CGRect(x: a.x + side * nw * 0.26 - 2, y: ny - 1.6, width: 4, height: 3.2)), with: .color(p.palette.ink.opacity(0.45)))
            }
        }

        PetDraw.blush(&hc, p, layout: layout)
        PetDraw.eyes(&hc, p, layout: layout)
        PetDraw.brows(&hc, p, layout: layout)
        PetDraw.mouth(&hc, p, style: .simple, layout: layout)
        PetDraw.sweat(&hc, p)
    }
}
