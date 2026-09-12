import AppIntents

struct PipShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMoodIntent(),
            phrases: [
                "Log my mood in \(.applicationName)",
                "Tell \(.applicationName) how I feel",
                "I'm feeling \(\.$mood) in \(.applicationName)",
            ],
            shortTitle: "Log Mood",
            systemImageName: "face.smiling")
        AppShortcut(
            intent: OpenPetIntent(),
            phrases: ["Check on my pet in \(.applicationName)", "Open my pet in \(.applicationName)"],
            shortTitle: "See Your Pet",
            systemImageName: "pawprint")
    }
}
