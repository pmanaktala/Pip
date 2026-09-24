import CoreMotion
import SwiftUI

/// Time together, away from the Pet tab: **Play** (drag it a treat, throw the ball, tilt or
/// shake the phone) or **Meditate** (it sits cross-legged and breathes with you). The Pet tab
/// stays simple; everything hands-on lives here.
struct PlayView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case play = "Play", meditate = "Meditate"
        var id: String { rawValue }
    }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State var mode: Mode = .play

    // Play
    @State private var scene = PetScene(species: .penguin, stance: .mood(.happy, .slight))
    /// A toy picked up from the tray and being dragged (translation from its slot).
    @State private var dragging: Toy?
    @State private var drag: CGSize = .zero
    /// A toy in flight or on the floor, in stage coordinates.
    @State private var flying: (toy: Toy, at: CGPoint)?
    /// Toys not in the tray right now (eaten, or out being fetched).
    @State private var away: Set<Toy> = []
    @State private var petOffset: CGFloat = 0
    @State private var busy = false
    @State private var motion = MotionReader()
    @State private var stageSize: CGSize = .zero

    // Meditate
    @State private var ambience = AmbientSound()
    @State private var guided = false

    private let floor: CGFloat = 0.64
    private let petScale: CGFloat = 0.62

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PetRoom(mood: mode == .meditate ? .calm : nil, horizon: floor)
                    .ignoresSafeArea()
                    .onAppear { stageSize = geo.size }
                switch mode {
                case .play: play(in: geo.size).coordinateSpace(.named("stage"))
                case .meditate: meditate(in: geo.size)
                }
                chrome
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear(perform: setUp)
        .onDisappear {
            motion.stop()
            ambience.stop()
        }
        .onChange(of: mode) { _, new in
            Haptics.selection()
            if new == .meditate, appState.preferences.soundEnabled { ambience.start() } else { ambience.stop() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { ambience.stop() } }
    }

    // MARK: Chrome

    /// Two round glass buttons, top right: switch between playing and meditating, and close.
    private var chrome: some View {
        VStack {
            HStack(spacing: 10) {
                Spacer()
                Button {
                    withAnimation(.smooth(duration: 0.45)) { mode = mode == .play ? .meditate : .play }
                } label: {
                    Image(systemName: mode == .play ? "figure.mind.and.body" : "tennisball.fill")
                        .font(.headline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .accessibilityLabel(mode == .play ? "Meditate together" : "Play")
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline.weight(.semibold)).frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, PipSpacing.m)
            Spacer()
        }
    }

    // MARK: Play

    private func setUp() {
        var s = appState.pet.scene
        s.events = []
        s.pettingSince = nil
        s.hidesStanceProp = true
        // Playtime wakes a sleeping pet (grumpy for a second, then happy).
        if s.stance.isAsleep { s.stance = .mood(.neutral, .slight); s.previous = nil; s.dressing.head = nil }
        scene = s
        motion.onTilt = { tilt in scene.tilt = reduceMotion ? 0 : tilt }
        motion.onShake = {
            Haptics.light()
            add(.dizzy)
        }
        motion.start()
        #if DEBUG
        if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "meditate" { mode = .meditate }
        if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "fetch" {
            Task { try? await Task.sleep(for: .seconds(1.5)); throwBall(from: CGPoint(x: stageSize.width / 2, y: stageSize.height - 80), velocity: .zero, in: stageSize) }
        }
        #endif
    }

    private func add(_ kind: PetEvent.Kind) {
        let now = Date.now
        scene.events.removeAll { now.timeIntervalSince($0.at) > 6 }
        scene.events.append(PetEvent(kind, at: now))
    }

    enum Toy: Hashable { case treat, ball }

    @ViewBuilder
    private func play(in size: CGSize) -> some View {
        let head = PetStage.headRect(in: size, species: scene.species, petScale: petScale, floor: floor).offsetBy(dx: petOffset, dy: 0)
        ZStack(alignment: .topLeading) {
            PetStage(scene: scene, petScale: petScale, floor: floor, showsRoom: false, showsSeason: true, petOffset: petOffset)
                .allowsHitTesting(false)

            // A toy in the air or on the floor.
            if let flying {
                toyView(flying.toy)
                    .frame(width: 38, height: 38)
                    .position(flying.at)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 10) {
                Spacer()
                Text("Toss a treat or the ball to \(appState.identity.name) · tilt or shake your phone")
                    .font(PipFont.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PipSpacing.l)
                tray(size: size, head: head)
            }
            .frame(width: size.width)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func toyView(_ toy: Toy) -> some View {
        switch toy {
        case .treat: TreatToken()
        case .ball: BallToken(color: PetPalette.palette(for: scene.species).prop.color)
        }
    }

    /// The tray: a treat and the ball. Drag one out and let go to toss it; a tap tosses it too.
    private func tray(size: CGSize, head: CGRect) -> some View {
        HStack(spacing: 28) {
            ForEach([Toy.treat, .ball], id: \.self) { toy in
                toyView(toy)
                    .frame(width: 40, height: 40)
                    .padding(6)
                    .contentShape(Rectangle())
                    .opacity(away.contains(toy) ? 0 : 1)
                    .offset(dragging == toy ? drag : .zero)
                    .onTapGesture {
                        // A tap tosses it from its slot in the tray.
                        let slot = CGPoint(x: size.width / 2 + (toy == .treat ? -34 : 34), y: size.height - 70)
                        toss(toy, from: slot, velocity: .zero, in: size, head: head)
                    }
                    .gesture(DragGesture(minimumDistance: 6, coordinateSpace: .named("stage"))
                        .onChanged { value in
                            guard !away.contains(toy), !busy else { return }
                            dragging = toy
                            drag = value.translation
                            scene.look = CGPoint(x: (value.location.x - head.midX) / (size.width * 0.4), y: (value.location.y - head.midY) / (size.height * 0.3))
                        }
                        .onEnded { value in
                            guard dragging == toy else { return }
                            dragging = nil
                            drag = .zero
                            scene.look = nil
                            toss(toy, from: value.location, velocity: value.predictedEndTranslation, in: size, head: head)
                        })
                    .accessibilityLabel(toy == .treat ? "Treat" : "Ball")
                    .accessibilityHint(toy == .treat ? "Tosses a treat to \(appState.identity.name)." : "Throws the ball for \(appState.identity.name).")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { toss(toy, from: CGPoint(x: size.width / 2, y: size.height - 80), velocity: .zero, in: size, head: head) }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }

    private func toss(_ toy: Toy, from start: CGPoint, velocity: CGSize, in size: CGSize, head: CGRect) {
        guard !busy else { return }
        switch toy {
        case .treat: tossTreat(from: start, in: size, head: head)
        case .ball: throwBall(from: start, velocity: velocity, in: size)
        }
    }

    /// The treat arcs to its mouth; it hops to catch it and munches.
    private func tossTreat(from start: CGPoint, in size: CGSize, head: CGRect) {
        busy = true
        Haptics.light()
        away.insert(.treat)
        let mouth = CGPoint(x: head.midX, y: head.midY + head.height * 0.2)
        flying = (.treat, start)
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.45)) { flying = (.treat, CGPoint(x: (start.x + mouth.x) / 2, y: min(start.y, mouth.y) - 70)) }
            scene.look = CGPoint(x: 0, y: -0.6)
            try? await Task.sleep(for: .seconds(0.4))
            add(.hop)
            withAnimation(.easeIn(duration: 0.3)) { flying = (.treat, mouth) }
            try? await Task.sleep(for: .seconds(0.3))
            flying = nil
            scene.look = nil
            Haptics.success()
            add(.munch)
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.smooth(duration: 0.4)) { _ = away.remove(.treat) }
            busy = false
        }
    }

    /// The ball flies the way you threw it and lands on the floor; the pet hops over, carries it
    /// back in its paws, drops it, and it rolls back into the tray.
    private func throwBall(from start: CGPoint, velocity: CGSize, in size: CGSize) {
        busy = true
        Haptics.light()
        away.insert(.ball)
        let center = size.width / 2
        let ground = size.height * floor - 16
        // Where it lands follows the throw; a tap or a straight toss goes to a random side.
        var x = abs(velocity.width) > 60 ? start.x + velocity.width * 0.9 : (Bool.random() ? center - size.width * 0.32 : center + size.width * 0.32)
        x = min(max(x, size.width * 0.1), size.width * 0.9)
        if abs(x - center) < size.width * 0.22 { x = x < center ? center - size.width * 0.3 : center + size.width * 0.3 }
        flying = (.ball, start)
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.35)) { flying = (.ball, CGPoint(x: (start.x + x) / 2, y: ground - 150)) }
            scene.look = CGPoint(x: (x - center) / (size.width * 0.4), y: -0.4)
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.interpolatingSpring(stiffness: 90, damping: 8)) { flying = (.ball, CGPoint(x: x, y: ground)) }
            scene.look = CGPoint(x: (x - center) / (size.width * 0.4), y: 0.5)
            try? await Task.sleep(for: .seconds(0.6))
            // Hop over to it.
            let target = x - center + (x < center ? 34 : -34)
            let hops = max(2, Int(abs(target) / 42))
            for i in 1...hops {
                add(.hop)
                withAnimation(.easeInOut(duration: 0.4)) { petOffset = target * CGFloat(i) / CGFloat(hops) }
                try? await Task.sleep(for: .seconds(0.42))
            }
            // Pick it up and bring it back.
            flying = nil
            scene.heldProp = .heldBall
            scene.look = nil
            try? await Task.sleep(for: .seconds(0.3))
            for i in stride(from: hops - 1, through: 0, by: -1) {
                add(.hop)
                withAnimation(.easeInOut(duration: 0.4)) { petOffset = target * CGFloat(i) / CGFloat(hops) }
                try? await Task.sleep(for: .seconds(0.42))
            }
            // Drop it; it rolls back to the tray.
            scene.heldProp = nil
            add(.proud)
            Haptics.success()
            flying = (.ball, CGPoint(x: center + 20, y: ground))
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeInOut(duration: 0.6)) { flying = (.ball, CGPoint(x: center + 34, y: size.height - 64)) }
            try? await Task.sleep(for: .seconds(0.6))
            flying = nil
            away.remove(.ball)
            busy = false
        }
    }

    // MARK: Meditate

    @ViewBuilder
    private func meditate(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 60, paused: reduceMotion)) { clock in
            let breath = PetBreath.guide(at: clock.date)
            ZStack {
                if guided {
                    Circle()
                        .stroke(MoodColor.bold(.calm).opacity(0.35), lineWidth: 2)
                        .frame(width: 300, height: 300)
                        .scaleEffect(reduceMotion ? 1 : 0.8 + breath * 0.34)
                        .position(x: size.width / 2, y: size.height * floor - size.width * petScale * 0.5)
                        .accessibilityHidden(true)
                }
                PetStage(scene: PetScene(species: appState.identity.species, stance: .meditating, breathGuide: guided ? breath : nil),
                         live: !reduceMotion, petScale: petScale, floor: floor, showsRoom: false, showsSeason: false)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(PetStance.meditating.describe(appState.identity.name))

        VStack(spacing: PipSpacing.m) {
            Spacer()
            Group {
                if guided {
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
                withAnimation(.smooth(duration: 0.5)) { guided.toggle() }
            } label: {
                Label(guided ? "Just sit" : "Breathe together", systemImage: guided ? "leaf" : "wind")
                    .font(PipFont.headline)
                    .padding(6)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
        .padding(.bottom, PipSpacing.xl)
    }
}

/// A treat biscuit: golden, with a few crumbs of colour.
private struct TreatToken: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 8)
            let biscuit = Path(roundedRect: r, cornerSize: CGSize(width: r.height * 0.45, height: r.height * 0.45))
            ctx.fill(biscuit, with: .color(Color(red: 0.93, green: 0.72, blue: 0.42)))
            ctx.stroke(biscuit, with: .color(Color(red: 0.62, green: 0.42, blue: 0.24)), lineWidth: 1.6)
            for (x, y) in [(0.3, 0.42), (0.55, 0.62), (0.72, 0.4), (0.44, 0.3)] {
                ctx.fill(Path(ellipseIn: CGRect(x: r.minX + r.width * x - 2, y: r.minY + r.height * y - 2, width: 4, height: 4)),
                         with: .color(Color(red: 0.62, green: 0.42, blue: 0.24)))
            }
        }
    }
}

/// The pet's ball, as a tappable thing on the floor.
private struct BallToken: View {
    var color: Color
    var body: some View {
        ZStack {
            Circle().fill(color)
            Circle().strokeBorder(.black.opacity(0.25), lineWidth: 1.5)
            Capsule().fill(.white.opacity(0.9)).frame(height: 4).rotationEffect(.degrees(-18))
        }
        .contentShape(Circle().inset(by: -12))
    }
}

/// The phone's tilt and shakes, from the accelerometer (no permission needed).
@MainActor
final class MotionReader {
    private let manager = CMMotionManager()
    private var lastShake = Date.distantPast
    var onTilt: ((Double) -> Void)?
    var onShake: (() -> Void)?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // Only a real tilt counts; a phone held slightly off level is still level.
            let x = motion.gravity.x
            self.onTilt?(abs(x) < 0.12 ? 0 : max(-1, min(1, (x - 0.12 * (x > 0 ? 1 : -1)) * 1.6)))
            let a = motion.userAcceleration
            if sqrt(a.x * a.x + a.y * a.y + a.z * a.z) > 1.8, Date.now.timeIntervalSince(self.lastShake) > 2.5 {
                self.lastShake = .now
                self.onShake?()
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
