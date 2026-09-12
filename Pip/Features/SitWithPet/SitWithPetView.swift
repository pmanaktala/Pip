import SwiftUI

/// Sit with your pet. Nothing to complete. Stay two seconds or ten minutes.
struct SitWithPetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ambience = AmbientSound()

    private var state: PetMoodState {
        var s = PetStateResolver.resolve(mood: .calm, intensity: .moderate, identity: appState.identity)
        // Sitting together is quieter than a logged "calm": slower breath, no accessory.
        s.motion.breathRate *= 0.8
        s.motion.gazeInterval = 7
        s.accessory = nil
        return s
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PetSceneWithClock(identity: appState.identity, state: state, petScale: 0.7, petVerticalPosition: 0.5)
                .ignoresSafeArea()
                .overlay(alignment: .bottom) {
                    Text("Just sitting.")
                        .font(PipFont.callout)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, PipSpacing.xl)
                        .accessibilityLabel("\(appState.identity.name) is sitting with you.")
                }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .padding(6)
            }
            .buttonStyle(.glass)
            .padding(PipSpacing.m)
            .accessibilityLabel("Close")
        }
        .onAppear { if appState.preferences.soundEnabled { ambience.start() } }
        .onDisappear { ambience.stop() }
    }
}
