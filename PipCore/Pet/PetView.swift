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

    @Environment(\.colorScheme) private var colorScheme

    public init(identity: PetIdentity, state: PetMoodState, time: TimeInterval? = nil, showsShadow: Bool = true) {
        self.identity = identity
        self.rig = state.rig
        self.motion = state.motion
        self.time = time
        self.showsShadow = showsShadow
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
            Self.draw(&ctx, identity: identity, rig: rig, motion: motion, time: time, colorScheme: colorScheme, showsShadow: showsShadow)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// Draws the pet in a 200×200 design space. Shared by the view and any offscreen rendering.
    public static func draw(_ ctx: inout GraphicsContext, identity: PetIdentity, rig base: PetRig, motion: PetMotionProfile, time: TimeInterval?, colorScheme: ColorScheme, showsShadow: Bool) {
        let (rig, live) = PetAnimator.animate(rig: base, motion: motion, time: time)
        let p = PetPaintContext(rig: rig, live: live, palette: PetPalette.palette(for: identity.species), colorScheme: colorScheme)

        if showsShadow { PetDraw.floorShadow(&ctx, p) }

        // Body transform: bounce / lift / jitter, then tilt+sway and breathing about the feet.
        let pivot = CGPoint(x: 100, y: 168)
        ctx.translateBy(x: CGFloat(live.jitterX), y: CGFloat(live.bounce + rig.lift + live.jitterY))
        ctx.translateBy(x: pivot.x, y: pivot.y)
        ctx.rotate(by: .degrees(rig.tilt + live.sway))
        ctx.scaleBy(x: 1 / sqrt(live.breathScale), y: live.breathScale)
        ctx.translateBy(x: -pivot.x, y: -pivot.y)

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
                    .animation(.spring(duration: 0.75, bounce: 0.25), value: state.rig)
            }
        }
    }
}
