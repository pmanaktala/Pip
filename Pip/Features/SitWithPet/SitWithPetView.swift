import SwiftUI

/// Sit with your pet. Nothing to complete. Stay two seconds or ten minutes.
/// The pet settles into a meditation with you; with the guide on, its breathing, the ring and
/// the words all follow one ten-second breath (four in, six out).
struct SitWithPetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var ambience = AmbientSound()
    @State private var startedAt = Date.now
    @State private var guidedBreathing = false
    @Environment(\.scenePhase) private var scenePhase

    /// One breath every ten seconds when guided; a slow, unhurried one otherwise.
    private var breathRate: Double { guidedBreathing ? 0.1 : 0.14 }

    private var state: PetMoodState {
        var s = PetStateResolver.resolve(mood: .calm, intensity: .moderate, identity: appState.identity)
        // Sitting together is a meditation, not a logged "calm": floating, eyes closed, deep breaths.
        s.motion.bit = .meditate
        s.motion.breathRate = breathRate
        s.motion.breathAmount = guidedBreathing ? 0.07 : 0.045
        s.motion.blinkInterval = .infinity
        s.motion.gazeInterval = .infinity
        s.motion.sigh = 0
        s.motion.hopHeight = 0
        s.accessory = nil
        return s
    }

    var body: some View {
        ZStack {
            PetRoom(mood: .calm, horizon: 0.64)
                .ignoresSafeArea()

            if guidedBreathing {
                // The ring breathes on the same clock and curve as the pet's chest.
                TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { clock in
                    let expansion = PetAnimator.breath(phase: clock.date.timeIntervalSinceReferenceDate * breathRate)
                    Circle()
                        .stroke(MoodColor.bold(.calm).opacity(0.35), lineWidth: 2)
                        .frame(width: 300, height: 300)
                        .scaleEffect(reduceMotion ? 1 : 0.82 + expansion * 0.32)
                        .offset(y: -30)
                        .accessibilityHidden(true)
                }
            }

            PetSceneWithClock(identity: appState.identity, state: state, petScale: 0.70, petVerticalPosition: 0.53, showsFloor: false, showsBackground: false)
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel("\(appState.identity.name) is sitting with you.")

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
                                let phase = (clock.date.timeIntervalSinceReferenceDate * breathRate).truncatingRemainder(dividingBy: 1)
                                Text(phase < 0.42 ? "Breathe in." : "Let it go.")
                                    .contentTransition(.opacity)
                            }
                        } else {
                            Text("Nothing to do. Just be.")
                        }
                    }
                    .font(PipFont.title)
                    .multilineTextAlignment(.center)
                    .animation(.smooth(duration: 0.4), value: guidedBreathing)

                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                Haptics.soft()
                                        guidedBreathing.toggle()
                            } label: {
                                Label(guidedBreathing ? "Stop breathing guide" : "Breathe together", systemImage: guidedBreathing ? "stop.fill" : "wind")
                                    .font(PipFont.headline)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)

                            Text(timerInterval: startedAt...startedAt.addingTimeInterval(24 * 3600), countsDown: false, showsHours: false)
                                .monospacedDigit()
                                .font(PipFont.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .glassEffect(.regular, in: .capsule)
                                .accessibilityLabel("Time together")
                        }
                    }
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
