import SwiftUI

/// The app icon: Pebble, head and shoulders, content and looking at you. Drawn by the same
/// renderer as the pet; rendered to PNG by `AppIconRenderTests`.
public struct AppIconView: View {
    /// When false, only the pet is drawn on a transparent background (Icon Composer layer).
    public var includesBackground: Bool

    public init(includesBackground: Bool = true) {
        self.includesBackground = includesBackground
    }

    public static var pose: PetPose {
        var p = PetPose()
        p.smile = 0.5
        p.smileEyes = 0.3
        p.blush = 0.55
        p.headTilt = 4
        p.armL = 18
        p.armR = 18
        return p
    }

    public var body: some View {
        ZStack {
            if includesBackground {
                LinearGradient(colors: [Color(red: 0.56, green: 0.84, blue: 0.78), Color(red: 0.20, green: 0.58, blue: 0.54)], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [.white.opacity(0.28), .white.opacity(0)], center: UnitPoint(x: 0.5, y: 0.38), startRadius: 0, endRadius: 560)
            }
            // Head-and-shoulders crop: the body runs off the bottom edge on purpose.
            PetPoseView(species: .penguin, pose: Self.pose, framing: .icon, showsShadow: false)
                .frame(width: 1024, height: 1024)
                .offset(y: 70)
                .shadow(color: .black.opacity(includesBackground ? 0.18 : 0), radius: 30, y: 22)
        }
        .frame(width: 1024, height: 1024)
        .clipped()
    }
}

#Preview {
    AppIconView()
        .clipShape(RoundedRectangle(cornerRadius: 230, style: .continuous))
        .scaleEffect(0.3)
}
