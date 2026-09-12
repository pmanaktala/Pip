import SwiftUI

public enum PenguinPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        CatPainter.paint(&ctx, p)
    }
}
