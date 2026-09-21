import Foundation
import Observation
import UserNotifications

/// Rare, optional, contextual notifications. Never "you haven't logged today".
///
/// Scheduling is deterministic per day so repeated foregrounding doesn't reshuffle plans:
/// at most one notification per day, drawn from the categories the user enabled.
@MainActor
@Observable
public final class NotificationService {
    public enum Category: String, CaseIterable, Sendable {
        case company, sleepy, moments

        var identifierPrefix: String { "pip.\(rawValue)" }
    }

    public private(set) var isAuthorized = false
    private let center = UNUserNotificationCenter.current()
    private let router = Router()

    /// Called with the deep link for a tapped notification (`pip://sit` or `pip://home`).
    public var onOpen: ((URL) -> Void)? {
        get { router.onOpen }
        set { router.onOpen = newValue }
    }

    public init() {
        center.delegate = router
        Task { await refreshAuthorization() }
    }

    /// Notification taps route like Live Activity taps: company and wind-down open Sit With Pet,
    /// little moments open the Pet tab. Notifications also show while the app is in front so the
    /// pet can be heard, quietly, without a sound.
    private final class Router: NSObject, UNUserNotificationCenterDelegate {
        var onOpen: ((URL) -> Void)?

        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
            guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
                  let raw = response.notification.request.content.userInfo["url"] as? String,
                  let url = URL(string: raw) else { return }
            await MainActor.run { onOpen?(url) }
        }

        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
            [.banner]
        }
    }

    public func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    public func requestAuthorization() async -> Bool {
        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            isAuthorized = false
        }
        return isAuthorized
    }

    /// Re-plans the next few days. Call on foreground and when preferences change.
    public func reschedule(preferences: Preferences, identity: PetIdentity, calendar: Calendar = .current, now: Date = .now) async {
        let pendingIDs = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("pip.") }
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)

        guard isAuthorized, preferences.anyNotificationsEnabled else { return }

        var enabled: [Category] = []
        if preferences.notificationsCompany { enabled.append(.company) }
        if preferences.notificationsSleepy { enabled.append(.sleepy) }
        if preferences.notificationsMoments { enabled.append(.moments) }

        for offset in 0..<4 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else { continue }
            guard let plan = Self.plan(for: day, enabled: enabled, calendar: calendar) else { continue }
            guard plan.date > now.addingTimeInterval(15 * 60) else { continue }

            let content = UNMutableNotificationContent()
            content.body = plan.body(identity.name)
            content.sound = nil
            content.interruptionLevel = .passive
            content.threadIdentifier = plan.category.rawValue
            content.userInfo = ["url": plan.category == .moments ? "pip://home" : "pip://sit"]

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: plan.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "\(plan.category.identifierPrefix).\(offset)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    struct Plan {
        var category: Category
        var date: Date
        var body: (String) -> String
    }

    /// Roughly every other day, one quiet note. Deterministic for a given day.
    static func plan(for day: Date, enabled: [Category], calendar: Calendar) -> Plan? {
        guard !enabled.isEmpty else { return nil }
        let seed = Double(calendar.ordinality(of: .day, in: .era, for: day) ?? 0)
        let roll = PetAnimator.hash01(seed)
        guard roll < 0.45 else { return nil } // most days: nothing
        let category = enabled[Int(PetAnimator.hash01(seed + 7) * Double(enabled.count)) % enabled.count]
        let variant = Int(PetAnimator.hash01(seed + 13) * 3)

        switch category {
        case .company:
            let hour = 14 + Int(PetAnimator.hash01(seed + 3) * 5) // 14…18
            let minute = Int(PetAnimator.hash01(seed + 5) * 60)
            let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
            let bodies: [(String) -> String] = [
                { "\($0) wants some company." },
                { "\($0) is hanging out." },
                { "\($0) saved you a spot." },
            ]
            return Plan(category: .company, date: date, body: bodies[variant])
        case .sleepy:
            let minute = 15 + Int(PetAnimator.hash01(seed + 5) * 45)
            let date = calendar.date(bySettingHour: 21, minute: minute, second: 0, of: day)!
            let bodies: [(String) -> String] = [
                { "\($0) looks sleepy." },
                { "\($0) is winding down for the night." },
                { "\($0) found a comfortable spot." },
            ]
            return Plan(category: .sleepy, date: date, body: bodies[variant])
        case .moments:
            let hour = 9 + Int(PetAnimator.hash01(seed + 3) * 10) // 9…18
            let minute = Int(PetAnimator.hash01(seed + 5) * 60)
            let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
            let bodies: [(String) -> String] = [
                { "\($0) is watching something out the window." },
                { "\($0) is doing absolutely nothing, very well." },
                { "\($0) stretched, then sat back down." },
            ]
            return Plan(category: .moments, date: date, body: bodies[variant])
        }
    }
}
