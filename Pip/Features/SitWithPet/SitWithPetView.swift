import SwiftUI

/// Sit with your pet. Nothing to complete. Stay two seconds or ten minutes.
/// The light drifts slowly through the calm colours; a quiet timer counts the time together.
struct SitWithPetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var ambience = AmbientSound()
    @State private var startedAt = Date.now
    @State private var guidedBreathing = false
    @State private var breathStartedAt = Date.now
    @Environment(\.scenePhase) private var scenePhase

    private var state: PetMoodState {
        var s = PetStateResolver.resolve(mood: .calm, intensity: .moderate, identity: appState.identity)
        // Sitting together is quieter than a logged "calm": slower breath, no accessory.
        s.motion.breathRate *= 0.8
        s.motion.gazeInterval = 7
        s.accessory = nil
        return s
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ambientLight

            if guidedBreathing {
                TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { clock in
                    let phase = clock.date.timeIntervalSince(breathStartedAt).truncatingRemainder(dividingBy: 10)
                    let expansion = phase < 4 ? phase / 4 : 1 - (phase - 4) / 6
                    Circle()
                        .stroke(MoodColor.bold(.calm).opacity(0.25), lineWidth: 2)
                        .frame(width: 280, height: 280)
                        .scaleEffect(reduceMotion ? 1 : 0.85 + expansion * 0.3)
                        .accessibilityHidden(true)
                }
            }

            PetSceneWithClock(identity: appState.identity, state: state, petScale: 0.8, petVerticalPosition: 0.5, showsFloor: true)
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
                VStack(spacing: 6) {
                    if guidedBreathing {
                        TimelineView(.periodic(from: breathStartedAt, by: 1)) { clock in
                            let phase = clock.date.timeIntervalSince(breathStartedAt).truncatingRemainder(dividingBy: 10)
                            Text(phase < 4 ? "Breathe in." : "Let it go.")
                                .font(PipFont.title)
                        }
                    } else {
                        Text("Nothing to do. Just be.").font(PipFont.title)
                    }
                    Button(guidedBreathing ? "Stop guided breathing" : "Breathe together") {
                        Haptics.soft()
                        breathStartedAt = .now
                        guidedBreathing.toggle()
                    }
                    .font(PipFont.callout)
                    .buttonStyle(.glass)
                    .padding(.vertical, 12)
                    Text(timerInterval: startedAt...startedAt.addingTimeInterval(24 * 3600), countsDown: false, showsHours: false)
                        .monospacedDigit()
                        .font(PipFont.callout)
                        .foregroundStyle(.secondary)
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

    /// A slow drift between the calm hues, like light moving across a room over a few minutes.
    private var ambientLight: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 60 : 1 / 20)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 0 : (t / 90).truncatingRemainder(dividingBy: 1) * 2 * Double.pi
            let hues: [Color] = [MoodColor.bold(.calm), MoodColor.bold(.sad), MoodColor.bold(.tired), MoodColor.bold(.calm)]
            let k = (sin(phase) + 1) / 2
            let color = k < 0.5 ? blend(hues[0], hues[1], k * 2) : blend(hues[1], hues[2], (k - 0.5) * 2)
            RadialGradient(colors: [color.opacity(scheme == .dark ? 0.35 : 0.22), color.opacity(0)],
                           center: UnitPoint(x: 0.5 + 0.08 * sin(phase * 0.7), y: 0.42),
                           startRadius: 0, endRadius: 420)
                .ignoresSafeArea()
        }
    }

    private func blend(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ca = UIColor(a), cb = UIColor(b)
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        ca.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        cb.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let u = CGFloat(t)
        return Color(red: r1 + (r2 - r1) * u, green: g1 + (g2 - g1) * u, blue: b1 + (b2 - b1) * u)
    }
}
