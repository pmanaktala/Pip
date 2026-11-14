import SwiftUI

/// How much of the pet a view shows (Bible §3).
public enum PetFraming: Sendable {
    /// The whole pet standing on its floor.
    case full
    /// Head and shoulders, for 40–90 pt.
    case face
    /// The head alone, simplified, for 20–40 pt.
    case badge
    /// The app icon: head and shoulders, a little larger.
    case icon

    var detail: PetDetail {
        switch self {
        case .full: .full
        case .face, .icon: .face
        case .badge: .badge
        }
    }
}

/// Draws one pose. Everything else in the pet module feeds this.
///
/// Animatable: when a static surface swaps one hold pose for another (a widget entry, a Live
/// Activity update, a mood token), SwiftUI interpolates channel by channel, so the change reads
/// as motion rather than a cut.
public struct PetPoseView: View, Animatable {
    public var species: PetSpecies
    public var pose: PetPose
    public var prop: PetProp?
    public var wear: PetWear?
    public var framing: PetFraming
    public var time: Double?
    public var showsShadow: Bool
    /// Draw for a tinted surface (see `PetPalette.monochrome`).
    public var monochrome: Bool
    /// The rest of the outfit: neck, floor extra, sign. (The head is `wear`.)
    public var dressing: PetDressing?
    public var staging: PetPropStage?

    public init(species: PetSpecies, pose: PetPose, prop: PetProp? = nil, wear: PetWear? = nil, framing: PetFraming = .full, time: Double? = nil, showsShadow: Bool = true, monochrome: Bool = false, dressing: PetDressing? = nil, staging: PetPropStage? = nil) {
        self.staging = staging
        self.monochrome = monochrome
        self.dressing = dressing
        self.species = species
        self.pose = pose
        self.prop = prop
        self.wear = wear
        self.framing = framing
        self.time = time
        self.showsShadow = showsShadow
    }

    @AppStorage("pet.illustratedArtwork", store: SharedStateStore.shared.defaultsSuite) private var illustratedArtwork = true

    #if DEBUG && os(iOS)
    @Environment(\.petConceptArtwork) private var conceptArtwork
    #endif

    public var animatableData: PetPose.Vector {
        get { pose.vector }
        set { pose.vector = newValue }
    }

    public var body: some View {
        Group {
            #if DEBUG && os(iOS)
            if let directory = conceptArtwork {
                PetConceptArtwork(species: species, framing: framing, directory: directory)
            } else {
                drawing
            }
            #else
            drawing
            #endif
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var drawing: some View {
        Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) { context, size in
            var ctx = context
            let side = min(size.width, size.height)
            ctx.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
            ctx.scaleBy(x: side / 200, y: side / 200)
            Self.frame(&ctx, species: species, framing: framing, style: illustratedArtwork ? .illustrated : .original)
            // Held props belong to the full pet; what it wears shows at every size.
            PetRenderer.draw(ctx, PetPaint(species: species, pose: pose, prop: framing == .full ? prop : nil, wear: wear, detail: framing.detail, time: time, monochrome: monochrome,
                                           neck: dressing?.neck, extra: framing == .full ? dressing?.extra : nil, sign: framing == .full ? dressing?.sign : nil, style: illustratedArtwork ? .illustrated : .original, staging: staging),
                             showsShadow: showsShadow)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// Zooms the 200-unit design space onto the head for the tighter framings.
    static func frame(_ ctx: inout GraphicsContext, species: PetSpecies, framing: PetFraming, style: PetArtStyle = .illustrated) {
        let head = PetFigure.of(species, style: style).headCenter
        let (zoom, focusY): (CGFloat, CGFloat) = switch framing {
        case .full: (1, 100)
        case .face: (1.5, head.y + 16)
        case .badge: species == .penguin ? (2.0, head.y + 2) : (1.78, head.y - 5)
        case .icon: species == .cat ? (1.42, head.y + 2) : species == .dog ? (1.52, head.y + 8) : (1.62, head.y + 12)
        }
        guard zoom != 1 else { return }
        ctx.translateBy(x: 100, y: 100)
        ctx.scaleBy(x: zoom, y: zoom)
        ctx.translateBy(x: -100, y: -focusY)
    }
}

/// A pet that holds still: widgets, complications, the Live Activity, mood tokens, history.
public struct PetView: View {
    public var species: PetSpecies
    public var scene: PetScene
    public var hold: Int
    public var framing: PetFraming
    public var showsShadow: Bool

    /// A pet in a stance, showing the stance's `hold` pose.
    public init(species: PetSpecies, stance: PetStance, hold: Int = 0, wear: PetWear? = nil, framing: PetFraming = .full, showsShadow: Bool = true) {
        self.species = species
        self.scene = PetScene(species: species, stance: stance, wear: wear ?? (stance.isAsleep ? .nightcap : nil))
        self.hold = hold
        self.framing = framing
        self.showsShadow = showsShadow
    }

    /// A mood as the pet's face — for mood tokens, history and pickers. Uses the mood's
    /// turned-up token face so eight feelings stay distinct at small sizes.
    public init(species: PetSpecies, mood: Mood, intensity: MoodIntensity = .moderate, framing: PetFraming = .badge) {
        self.init(species: species, stance: .mood(mood, intensity), framing: framing, showsShadow: false)
        self.token = mood
    }

    public var body: some View {
        if let token {
            PetPoseView(species: species, pose: PetStance.tokenFace(token, species), framing: framing, showsShadow: false)
        } else {
            PetPoseView(species: species, pose: PetDirector.hold(scene, index: hold), prop: scene.prop, wear: scene.wear, framing: framing, showsShadow: showsShadow, dressing: scene.dressing)
        }
    }

    /// Set when the view stands for a mood (a token) rather than the pet's current state.
    private var token: Mood?
}

/// A pet on the director's clock. Honours Reduce Motion (holds the stance's rest pose) and the
/// system's reduced-resource hint (30 fps).
public struct LivePetView: View {
    public var scene: PetScene
    public var framing: PetFraming
    public var showsShadow: Bool
    public var paused: Bool

    @State private var propHandling: PetPropHandling
    @AppStorage("pet.illustratedArtwork", store: SharedStateStore.shared.defaultsSuite) private var illustratedArtwork = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.self) private var environment

    public init(scene: PetScene, framing: PetFraming = .full, showsShadow: Bool = true, paused: Bool = false) {
        let original = SharedStateStore.shared.defaultsSuite.object(forKey: "pet.illustratedArtwork") as? Bool == false
        _propHandling = State(initialValue: PetPropHandling(prop: scene.handlingProp(style: original ? .original : .illustrated)))
        self.scene = scene
        self.framing = framing
        self.showsShadow = showsShadow
        self.paused = paused
    }

    private var artStyle: PetArtStyle { illustratedArtwork ? .illustrated : .original }
    private var carriedProp: PetProp? { scene.handlingProp(style: artStyle) }

    private var frameInterval: Double {
        #if os(watchOS)
        return 1.0 / 30
        #else
        #if compiler(>=6.4) && os(iOS)
        if #available(iOS 27, *), environment.systemPrefersReducedResourceUsage { return 1.0 / 30 }
        #endif
        return 1.0 / 60
        #endif
    }

    private var isConceptPreview: Bool {
        #if DEBUG && os(iOS)
        return environment.petConceptArtwork != nil
        #else
        return false
        #endif
    }

    public var body: some View {
        Group {
            if reduceMotion || paused || isConceptPreview {
                PetPoseView(species: scene.species, pose: PetDirector.hold(scene), prop: scene.prop, wear: scene.wear, framing: framing, showsShadow: showsShadow, dressing: scene.dressing,
                            staging: PetPropStage(carried: carriedProp))
            } else {
                TimelineView(.animation(minimumInterval: frameInterval)) { context in
                    let pose = PetDirector.pose(scene, at: context.date)
                    let frame = propHandling.frame(at: context.date, base: pose, fallback: scene.prop(for: pose),
                                                   species: scene.species, style: artStyle)
                    PetPoseView(species: scene.species, pose: frame.pose, prop: frame.prop, wear: scene.wear, framing: framing,
                                time: context.date.timeIntervalSince1970, showsShadow: showsShadow,
                                dressing: scene.dressing, staging: frame.stage)
                        // The clock already interpolates the bones. A room-camera animation
                        // must not interpolate ownership and paw targets a second time.
                        .transaction { $0.animation = nil }
                }
            }
        }
        .onChange(of: scene) { old, new in
            if old.species != new.species || reduceMotion || paused {
                propHandling = PetPropHandling(prop: new.handlingProp(style: artStyle))
            } else if old.handlingProp(style: artStyle) != new.handlingProp(style: artStyle) {
                let now = Date.now
                propHandling.request(new.handlingProp(style: artStyle), at: now, source: PetDirector.pose(old, at: now),
                                     species: old.species, style: artStyle)
            }
        }
        .onChange(of: reduceMotion) { _, _ in propHandling = PetPropHandling(prop: carriedProp) }
        .onChange(of: illustratedArtwork) { _, _ in propHandling = PetPropHandling(prop: carriedProp) }
        .onChange(of: paused) { _, _ in propHandling = PetPropHandling(prop: carriedProp) }
    }

}

/// The pet in its room: the room full-bleed, the pet standing on the horizon.
///
/// `petScale` is the pet's width as a fraction of the stage's width; `floor` is where its feet
/// meet the horizon, as a fraction of the height. The room is drawn to match.
public struct PetStage: View {
    public var scene: PetScene
    public var live: Bool
    public var hold: Int
    public var petScale: CGFloat
    public var floor: CGFloat
    public var showsRoom: Bool
    public var showsFoliage: Bool
    public var mood: Mood?
    public var date: Date
    public var showsSeason: Bool
    /// Moves the pet sideways within the room (fetching).
    public var petOffset: CGFloat
    /// Still surfaces: leaning into a hand (petted from a widget).
    public var petted: Bool

    public init(scene: PetScene, live: Bool = true, hold: Int = 0, petScale: CGFloat = 0.62, floor: CGFloat = 0.62, showsRoom: Bool = true,
                showsFoliage: Bool = true, mood: Mood? = nil, date: Date = .now, showsSeason: Bool = true, petOffset: CGFloat = 0, petted: Bool = false) {
        self.petted = petted
        self.showsSeason = showsSeason
        self.petOffset = petOffset
        self.scene = scene
        self.live = live
        self.hold = hold
        self.petScale = petScale
        self.floor = floor
        self.showsRoom = showsRoom
        self.showsFoliage = showsFoliage
        self.mood = mood
        self.date = date
    }

    public var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width * petScale, geo.size.height * 0.9)
            // In the 200-unit space the feet are at y = 170: put that on the horizon.
            let top = geo.size.height * floor - side * PetFigure.floor / 200
            ZStack(alignment: .topLeading) {
                if showsRoom {
                    PetRoom(mood: mood, date: date, horizon: floor, showsFoliage: showsFoliage)
                }
                if showsSeason {
                    PetSeasonLayer(season: scene.dressing.season, confetti: scene.dressing.confetti, live: live, date: date)
                }
                Group {
                    if live {
                        LivePetView(scene: scene)
                    } else {
                        let still = PetDirector.hold(scene, index: hold)
                        PetPoseView(species: scene.species, pose: petted ? PetDirector.petting(still, stance: scene.stance, species: scene.species, t: 0, weight: 1).clamped() : still,
                                    prop: scene.prop, wear: scene.wear, dressing: scene.dressing)
                    }
                }
                .frame(width: side, height: side)
                .offset(x: (geo.size.width - side) / 2 + petOffset, y: top)
            }
        }
    }
}

/// Where the pet's head is inside a `PetStage`, for aiming touches and glances.
public extension PetStage {
    static func headRect(in size: CGSize, species: PetSpecies, petScale: CGFloat, floor: CGFloat) -> CGRect {
        let side = min(size.width * petScale, size.height * 0.9)
        let top = size.height * floor - side * PetFigure.floor / 200
        let fig = PetFigure.of(species)
        let k = side / 200
        let left = (size.width - side) / 2
        return CGRect(x: left + (fig.headCenter.x - fig.headRX) * k, y: top + (fig.headCenter.y - fig.headRY - 6) * k,
                      width: fig.headRX * 2 * k, height: (fig.headRY * 2 + 6) * k)
    }

    static func bodyRect(in size: CGSize, species: PetSpecies, petScale: CGFloat, floor: CGFloat) -> CGRect {
        let side = min(size.width * petScale, size.height * 0.9)
        let top = size.height * floor - side * PetFigure.floor / 200
        let k = side / 200
        let left = (size.width - side) / 2
        let fig = PetFigure.of(species)
        let y0 = fig.headCenter.y + fig.headRY
        return CGRect(x: left + 52 * k, y: top + y0 * k, width: 96 * k, height: (PetFigure.floor - y0) * k)
    }
}
