import SwiftUI

/// Renders a pet for a given identity and resolved state.
///
/// `time` drives idle motion. Pass `nil` (widgets, Reduce Motion) for a still pose.
/// The rig is `Animatable`, so changing `state` inside `withAnimation` interpolates
/// the pose and expression field by field.
public struct PetView: View, Animatable {
    public var identity: PetIdentity
    public var rig: PetRig
    public var motion: PetMotionProfile
    public var time: TimeInterval?
    public var showsShadow: Bool
    public var framing: Framing

    /// How much of the pet to show.
    public enum Framing: Sendable {
        /// Whole pet with room for the tail and shadow.
        case full
        /// Head and shoulders — for medium sizes (40–120pt) such as cards and the Live Activity.
        case face
        /// Head only, simplified — for tiny sizes (20–48pt) such as picker buttons and calendar cells.
        case badge
        /// Head fills the frame — used by the icon renderer.
        case icon
    }

    @Environment(\.colorScheme) private var colorScheme

    public init(identity: PetIdentity, state: PetMoodState, time: TimeInterval? = nil, showsShadow: Bool = true, framing: Framing = .full) {
        self.identity = identity
        self.rig = state.rig
        self.motion = state.motion
        self.time = time
        self.showsShadow = showsShadow
        self.framing = framing
    }

    public var animatableData: PetRig.Vector {
        get { rig.vector }
        set { rig.vector = newValue }
    }

    public var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { context, size in
            let scale = min(size.width, size.height) / 200
            var ctx = context
            ctx.translateBy(x: (size.width - 200 * scale) / 2, y: (size.height - 200 * scale) / 2)
            ctx.scaleBy(x: scale, y: scale)
            let zoom: CGFloat
            switch framing {
            case .full: zoom = 1
            case .face: zoom = 1.5
            case .badge: zoom = 1.9
            case .icon: zoom = 1.55
            }
            if framing != .full {
                // Zoom on the head; the pivot keeps the face centred as the pose changes.
                let headY = Self.headCenterY(identity: identity, rig: rig)
                let offset: CGFloat = switch framing {
                case .face: 10
                case .icon: -8
                default: 0
                }
                ctx.translateBy(x: 100, y: 100)
                ctx.scaleBy(x: zoom, y: zoom)
                ctx.translateBy(x: -100, y: -(headY + offset))
            }
            let detail: PetPaintContext.Detail = scale * zoom < 0.42 || framing == .badge ? .small : .full
            Self.draw(&ctx, identity: identity, rig: rig, motion: motion, time: time, colorScheme: colorScheme, showsShadow: showsShadow && framing == .full, detail: detail)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .accessibilityHidden(true)
    }

    /// Where the head centre lands for a rig, so zoomed framings stay on the face.
    static func headCenterY(identity: PetIdentity, rig: PetRig) -> CGFloat {
        PetPaintContext(rig: rig, live: .still, palette: PetPalette.palette(for: identity.species), colorScheme: .light, anatomy: identity.species.anatomy).head.center.y
    }

    /// Draws the pet in a 200×200 design space. Shared by the view and any offscreen rendering.
    public static func draw(_ ctx: inout GraphicsContext, identity: PetIdentity, rig base: PetRig, motion: PetMotionProfile, time: TimeInterval?, colorScheme: ColorScheme, showsShadow: Bool, detail: PetPaintContext.Detail = .full) {
        let (rig, live) = PetAnimator.animate(rig: base, motion: motion, time: time)
        let p = PetPaintContext(rig: rig, live: live, palette: PetPalette.palette(for: identity.species), colorScheme: colorScheme, anatomy: identity.species.anatomy, detail: detail)

        if showsShadow { PetDraw.floorShadow(&ctx, p) }

        // One body transform for the pet and anything it holds (see `PetDraw.bodyTransform`).
        // Head tilt is applied by each painter about the neck.
        ctx.concatenate(PetDraw.bodyTransform(rig: rig, live: live))

        switch identity.species {
        case .cat: CatPainter.paint(&ctx, p)
        case .dog: DogPainter.paint(&ctx, p)
        case .capybara: CapybaraPainter.paint(&ctx, p)
        case .penguin: PenguinPainter.paint(&ctx, p)
        case .redPanda: RedPandaPainter.paint(&ctx, p)
        }
    }
}

/// Convenience: an animated pet that keeps its own clock. Respects Reduce Motion.
public struct AnimatedPetView: View {
    public var identity: PetIdentity
    public var state: PetMoodState
    public var showsShadow: Bool
    public var isPaused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(identity: PetIdentity, state: PetMoodState, showsShadow: Bool = true, isPaused: Bool = false) {
        self.identity = identity
        self.state = state
        self.showsShadow = showsShadow
        self.isPaused = isPaused
    }

    public var body: some View {
        if reduceMotion || isPaused {
            PetView(identity: identity, state: state, time: nil, showsShadow: showsShadow)
                .animation(.smooth(duration: 0.6), value: state.rig)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                PetView(identity: identity, state: state, time: context.date.timeIntervalSinceReferenceDate, showsShadow: showsShadow)
                    .animation(.smooth(duration: 0.7), value: state.rig)
            }
        }
    }
}

// MARK: - Previews

#Preview("All species · happy") {
    HStack {
        ForEach(PetSpecies.allCases) { species in
            let id = PetIdentity(species: species)
            AnimatedPetView(identity: id, state: PetStateResolver.resolve(mood: .happy, identity: id))
        }
    }
    .padding()
}

#Preview("Cat · every mood") {
    let id = PetIdentity(species: .cat)
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))]) {
        ForEach(Mood.allCases) { mood in
            VStack {
                PetView(identity: id, state: PetStateResolver.resolve(mood: mood, identity: id))
                Text(mood.displayName).font(.caption)
            }
        }
    }
    .padding()
}

#Preview("Intensity · stressed · dark") {
    let id = PetIdentity(species: .cat)
    HStack {
        ForEach(MoodIntensity.allCases) { intensity in
            PetView(identity: id, state: PetStateResolver.resolve(mood: .stressed, intensity: intensity, identity: id))
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Scene") {
    PetSceneView(identity: PetIdentity(species: .redPanda), state: PetStateResolver.resolve(mood: .excited, intensity: .strong, identity: PetIdentity(species: .redPanda)), time: 3)
}
