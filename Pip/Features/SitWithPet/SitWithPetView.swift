import SwiftUI

/// Sit with your pet. Nothing to complete, nothing counting. Stay two seconds or ten minutes.
/// The pet closes its eyes and breathes; with the guide on, its chest, the ring and the words
/// follow one ten-second breath (four in, six out).
struct SitWithPetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ambience = AmbientSound()
    @State private var guidedBreathing = false
    @Environment(\.scenePhase) private var scenePhase

    private let floor: CGFloat = 0.62
    private let petScale: CGFloat = 0.72

    var body: some View {
        ZStack {
            PetRoom(mood: .calm, horizon: floor)
                .ignoresSafeArea()

            GeometryReader { geo in
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 60, paused: reduceMotion)) { clock in
                let breath = PetBreath.guide(at: clock.date)
                ZStack {
                    if guidedBreathing {
                        Circle()
                            .stroke(MoodColor.bold(.calm).opacity(0.35), lineWidth: 2)
                            .frame(width: 300, height: 300)
                            .scaleEffect(reduceMotion ? 1 : 0.8 + breath * 0.34)
                            .position(x: geo.size.width / 2, y: geo.size.height * floor - geo.size.width * petScale * 0.5)
                            .accessibilityHidden(true)
                    }
                    PetStage(scene: PetScene(species: appState.identity.species, stance: .meditating, breathGuide: guidedBreathing ? breath : nil),
                             live: !reduceMotion, petScale: petScale, floor: floor, showsRoom: false)
                }
            }
            }
            .ignoresSafeArea()
            .accessibilityElement()
            .accessibilityLabel(PetStance.meditating.describe(appState.identity.name))

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, PipSpacing.m)
                Spacer()
                VStack(spacing: PipSpacing.m) {
                    Group {
                        if guidedBreathing {
                            TimelineView(.periodic(from: .now, by: 0.25)) { clock in
                                Text(PetBreath.isInhaling(at: clock.date) ? "Breathe in." : "Let it go.")
                                    .contentTransition(.opacity)
                                    .animation(.smooth(duration: 0.6), value: PetBreath.isInhaling(at: clock.date))
                            }
                        } else {
                            Text("Nothing to do. Just be.")
                        }
                    }
                    .font(PipFont.title)
                    .multilineTextAlignment(.center)

                    Button {
                        Haptics.soft()
                        withAnimation(.smooth(duration: 0.5)) { guidedBreathing.toggle() }
                    } label: {
                        Label(guidedBreathing ? "Just sit" : "Breathe together", systemImage: guidedBreathing ? "leaf" : "wind")
                            .font(PipFont.headline)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                }
                .padding(.bottom, PipSpacing.xl)
            }
        }
        .onAppear { if appState.preferences.soundEnabled { ambience.start() } }
        .onDisappear { ambience.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && appState.preferences.soundEnabled { ambience.start() }
            else { ambience.stop() }
        }
    }
}
