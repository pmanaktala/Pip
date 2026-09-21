import AppIntents
import SwiftData

/// Side effects the current process can perform after a log. The app registers Health and
/// Live Activity effects at launch; the widget extension registers nothing.
@MainActor
public enum MoodSideEffectRegistry {
    public static var effects: [any MoodLogSideEffect] = []
}

/// Log a mood from a widget button, Shortcuts or Siri — without opening the app.
///
/// Conforming to `LiveActivityIntent` makes the system run it in the app's process,
/// so the mood-change Live Activity and Health write happen exactly as in-app logs.
#if canImport(ActivityKit)
public typealias PipIntentBase = AppIntent & LiveActivityIntent
#else
public typealias PipIntentBase = AppIntent
#endif

public struct LogMoodIntent: PipIntentBase {
    public static let title: LocalizedStringResource = "Log Mood"
    public static let description = IntentDescription("Tell your pet how you feel.")
    public static let openAppWhenRun = false

    @Parameter(title: "Mood")
    public var mood: MoodAppEnum

    @Parameter(title: "Intensity", default: .moderate)
    public var intensity: IntensityAppEnum

    public static var parameterSummary: some ParameterSummary {
        Summary("I’m feeling \(\.$mood)") {
            \.$intensity
        }
    }

    public init() {}

    public init(mood: Mood, intensity: MoodIntensity = .moderate) {
        self.mood = MoodAppEnum(mood)
        self.intensity = IntensityAppEnum(rawValue: intensity.rawValue) ?? .moderate
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PipModelContainer.shared.mainContext
        let logger = MoodLogger(context: context, sideEffects: MoodSideEffectRegistry.effects)
        let entry = logger.log(mood: mood.mood, intensity: intensity.intensity)
        let name = PipQueries.petProfile(in: context)?.name ?? PetSpecies.penguin.defaultName
        return .result(dialog: "\(name) \(entry.mood.petDescription).")
    }
}

/// Opens the app on the pet.
public struct OpenPetIntent: AppIntent {
    public static let title: LocalizedStringResource = "See Your Pet"
    public static let openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        .result()
    }
}

#if canImport(ActivityKit)
/// Wave at the pet from a Live Activity. Runs in the app's process and updates the moment's pose.
public struct WaveAtPetIntent: AppIntent, LiveActivityIntent {
    public static let title: LocalizedStringResource = "Wave"
    public static let description = IntentDescription("Say hi to your pet.")
    public static let openAppWhenRun = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        await PetMomentManager.shared.wave()
        return .result()
    }
}
#endif
