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
                PetMomentBanner(identity: snapshot.identity, state: .init(kind: .breather, mood: .calm, intensity: .slight, message: "\(snapshot.identity.name) is sitting with you.", endsAt: .now.addingTimeInterval(1500), startedAt: .now.addingTimeInterval(-252), pose: 4))
                    .frame(width: 358)
                    .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 24))
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
            .background(WidgetCanvasPreview(snapshot: appState.snapshot))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

/// Mirrors the widget extension's container background for the gallery.
private struct WidgetCanvasPreview: View {
    var snapshot: PetSnapshot
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let mood: Mood? = {
            guard let m = snapshot.mood, let at = snapshot.loggedAt, Date.now.timeIntervalSince(at) < PetSnapshot.freshness else { return nil }
            return m
        }()
        ZStack {
            Color(.systemBackground)
            LinearGradient(colors: [
                (mood.map(MoodColor.bold) ?? PipColor.sceneTop).opacity(mood == nil ? (scheme == .dark ? 0.5 : 1) : (scheme == .dark ? 0.3 : 0.22)),
                (mood.map(MoodColor.bold) ?? PipColor.sceneBottom).opacity(mood == nil ? (scheme == .dark ? 0.4 : 0.7) : 0.06),
            ], startPoint: .top, endPoint: .bottom)
        }
    }
}
#endif
