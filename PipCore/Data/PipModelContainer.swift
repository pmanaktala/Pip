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

    public enum StorageMode {
        case iCloud, local, unavailable
    }

    /// The shared container and its actual storage mode. Created once per process.
    private static let sharedSetup = makePersistent()
    public static var shared: ModelContainer { sharedSetup.container }
    public static var storageMode: StorageMode { sharedSetup.mode }
    private static let unavailableConfigurationName = "PipUnavailable"

    static func isUnavailable(_ container: ModelContainer) -> Bool {
        container.configurations.contains { $0.name == unavailableConfigurationName && $0.isStoredInMemoryOnly }
    }

    public static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory
        return base.appending(path: "Pip.store")
    }

    public static func make(inMemory: Bool = false) -> ModelContainer {
        inMemory ? makeInMemory() : makePersistent().container
    }

    private static func makeInMemory(name: String? = nil) -> ModelContainer {
        let config = ModelConfiguration(name, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    static func makePersistent(at url: URL = storeURL) -> (container: ModelContainer, mode: StorageMode) {
        let cloud = ModelConfiguration("Pip", schema: schema, url: url, cloudKitDatabase: .private(cloudKitContainerID))
        if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
            log.info("Model container ready with CloudKit mirroring")
            return (container, .iCloud)
        }

        let local = ModelConfiguration("Pip", schema: schema, url: url, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: [local]) {
            log.warning("CloudKit configuration unavailable; using local-only store")
            return (container, .local)
        }

        log.error("Persistent store unavailable; falling back to in-memory store")
        return (makeInMemory(name: unavailableConfigurationName), .unavailable)
    }
}
