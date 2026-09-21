import SwiftUI
import Testing
import UIKit
@testable import Pip

/// Renders candidate SF Symbols at tab-bar and accessory sizes for review. Set `PIP_FILM_OUTPUT`.
@MainActor
struct SymbolSheetTests {
    @Test func candidates() throws {
        let names = ["face.smiling", "face.smiling.fill", "face.smiling.inverse", "bubble.left.and.heart.bubble.right", "bubble.left.and.heart.bubble.right.fill", "heart.text.square.fill", "hand.wave.fill", "sparkles", "sun.max.fill", "heart.fill", "pawprint.fill", "figure.mind.and.body", "bubble.left.and.text.bubble.right.fill", "message.fill", "plus.bubble.fill"]
        let sheet = VStack(alignment: .leading, spacing: 10) {
            ForEach(names, id: \.self) { n in
                HStack(spacing: 18) {
                    Text(n).font(.system(size: 11, design: .monospaced)).frame(width: 300, alignment: .leading)
                    Image(systemName: n).font(.system(size: 22, weight: .regular)).frame(width: 40)
                    Image(systemName: n).font(.system(size: 22, weight: .semibold)).frame(width: 40)
                    ZStack { Circle().fill(.white).frame(width: 52, height: 52).shadow(radius: 2); Image(systemName: n).font(.system(size: 24, weight: .medium)).foregroundStyle(Color(red: 0.18, green: 0.66, blue: 0.60)) }
                    Image(systemName: n).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(red: 0.18, green: 0.66, blue: 0.60)).frame(width: 30)
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.95, green: 0.94, blue: 0.92))
        let r = ImageRenderer(content: sheet); r.scale = 2
        let image = try #require(r.uiImage)
        if let dir = ProcessInfo.processInfo.environment["PIP_FILM_OUTPUT"] {
            try #require(image.pngData()).write(to: URL(fileURLWithPath: dir).appendingPathComponent("symbols.png"))
        }
    }
}
