#if DEBUG
import SwiftUI
import WidgetKit

/// Developer gallery: renders widget and Live Activity content at their real sizes.
struct WidgetGalleryView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let snapshot = appState.snapshot
        ScrollView {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    PetLockScreenView(snapshot: snapshot, family: .accessoryCircular)
                        .frame(width: 72, height: 72)
                    PetLockScreenView(snapshot: snapshot, family: .accessoryRectangular)
                        .frame(width: 172, height: 72)
                }
                .padding(12)
                .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
                .environment(\.colorScheme, .dark)
                PetMomentBanner(identity: snapshot.identity, state: .init(kind: .breather, mood: .stressed, intensity: .moderate, message: "\(snapshot.identity.name) is sitting with you.", endsAt: .now))
                    .frame(width: 358)
                    .background(PipColor.sceneBottom.opacity(0.9), in: RoundedRectangle(cornerRadius: 24))
                HStack(spacing: 16) {
                    widget(PetHomeWidgetView(snapshot: snapshot, family: .systemSmall), width: 158, height: 158)
                    widget(PetHomeWidgetView(snapshot: snapshot, family: .systemSmall, showsBackground: false), width: 158, height: 158)
                }
                widget(PetHomeWidgetView(snapshot: snapshot, family: .systemMedium), width: 338, height: 158)
                widget(PetHomeWidgetView(snapshot: snapshot, family: .systemLarge), width: 338, height: 354)
            }
            .padding()
        }
        .background(Color(white: 0.9))
        .navigationTitle("Widgets")
    }

    private func widget(_ content: some View, width: CGFloat, height: CGFloat) -> some View {
        content
            .frame(width: width, height: height)
            .background(LinearGradient(colors: [PipColor.sceneTop, PipColor.sceneBottom], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
#endif
