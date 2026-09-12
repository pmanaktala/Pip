import Foundation
import OSLog
import SwiftData

/// Builds the app's `ModelContainer`.
///
/// Local-first: the store lives in the App Group so the widget extension can log moods too.
/// CloudKit mirroring is attempted first; if the container cannot be created that way
/// (no iCloud entitlement in CI, restricted environments) it falls back to local-only,
/// and finally to an in-memory store so the app never fails to launch.
public enum PipModelContainer {
    public static let appGroupID = "group.com.pmanaktala.Pip"
    public static let cloudKitContainerID = "iCloud.com.pmanaktala.Pip"

    private static let log = Logger(subsystem: "com.pmanaktala.Pip", category: "Persistence")

    public static let schema = Schema([MoodEntry.self, PetProfile.self])

    /// The shared container. Created once per process.
    public static let shared: ModelContainer = make()

    public private(set) static var isCloudKitEnabled = false

    public static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory
        return base.appending(path: "Pip.store")
    }

    public static func make(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: [config])
        }

        let url = storeURL
        let cloud = ModelConfiguration("Pip", schema: schema, url: url, cloudKitDatabase: .private(cloudKitContainerID))
        if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
            isCloudKitEnabled = true
            log.info("Model container ready with CloudKit mirroring")
            return container
        }

        let local = ModelConfiguration("Pip", schema: schema, url: url, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: [local]) {
            log.warning("CloudKit configuration unavailable; using local-only store")
            return container
        }

        log.error("Persistent store unavailable; falling back to in-memory store")
        return make(inMemory: true)
    }
}
