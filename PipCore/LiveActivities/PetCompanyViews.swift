import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Pet the pet from the Lock Screen or the Dynamic Island. Runs in the app's process.
public struct PetCompanionIntent: AppIntent, LiveActivityIntent {
    public static let title: LocalizedStringResource = "Pet"
    public static let description = IntentDescription("Give your pet a little scratch.")
    public static let openAppWhenRun = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        let name = Activity<PetCompanyAttributes>.activities.first?.attributes.identity.name ?? PetSpecies.penguin.defaultName
        await PetCompanyManager.shared.pet(name: name)
        return .result()
    }
}

/// What the pet looks like for a content state: its company pose, leaning into a hand when
/// petted, dozing once the activity has gone stale.
public enum PetCompanyLook {
    public static func pose(_ state: PetCompanyAttributes.ContentState, species: PetSpecies, stale: Bool) -> (PetPose, PetProp?) {
        if stale {
            let scene = PetScene(species: species, stance: .life(.napping))
            return (PetDirector.hold(scene, index: 0), state.stance.prop == .blanket ? .blanket : nil)
        }
        let scene = PetScene(species: species, stance: state.stance)
        let base = PetDirector.hold(scene, index: state.hold)
        return (state.petted ? PetDirector.petting(base, species: species, t: 0, weight: 1).clamped() : base, scene.prop)
    }

    /// Dozing wears the nightcap; so does company after bedtime.
    public static func wear(_ state: PetCompanyAttributes.ContentState, stale: Bool, at date: Date = .now) -> PetWear? {
        stale ? .nightcap : PetWear.choose(for: state.stance, at: date, music: false)
    }

    public static func line(_ state: PetCompanyAttributes.ContentState, name: String, stale: Bool) -> String {
        stale && !state.petted ? PetCompanyWords.dozed(name) : state.line
    }
}

/// The Lock Screen / StandBy banner: a slice of the pet's room with the pet in it, its line,
/// and the Pet button. Nothing counts down.
public struct PetCompanyBanner: View {
    public var identity: PetIdentity
    public var state: PetCompanyAttributes.ContentState
    public var stale: Bool

    public init(identity: PetIdentity, state: PetCompanyAttributes.ContentState, stale: Bool) {
        self.identity = identity
        self.state = state
        self.stale = stale
    }

    public var body: some View {
        let (pose, prop) = PetCompanyLook.pose(state, species: identity.species, stale: stale)
        HStack(spacing: 14) {
            ZStack(alignment: .top) {
                PetRoom(mood: state.mood, date: .now, horizon: 0.84, showsFoliage: false)
                PetPoseView(species: identity.species, pose: pose, prop: prop, wear: PetCompanyLook.wear(state, stale: stale), showsShadow: true)
                    .frame(width: 96, height: 96)
                    .offset(y: 96 * 0.84 - 96 * 170 / 200)
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .animation(.smooth(duration: 0.9), value: state)

            VStack(alignment: .leading, spacing: 3) {
                Text(PetCompanyLook.line(state, name: identity.name, stale: stale))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .lineLimit(2)
                    .contentTransition(.opacity)
                Text("Here since \(state.startedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            PetButton(identity: identity, mood: state.mood, petted: state.petted)
        }
        .padding(14)
        .widgetURL(URL(string: "pip://home"))
        .accessibilityElement(children: .contain)
    }
}

struct PetButton: View {
    var identity: PetIdentity
    var mood: Mood
    var petted: Bool

    var body: some View {
        Button(intent: PetCompanionIntent()) {
            // A soft paw, not a raised hand: a hand on a coloured disc reads as "stop".
            Image(systemName: petted ? "heart.fill" : "pawprint.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MoodColor.bold(mood))
                .frame(width: 44, height: 44)
                .background(MoodColor.bold(mood).opacity(0.2), in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pet \(identity.name)")
    }
}

/// The small family: the watch Smart Stack and CarPlay.
public struct PetCompanySmall: View {
    public var identity: PetIdentity
    public var state: PetCompanyAttributes.ContentState
    public var stale: Bool

    public init(identity: PetIdentity, state: PetCompanyAttributes.ContentState, stale: Bool) {
        self.identity = identity
        self.state = state
        self.stale = stale
    }

    public var body: some View {
        let (pose, _) = PetCompanyLook.pose(state, species: identity.species, stale: stale)
        HStack(spacing: 8) {
            PetPoseView(species: identity.species, pose: pose, wear: PetCompanyLook.wear(state, stale: stale), framing: .face, showsShadow: false)
                .frame(width: 44, height: 44)
            Text(PetCompanyLook.line(state, name: identity.name, stale: stale))
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
    }
}
