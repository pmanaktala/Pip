import Foundation
import Observation

/// User preferences. Backed by the App Group so extensions can honour them.
/// These are deliberately *not* synced through CloudKit: permissions are per device.
@MainActor
@Observable
public final class Preferences {
    public static let shared = Preferences()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = SharedStateStore.shared.defaultsSuite) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        healthSyncEnabled = defaults.bool(forKey: Keys.health)
        healthSyncEnabledAt = defaults.object(forKey: Keys.healthSince) as? Date
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        soundEnabled = defaults.bool(forKey: Keys.sound)
        liveActivitiesEnabled = defaults.object(forKey: Keys.liveActivities) as? Bool ?? true
        petMomentsEnabled = defaults.object(forKey: Keys.petMoments) as? Bool ?? true
        notificationsCompany = defaults.bool(forKey: Keys.notifCompany)
        notificationsSleepy = defaults.bool(forKey: Keys.notifSleepy)
        notificationsMoments = defaults.bool(forKey: Keys.notifMoments)
        petWordsEnabled = defaults.object(forKey: Keys.petWords) as? Bool ?? true
    }

    private enum Keys {
        static let onboarding = "pref.onboardingComplete"
        static let health = "pref.healthSync"
        static let healthSince = "pref.healthSyncSince"
        static let haptics = "pref.haptics"
        static let sound = "pref.sound"
        static let liveActivities = "pref.liveActivities"
        static let petMoments = "pref.petMoments"
        static let notifCompany = "pref.notif.company"
        static let notifSleepy = "pref.notif.sleepy"
        static let notifMoments = "pref.notif.moments"
        static let petWords = "pref.petWords"
    }

    public var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) } }

    /// Apple Health State of Mind sync. Only entries created after `healthSyncEnabledAt` are written.
    public var healthSyncEnabled: Bool {
        didSet {
            defaults.set(healthSyncEnabled, forKey: Keys.health)
            if healthSyncEnabled, healthSyncEnabledAt == nil { healthSyncEnabledAt = .now }
        }
    }
    public var healthSyncEnabledAt: Date? { didSet { defaults.set(healthSyncEnabledAt, forKey: Keys.healthSince) } }

    public var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) } }
    public var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.sound) } }

    /// Mood-change Live Activities.
    public var liveActivitiesEnabled: Bool { didSet { defaults.set(liveActivitiesEnabled, forKey: Keys.liveActivities) } }
    /// Occasional pet moments (come sit with me, wind-down, random).
    public var petMomentsEnabled: Bool { didSet { defaults.set(petMomentsEnabled, forKey: Keys.petMoments) } }

    public var notificationsCompany: Bool { didSet { defaults.set(notificationsCompany, forKey: Keys.notifCompany) } }
    public var notificationsSleepy: Bool { didSet { defaults.set(notificationsSleepy, forKey: Keys.notifSleepy) } }
    public var notificationsMoments: Bool { didSet { defaults.set(notificationsMoments, forKey: Keys.notifMoments) } }

    public var anyNotificationsEnabled: Bool { notificationsCompany || notificationsSleepy || notificationsMoments }

    /// On-device Apple Intelligence writes the History sentences in the pet's voice. Default on;
    /// silently inert where Apple Intelligence is unavailable.
    public var petWordsEnabled: Bool { didSet { defaults.set(petWordsEnabled, forKey: Keys.petWords) } }

    /// Resets everything to first-launch defaults (used by Delete All App Data).
    public func reset() {
        hasCompletedOnboarding = false
        healthSyncEnabled = false
        healthSyncEnabledAt = nil
        hapticsEnabled = true
        soundEnabled = false
        liveActivitiesEnabled = true
        petMomentsEnabled = true
        notificationsCompany = false
        notificationsSleepy = false
        notificationsMoments = false
        petWordsEnabled = true
    }
}
