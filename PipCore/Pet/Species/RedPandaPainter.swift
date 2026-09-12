import SwiftUI

public enum RedPandaPainter: PetPainter {
    public static func paint(_ ctx: inout GraphicsContext, _ p: PetPaintContext) {
        CatPainter.paint(&ctx, p)
    }
}
