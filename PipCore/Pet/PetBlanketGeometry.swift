import CoreGraphics

/// Two fabric panels share a center fold and remain attached to the actual paw positions.
/// Folding lifts the hem toward those paws; the folded bundle is six units deep, matching
/// its shelf compartment. All coordinates are in the room, independently of body squash.
struct PetBlanketGeometry {
    struct Panel {
        var grip: CGPoint
        var shoulder: CGPoint
        var crown: CGPoint
        var outerHem: CGPoint
        var outerControl: CGPoint
        var innerHem: CGPoint
        var hemControl: CGPoint
        var chest: CGPoint
        var chestControl: CGPoint
    }

    static func panels(_ pose: PetPose, species: PetSpecies, style: PetArtStyle) -> [Panel] {
        let f = PetFigure.of(species, style: style)
        let transform = PetBodyGeometry.transform(pose, style: style)
        let left = PetBodyGeometry.hand(pose, species: species, style: style, side: -1)
        let right = PetBodyGeometry.hand(pose, species: species, style: style, side: 1)
        let center = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        let fold = CGFloat(pose.blanketFold)
        let width: CGFloat = species == .penguin ? 48 : 50
        let top = f.neck.y - 6 + CGFloat(pose.slump) * 4
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let p = CGPoint(x: x, y: y).applying(transform)
            return CGPoint(x: p.x, y: min(PetFigure.floor, p.y))
        }
        func mix(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * fold, y: a.y + (b.y - a.y) * fold)
        }
        return [CGFloat(-1), 1].map { side in
            let grip = side < 0 ? left : right
            return Panel(
                grip: grip,
                shoulder: mix(point(100 + side * width * 0.9, top + 18), grip),
                crown: mix(point(100 + side * 8, top - 6), grip),
                outerHem: mix(point(100 + side * (width + 3), 168), CGPoint(x: grip.x, y: grip.y + 6)),
                outerControl: mix(point(100 + side * (width + 10), top + 56), CGPoint(x: grip.x, y: grip.y + 3)),
                innerHem: mix(point(100 + side * 12, 169), CGPoint(x: center.x, y: center.y + 6)),
                hemControl: mix(point(100 + side * width * 0.55, 169), CGPoint(x: center.x, y: center.y + 6)),
                chest: mix(point(100 + side, top + 36), center),
                chestControl: mix(point(100 + side * 4, top + 60), CGPoint(x: center.x, y: center.y + 3)))
        }
    }
}
