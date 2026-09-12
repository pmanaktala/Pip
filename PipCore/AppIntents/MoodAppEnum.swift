import AppIntents

/// `Mood` exposed to App Intents / Shortcuts.
public enum MoodAppEnum: String, AppEnum {
    case happy, excited, calm, neutral, tired, stressed, sad, frustrated

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Mood")

    public static let caseDisplayRepresentations: [MoodAppEnum: DisplayRepresentation] = [
        .happy: DisplayRepresentation(title: "Happy", image: .init(systemName: "sun.max")),
        .excited: DisplayRepresentation(title: "Excited", image: .init(systemName: "sparkles")),
        .calm: DisplayRepresentation(title: "Calm", image: .init(systemName: "leaf")),
        .neutral: DisplayRepresentation(title: "Neutral", image: .init(systemName: "minus")),
        .tired: DisplayRepresentation(title: "Tired", image: .init(systemName: "moon.zzz")),
        .stressed: DisplayRepresentation(title: "Stressed", image: .init(systemName: "bolt")),
        .sad: DisplayRepresentation(title: "Sad", image: .init(systemName: "cloud.rain")),
        .frustrated: DisplayRepresentation(title: "Frustrated", image: .init(systemName: "flame")),
    ]

    public var mood: Mood { Mood(rawValue: rawValue) ?? .neutral }
    public init(_ mood: Mood) { self = MoodAppEnum(rawValue: mood.rawValue) ?? .neutral }
}

public enum IntensityAppEnum: Int, AppEnum {
    case slight = 1, moderate = 2, strong = 3

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intensity")
    public static let caseDisplayRepresentations: [IntensityAppEnum: DisplayRepresentation] = [
        .slight: "A little", .moderate: "Moderately", .strong: "Very",
    ]

    public var intensity: MoodIntensity { MoodIntensity(rawValue: rawValue) ?? .moderate }
}
