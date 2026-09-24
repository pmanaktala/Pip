import CoreMotion
import SwiftUI

/// Time together, away from the Pet tab: **Play** (toss it a treat, throw the ball, blow
/// bubbles for it to swat, tilt or shake the phone, and it dances if music is playing) or **Meditate** (it sits cross-legged and breathes with you). The Pet tab
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
    @State private var bubbles: [Bubble] = []
    @State private var bubbleLoop: Task<Void, Never>?

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
                // The stage runs to the very top, so bubbles and notes float off the screen,
                // passing under the glass buttons (which bend them) on the way.
                Group {
                    switch mode {
                    case .play: play(in: geo.size).coordinateSpace(.named("stage"))
                    case .meditate: meditate(in: geo.size)
                    }
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .overlay(alignment: .topTrailing) { chrome }
        .ignoresSafeArea(.keyboard)
        .onAppear(perform: setUp)
        .onDisappear {
            motion.stop()
            ambience.stop()
            bubbleLoop?.cancel()
            appState.updateFavourite()
        }
        .onChange(of: appState.pet.context) { _, _ in syncMusic() }
        .task {
            // Music can start or stop without a notification; look again now and then.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                appState.checkListening()
            }
        }
        .onChange(of: mode) { _, new in
            Haptics.selection()
            syncMusic()
            if new == .meditate, appState.preferences.soundEnabled { ambience.start() } else { ambience.stop() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { ambience.stop() } }
    }

    // MARK: Chrome

    /// Two floating glass buttons, the same size and weight as the Pet tab's toolbar buttons:
    /// switch between playing and meditating, and close. Regular Liquid Glass (Apple keeps the
    /// clear variant for photo and video backgrounds), living over the room rather than in a
    /// toolbar, so whatever drifts beneath them is bent by the glass instead of cut off by a bar edge.
    private var chrome: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.smooth(duration: 0.45)) { mode = mode == .play ? .meditate : .play }
                } label: {
                    Image(systemName: mode == .play ? "figure.mind.and.body" : "tennisball.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(mode == .play ? "Meditate together" : "Play")
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close")
            }
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(.tint)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
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
        syncMusic()
        motion.onTilt = { tilt in scene.tilt = reduceMotion ? 0 : tilt }
        motion.onShake = {
            Haptics.light()
            add(.dizzy)
        }
        motion.start()
        #if DEBUG
        if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "meditate" { mode = .meditate }
        if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "treat" {
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                let head = PetStage.headRect(in: stageSize, species: scene.species, petScale: petScale, floor: floor)
                tossTreat(from: CGPoint(x: stageSize.width / 2 - 80, y: stageSize.height - 70), in: stageSize, head: head)
            }
        }
        if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "bubbles" {
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                let head = PetStage.headRect(in: stageSize, species: scene.species, petScale: petScale, floor: floor)
                blowBubbles(from: CGPoint(x: stageSize.width / 2 + 80, y: stageSize.height - 70), in: stageSize, head: head)
            }
        }
        if ProcessInfo.processInfo.environment["PIP_DEBUG"] == "fetch" {
            Task { try? await Task.sleep(for: .seconds(1.5)); throwBall(from: CGPoint(x: stageSize.width / 2, y: stageSize.height - 80), velocity: .zero, in: stageSize) }
        }
        #endif
    }

    /// Headphones on while something plays; and with music playing it dances.
    private func syncMusic() {
        let live = appState.pet.scene.dressing
        scene.dressing.head = scene.stance.isAsleep ? scene.dressing.head : live.head
        scene.dancing = mode == .play && appState.pet.context.audioPlaying
    }

    private func add(_ kind: PetEvent.Kind) {
        let now = Date.now
        scene.events.removeAll { now.timeIntervalSince($0.at) > 6 }
        scene.events.append(PetEvent(kind, at: now))
    }

    typealias Toy = PetToy

    @ViewBuilder
    private func play(in size: CGSize) -> some View {
        let head = PetStage.headRect(in: size, species: scene.species, petScale: petScale, floor: floor).offsetBy(dx: petOffset, dy: 0)
        ZStack(alignment: .topLeading) {
            PetStage(scene: scene, petScale: petScale, floor: floor, showsRoom: false, showsSeason: true, petOffset: petOffset)
                .allowsHitTesting(false)

            // Dancing: notes float up off it and drift away behind the glass.
            if scene.dancing && !reduceMotion {
                TimelineView(.animation) { clock in
                    Canvas { ctx, _ in
                        RisingNotes.draw(ctx, from: CGPoint(x: head.midX, y: head.minY), height: size.height, t: clock.date.timeIntervalSince1970)
                    }
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .accessibilityHidden(true)
            }

            // Bubbles, and a tap pops the one under your finger.
            if !bubbles.isEmpty {
                TimelineView(.animation) { clock in
                    Canvas { ctx, _ in
                        for bubble in bubbles { bubble.draw(ctx, at: clock.date) }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .named("stage")) { location in popBubble(near: location) }
                .accessibilityHidden(true)
            }

            // A toy in the air or on the floor.
            if let flying {
                toyView(flying.toy)
                    .frame(width: 38, height: 38)
                    .position(flying.at)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 10) {
                Spacer()
                Text(scene.dancing ? "\(appState.identity.name) is dancing to your music"
                     : "Toss a treat, throw the ball or blow bubbles · tilt or shake your phone")
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
        case .treat: SnackToken(species: scene.species)
        case .ball: BallToken(color: PetPalette.palette(for: scene.species).prop.color)
        case .bubbles: WandToken()
        }
    }

    /// The tray: a treat, the ball and the bubble wand. Drag one out and let go to toss it; a tap
    /// tosses it too.
    /// The tray: one capsule of glass holding the treat, the ball and the bubble wand.
    private func tray(size: CGSize, head: CGRect) -> some View {
        HStack(spacing: 28) {
            ForEach(Toy.allCases, id: \.self) { toy in
                toyView(toy)
                    .frame(width: 40, height: 40)
                    .padding(6)
                    .contentShape(Rectangle())
                    .scaleEffect(away.contains(toy) ? 0.3 : 1)
                    .opacity(away.contains(toy) ? 0 : 1)
                    .animation(.spring(duration: 0.45, bounce: 0.35), value: away.contains(toy))
                    .offset(dragging == toy ? drag : .zero)
                    .onTapGesture {
                        // A tap tosses it from its slot in the tray.
                        let slot = CGPoint(x: size.width / 2 + slotOffset(toy), y: size.height - 70)
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
                    .accessibilityLabel(toyName(toy))
                    .accessibilityHint(toyHint(toy))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { toss(toy, from: CGPoint(x: size.width / 2, y: size.height - 80), velocity: .zero, in: size, head: head) }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    /// Where a toy sits in the tray, from the middle: three 52 pt slots 28 pt apart.
    private func slotOffset(_ toy: Toy) -> CGFloat {
        CGFloat((Toy.allCases.firstIndex(of: toy) ?? 1) - 1) * 80
    }

    private func toyName(_ toy: Toy) -> String {
        switch toy {
        case .treat: "Treat"
        case .ball: "Ball"
        case .bubbles: "Bubbles"
        }
    }

    private func toyHint(_ toy: Toy) -> String {
        let name = appState.identity.name
        return switch toy {
        case .treat: "Tosses a treat to \(name)."
        case .ball: "Throws the ball for \(name)."
        case .bubbles: "Blows bubbles for \(name) to swat."
        }
    }

    private func toss(_ toy: Toy, from start: CGPoint, velocity: CGSize, in size: CGSize, head: CGRect) {
        if toy == .bubbles {
            blowBubbles(from: start, in: size, head: head)
            return
        }
        guard !busy else { return }
        PetToy.played(toy)
        switch toy {
        case .treat: tossTreat(from: start, in: size, head: head)
        case .ball: throwBall(from: start, velocity: velocity, in: size)
        case .bubbles: break
        }
    }

    // MARK: Bubbles

    /// A puff of five bubbles from the wand. They wobble up toward the pet, which watches the
    /// nearest one and swats any that come within reach; a tap pops one too.
    private func blowBubbles(from start: CGPoint, in size: CGSize, head: CGRect) {
        let now = Date.now
        guard bubbles.filter({ $0.poppedAt == nil }).count < 12 else { return }
        PetToy.played(.bubbles)
        Haptics.soft()
        for i in 0..<5 {
            bubbles.append(Bubble(born: now.addingTimeInterval(Double(i) * 0.18), origin: CGPoint(x: start.x, y: start.y - 20),
                                  towardX: size.width / 2 + CGFloat.random(in: -110...110), seed: .random(in: 0...1),
                                  radius: .random(in: 11...19)))
        }
        guard bubbleLoop == nil else { return }
        bubbleLoop = Task { @MainActor in
            var lastSwat = Date.distantPast
            while !Task.isCancelled, !bubbles.isEmpty {
                let now = Date.now
                bubbles.removeAll { b in
                    if let popped = b.poppedAt { return now.timeIntervalSince(popped) > 0.45 }
                    return now > b.born && b.position(at: now).y < -40
                }
                let reach = head.offsetBy(dx: petOffset, dy: 0).insetBy(dx: -34, dy: -26).offsetBy(dx: 0, dy: -22)
                let live = bubbles.indices.filter { bubbles[$0].poppedAt == nil && now >= bubbles[$0].born }
                // Eyes on the nearest bubble.
                if !busy, let i = live.min(by: { bubbles[$0].position(at: now).distance(to: reach.center) < bubbles[$1].position(at: now).distance(to: reach.center) }) {
                    let p = bubbles[i].position(at: now)
                    scene.look = CGPoint(x: (p.x - reach.midX) / (size.width * 0.4), y: (p.y - reach.midY) / (size.height * 0.3))
                    if reach.contains(p), now.timeIntervalSince(lastSwat) > 0.65 {
                        lastSwat = now
                        add(.swat(left: p.x < reach.midX))
                        let id = bubbles[i].id
                        try? await Task.sleep(for: .seconds(0.14))
                        if let j = bubbles.firstIndex(where: { $0.id == id }), bubbles[j].poppedAt == nil {
                            bubbles[j].poppedAt = .now
                            Haptics.light()
                        }
                        continue
                    }
                } else if live.isEmpty, !busy {
                    scene.look = nil
                }
                try? await Task.sleep(for: .seconds(1.0 / 20))
            }
            if !busy { scene.look = nil }
            bubbleLoop = nil
        }
    }

    private func popBubble(near location: CGPoint) {
        let now = Date.now
        guard let i = bubbles.indices.filter({ bubbles[$0].poppedAt == nil && now >= bubbles[$0].born })
            .min(by: { bubbles[$0].position(at: now).distance(to: location) < bubbles[$1].position(at: now).distance(to: location) }),
            bubbles[i].position(at: now).distance(to: location) < bubbles[i].radius + 22 else { return }
        bubbles[i].poppedAt = now
        Haptics.light()
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
            // Caught: it holds the snack up in both paws and eats it in three bites.
            flying = nil
            scene.look = nil
            scene.heldProp = .snack
            Haptics.success()
            add(.munch)
            for _ in 0..<3 {
                try? await Task.sleep(for: .seconds(0.7))
                Haptics.soft()
            }
            try? await Task.sleep(for: .seconds(0.12))
            scene.heldProp = nil
            try? await Task.sleep(for: .seconds(1.0))
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
                if !reduceMotion {
                    Canvas { ctx, canvasSize in
                        CalmMotes.draw(ctx, size: canvasSize, t: clock.date.timeIntervalSince1970, breath: guided ? breath : nil)
                    }
                    .allowsHitTesting(false)
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

/// Music notes rising off the dancing pet: one every second or so, swaying as they climb and
/// fading out near the top, where they slip behind the glass buttons.
enum RisingNotes {
    static func draw(_ ctx: GraphicsContext, from origin: CGPoint, height: CGFloat, t: Double) {
        let colors = [Color(red: 0.2, green: 0.62, blue: 0.58), Color(red: 0.93, green: 0.45, blue: 0.5), Color(red: 0.45, green: 0.5, blue: 0.85)]
        for i in 0..<8 {
            // Each note has its own pace and path, re-rolled every time it starts again.
            let period = 5.5 + Double(i % 4) * 0.9
            let phase = t / period + Double(i) * 0.37
            let u = phase.truncatingRemainder(dividingBy: 1)
            let seed = floor(phase) * 7.31 + Double(i) * 3.17
            let rnd = { (k: Double) in (sin(seed * 12.9898 + k * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude }
            let side: CGFloat = i.isMultiple(of: 2) ? 1 : -1
            let reach = CGFloat(60 + rnd(1) * 130)
            let curve = CGFloat(1 - (1 - u) * (1 - u))
            let x = origin.x + side * (14 + reach * curve) + CGFloat(sin(u * (6 + rnd(2) * 4) + seed)) * 9
            let y = origin.y + 8 - CGFloat(u) * (origin.y + 70) * CGFloat(0.8 + rnd(3) * 0.3)
            let alpha = min(1, u * 8) * (u > 0.75 ? (1 - u) / 0.25 : 1)
            var note = ctx
            note.opacity = alpha * 0.85
            note.translateBy(x: x, y: y)
            note.rotate(by: .radians(sin(u * 5 + seed) * 0.35))
            note.draw(Text(rnd(4) > 0.6 ? "♫" : "♪").font(.system(size: 18 + CGFloat(u) * 9, weight: .bold, design: .rounded))
                .foregroundStyle(colors[Int(rnd(5) * 3) % 3]), at: .zero)
        }
    }
}

/// Meditating: a few soft motes rise slowly through the room, brightening on the out-breath,
/// and drift up behind the glass. Nothing to track, just something gentle to rest the eyes on.
enum CalmMotes {
    static func draw(_ ctx: GraphicsContext, size: CGSize, t: Double, breath: Double?) {
        let glow = breath.map { 0.55 + (1 - $0) * 0.45 } ?? 0.8
        for i in 0..<12 {
            let period = 16 + Double(i % 5) * 2.5
            let u = (t / period + Double(i) * 0.137).truncatingRemainder(dividingBy: 1)
            let seed = Double(i) * 5.3
            let x = size.width * CGFloat(0.08 + (sin(seed) * 0.5 + 0.5) * 0.84) + CGFloat(sin(t * 0.3 + seed)) * 16
            let y = size.height * CGFloat(0.95 - u * 1.05)
            let alpha = min(1, u * 5) * min(1, (1 - u) * 5) * glow
            let r = 2.2 + CGFloat(i % 3)
            ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)), with: .color(Color(red: 1, green: 0.95, blue: 0.8).opacity(0.12 * alpha)))
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color(red: 1, green: 0.97, blue: 0.88).opacity(0.75 * alpha)))
        }
    }
}

/// One soap bubble: it rises and wobbles toward the pet, then pops in a little ring of droplets.
struct Bubble: Identifiable {
    let id = UUID()
    let born: Date
    let origin: CGPoint
    let towardX: CGFloat
    let seed: Double
    let radius: CGFloat
    var poppedAt: Date?

    func position(at date: Date) -> CGPoint {
        let t = max(0, date.timeIntervalSince(born))
        let drift = CGFloat(min(1, t / 2.6))
        let x = origin.x + (towardX - origin.x) * (1 - (1 - drift) * (1 - drift)) + CGFloat(sin(t * 1.6 + seed * 6)) * 14
        let y = origin.y - CGFloat(t) * (58 + CGFloat(seed) * 26) - CGFloat(min(t, 0.4)) * 60
        return CGPoint(x: x, y: y)
    }

    func draw(_ ctx: GraphicsContext, at date: Date) {
        guard date >= born else { return }
        let p = position(at: poppedAt ?? date)
        if let popped = poppedAt {
            let u = min(1, date.timeIntervalSince(popped) / 0.4)
            let ring = radius * (1 + CGFloat(u) * 0.6)
            let fade = 1 - u
            for k in 0..<7 {
                let a = Double(k) / 7 * 2 * .pi + seed
                let d = CGPoint(x: p.x + CGFloat(cos(a)) * ring, y: p.y + CGFloat(sin(a)) * ring)
                ctx.fill(Path(ellipseIn: CGRect(x: d.x - 1.6, y: d.y - 1.6, width: 3.2, height: 3.2)), with: .color(Color(red: 0.6, green: 0.8, blue: 1).opacity(fade)))
            }
            return
        }
        let t = date.timeIntervalSince(born)
        let r = radius * CGFloat(min(1, 0.4 + t * 2)) * (1 + CGFloat(sin(t * 5 + seed * 9)) * 0.04)
        let rect = CGRect(x: p.x - r, y: p.y - r * 0.97, width: r * 2, height: r * 1.94)
        let shell = Path(ellipseIn: rect)
        ctx.fill(shell, with: .radialGradient(Gradient(colors: [.white.opacity(0.03), Color(red: 0.7, green: 0.88, blue: 1).opacity(0.22)]),
                                              center: p, startRadius: 0, endRadius: r))
        // A thin rim that shimmers from blue to pink as it turns.
        let hue = (seed + t * 0.15).truncatingRemainder(dividingBy: 1)
        ctx.stroke(shell, with: .linearGradient(Gradient(colors: [Color(hue: 0.55 + hue * 0.1, saturation: 0.5, brightness: 1), Color(hue: 0.9, saturation: 0.35, brightness: 1)]),
                                                startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)), lineWidth: 1.4)
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.55, y: p.y - r * 0.6, width: r * 0.42, height: r * 0.26)), with: .color(.white.opacity(0.85)))
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

/// The bubble wand: a loop with a shimmering soap film on a short handle, and two little
/// bubbles already floating off it, so it reads as "bubbles" at a glance.
private struct WandToken: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let pink = Color(red: 0.95, green: 0.5, blue: 0.62)
            let ring = CGRect(x: s * 0.14, y: s * 0.22, width: s * 0.5, height: s * 0.5)
            // Handle, down and to the left.
            var handle = Path()
            handle.move(to: CGPoint(x: ring.midX - s * 0.1, y: ring.maxY - s * 0.02))
            handle.addLine(to: CGPoint(x: s * 0.2, y: s * 0.98))
            ctx.stroke(handle, with: .color(pink), style: StrokeStyle(lineWidth: s * 0.1, lineCap: .round))
            // The film: faint and iridescent.
            let film = Path(ellipseIn: ring.insetBy(dx: s * 0.04, dy: s * 0.04))
            ctx.fill(film, with: .linearGradient(Gradient(colors: [Color(red: 0.7, green: 0.9, blue: 1).opacity(0.55), Color(red: 1, green: 0.8, blue: 0.95).opacity(0.45)]),
                                                 startPoint: CGPoint(x: ring.minX, y: ring.minY), endPoint: CGPoint(x: ring.maxX, y: ring.maxY)))
            ctx.stroke(Path(ellipseIn: ring), with: .color(pink), lineWidth: s * 0.09)
            ctx.fill(Path(ellipseIn: CGRect(x: ring.minX + s * 0.1, y: ring.minY + s * 0.1, width: s * 0.1, height: s * 0.06)), with: .color(.white.opacity(0.9)))
            // Two bubbles drifting off to the upper right.
            for (x, y, r) in [(0.8, 0.26, 0.11), (0.9, 0.05, 0.07)] as [(CGFloat, CGFloat, CGFloat)] {
                let b = CGRect(x: s * x - s * r, y: s * y, width: s * r * 2, height: s * r * 2)
                ctx.fill(Path(ellipseIn: b), with: .color(Color(red: 0.75, green: 0.9, blue: 1).opacity(0.35)))
                ctx.stroke(Path(ellipseIn: b), with: .color(Color(red: 0.45, green: 0.66, blue: 0.92)), lineWidth: 1.4)
                ctx.fill(Path(ellipseIn: CGRect(x: b.minX + b.width * 0.22, y: b.minY + b.height * 0.2, width: b.width * 0.3, height: b.height * 0.2)), with: .color(.white.opacity(0.9)))
            }
        }
    }
}

/// The pet's own snack, as it sits in the tray (the same drawing it eats from its paws).
private struct SnackToken: View {
    var species: PetSpecies
    var body: some View {
        Canvas { ctx, size in
            PetSnackArt.draw(ctx, species: species, at: CGPoint(x: size.width / 2, y: size.height / 2), size: size.width * 0.95)
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
