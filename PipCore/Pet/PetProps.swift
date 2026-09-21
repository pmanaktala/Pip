import SwiftUI

/// Props — one per pet. They carry most of the character's charm, and the neck props
/// double as a clean seam between head and body. Draw them through the head context
/// after the face so they tilt with the head.
public enum PetProps {

    public static let coral = Color(red: 0.95, green: 0.40, blue: 0.36)
    public static let coralShade = Color(red: 0.78, green: 0.27, blue: 0.25)
    public static let teal = Color(red: 0.26, green: 0.66, blue: 0.70)
    public static let tealShade = Color(red: 0.17, green: 0.50, blue: 0.55)
    public static let leafGreen = Color(red: 0.46, green: 0.74, blue: 0.38)
    public static let leafShade = Color(red: 0.30, green: 0.56, blue: 0.26)
    public static let gold = Color(red: 0.98, green: 0.78, blue: 0.28)
    public static let goldShade = Color(red: 0.82, green: 0.58, blue: 0.14)
    public static let yuzu = Color(red: 0.99, green: 0.70, blue: 0.22)
    public static let yuzuShade = Color(red: 0.86, green: 0.52, blue: 0.12)

    /// A knitted scarf: a band around the neck with one end hanging over the chest.
    public static func scarf(_ ctx: inout GraphicsContext, _ p: PetPaintContext, color: Color = coral, shade: Color = coralShade) {
        let h = p.head
        let y = h.bottom - h.height * 0.1
        let w = h.width * 0.74, bandH = h.height * 0.16
        let band = CGRect(x: h.center.x - w / 2, y: y - bandH / 2, width: w, height: bandH)
        var bandPath = Path(roundedRect: band, cornerRadius: bandH / 2)
        // The band bows a little, like fabric.
        bandPath = bandPath.union(Path(ellipseIn: CGRect(x: band.minX + w * 0.1, y: band.minY + bandH * 0.3, width: w * 0.8, height: bandH * 1.1)))
        // Hanging end on the pet's right, with a fringe.
        let tailW = bandH * 1.15, tailH = h.height * 0.34
        let tail = CGRect(x: h.center.x + w * 0.16, y: band.midY, width: tailW, height: tailH)
        let tailPath = Path(roundedRect: tail, cornerRadius: tailW * 0.3).applying(CGAffineTransform(translationX: tail.midX, y: tail.minY).rotated(by: -0.12).translatedBy(x: -tail.midX, y: -tail.minY))
        PetDraw.form(&ctx, tailPath, in: tail, base: color, shade: shade, light: .white, strength: 0.9)
        if p.detail == .full {
            var fringe = Path()
            for i in 0..<3 {
                let fx = tail.minX + tailW * (0.2 + 0.3 * CGFloat(i))
                fringe.move(to: CGPoint(x: fx, y: tail.maxY - 2))
                fringe.addLine(to: CGPoint(x: fx + 1, y: tail.maxY + 5))
            }
            ctx.stroke(fringe.applying(CGAffineTransform(translationX: tail.midX, y: tail.minY).rotated(by: -0.12).translatedBy(x: -tail.midX, y: -tail.minY)), with: .color(shade), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            var knit = Path()
            for i in 0..<4 {
                let kx = band.minX + w * (0.2 + 0.2 * CGFloat(i))
                knit.move(to: CGPoint(x: kx, y: band.minY + 3))
                knit.addLine(to: CGPoint(x: kx - 3, y: band.maxY - 3))
            }
            PetDraw.form(&ctx, bandPath, in: band, base: color, shade: shade, light: .white, strength: 0.9)
            ctx.stroke(knit, with: .color(shade.opacity(0.6)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        } else {
            PetDraw.form(&ctx, bandPath, in: band, base: color, shade: shade, light: .white, strength: 0.9)
        }
    }

    /// A thin collar with a little bell: a band that curves *around* the neck, so it sits on the
    /// body rather than floating under the chin, with the bell hanging from its lowest point.
    public static func collar(_ ctx: inout GraphicsContext, _ p: PetPaintContext, color: Color = coral, shade: Color = coralShade) {
        let h = p.head
        let y = h.bottom - h.height * 0.1
        let w = h.width * 0.64, bandH = h.height * 0.07
        let dip = h.height * 0.09
        var band = Path()
        band.move(to: CGPoint(x: h.center.x - w / 2, y: y))
        band.addQuadCurve(to: CGPoint(x: h.center.x + w / 2, y: y), control: CGPoint(x: h.center.x, y: y + dip * 2))
        let bandStroke = band.strokedPath(StrokeStyle(lineWidth: bandH, lineCap: .round))
        let bandBox = CGRect(x: h.center.x - w / 2, y: y - bandH / 2, width: w, height: dip + bandH)
        PetDraw.form(&ctx, bandStroke, in: bandBox, base: color, shade: shade, light: .white, strength: 0.6)
        let r = bandH * 1.05
        let bell = CGRect(x: h.center.x - r, y: y + dip + bandH * 0.15, width: r * 2, height: r * 2)
        PetDraw.form(&ctx, Path(ellipseIn: bell), in: bell, base: gold, shade: goldShade, light: .white, strength: 0.8)
        if p.detail == .full {
            var slit = Path()
            slit.move(to: CGPoint(x: bell.midX, y: bell.midY + r * 0.2))
            slit.addLine(to: CGPoint(x: bell.midX, y: bell.maxY - r * 0.25))
            ctx.stroke(slit, with: .color(goldShade), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: bell.midX - r * 0.45, y: bell.minY + r * 0.35, width: r * 0.35, height: r * 0.25)), with: .color(.white.opacity(0.7)))
        }
    }

    /// A bandana knotted at the back, hanging over the chest.
    public static func bandana(_ ctx: inout GraphicsContext, _ p: PetPaintContext, color: Color = teal, shade: Color = tealShade) {
        let h = p.head
        let y = h.bottom - h.height * 0.08
        let w = h.width * 0.7, bandH = h.height * 0.11
        let band = CGRect(x: h.center.x - w / 2, y: y - bandH / 2, width: w, height: bandH)
        var tri = Path()
        tri.move(to: CGPoint(x: band.minX + w * 0.18, y: band.midY))
        tri.addLine(to: CGPoint(x: band.maxX - w * 0.18, y: band.midY))
        tri.addQuadCurve(to: CGPoint(x: h.center.x + w * 0.06, y: band.maxY + h.height * 0.3), control: CGPoint(x: h.center.x + w * 0.3, y: band.maxY + h.height * 0.2))
        tri.addQuadCurve(to: CGPoint(x: band.minX + w * 0.18, y: band.midY), control: CGPoint(x: h.center.x - w * 0.24, y: band.maxY + h.height * 0.2))
        tri.closeSubpath()
        PetDraw.form(&ctx, tri, in: tri.boundingRect, base: color, shade: shade, light: .white, strength: 0.8)
        PetDraw.form(&ctx, Path(roundedRect: band, cornerRadius: bandH / 2), in: band, base: color, shade: shade, light: .white, strength: 0.6)
        if p.detail == .full {
            var dots = ctx
            dots.clip(to: tri)
            for (dx, dy) in [(-0.1, 0.05), (0.08, 0.08), (-0.02, 0.17), (0.14, 0.15), (-0.14, 0.14)] {
                let c = CGPoint(x: h.center.x + CGFloat(dx) * w, y: band.maxY + CGFloat(dy) * h.height)
                dots.fill(Path(ellipseIn: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)), with: .color(.white.opacity(0.8)))
            }
        }
    }

    /// A single leaf resting on the crown.
    public static func leaf(_ ctx: inout GraphicsContext, _ p: PetPaintContext, at anchor: CGPoint, size: CGFloat, angle: CGFloat = -0.5) {
        var leaf = Path()
        leaf.move(to: .zero)
        leaf.addQuadCurve(to: CGPoint(x: size, y: 0), control: CGPoint(x: size * 0.5, y: -size * 0.55))
        leaf.addQuadCurve(to: .zero, control: CGPoint(x: size * 0.5, y: size * 0.55))
        leaf.closeSubpath()
        let t = CGAffineTransform(translationX: anchor.x, y: anchor.y).rotated(by: angle)
        let path = leaf.applying(t)
        PetDraw.form(&ctx, path, in: path.boundingRect, base: leafGreen, shade: leafShade, light: .white, strength: 0.8)
        var vein = Path()
        vein.move(to: CGPoint(x: size * 0.1, y: 0))
        vein.addLine(to: CGPoint(x: size * 0.9, y: 0))
        ctx.stroke(vein.applying(t), with: .color(leafShade.opacity(0.7)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
    }

    /// A little yuzu balanced on the head — the capybara's signature.
    public static func yuzu(_ ctx: inout GraphicsContext, _ p: PetPaintContext, at center: CGPoint, radius r: CGFloat) {
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        PetDraw.form(&ctx, Path(ellipseIn: rect), in: rect, base: yuzu, shade: yuzuShade, light: .white, strength: 1)
        if p.detail == .full {
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.15, y: center.y - r * 0.95, width: r * 0.3, height: r * 0.24)), with: .color(yuzuShade))
        }
        leaf(&ctx, p, at: CGPoint(x: center.x + r * 0.05, y: center.y - r * 0.9), size: r * 1.1, angle: -0.9)
    }
}
