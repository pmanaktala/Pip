import AVFoundation
import Foundation
import Network
import UIKit

/// Notices the few things the phone tells any app without asking — whether something is playing,
/// whether headphones are in, the battery, the time zone, whether there's a network — and turns
/// them into `PetContext` for the pet. Only while the app is open; nothing leaves the device and
/// nothing is kept except two timestamps (last visit, last time zone change) in local defaults.
@MainActor
final class PetContextMonitor {
    private(set) var context = PetContext()
    var onChange: ((PetContext) -> Void)?

    private let defaults: UserDefaults
    private let path = NWPathMonitor()
    private var offline = false
    private var observers: [NSObjectProtocol] = []
    private var missedYouUntil = Date.distantPast

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        UIDevice.current.isBatteryMonitoringEnabled = true
        path.pathUpdateHandler = { [weak self] update in
            let off = update.status != .satisfied
            Task { @MainActor in
                self?.offline = off
                self?.refresh()
            }
        }
        path.start(queue: DispatchQueue(label: "com.pmanaktala.Pip.path"))
        let center = NotificationCenter.default
        let names: [Notification.Name] = [AVAudioSession.routeChangeNotification, AVAudioSession.silenceSecondaryAudioHintNotification,
                                          UIDevice.batteryStateDidChangeNotification, UIDevice.batteryLevelDidChangeNotification,
                                          .NSProcessInfoPowerStateDidChange, .NSSystemTimeZoneDidChange]
        observers = names.map { center.addObserver(forName: $0, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refresh() } } }
    }

    /// Call when the app becomes active (it also runs on every change it hears about).
    func didBecomeActive(now: Date = .now) {
        let last = defaults.object(forKey: Keys.lastVisit) as? Date
        if let last, now.timeIntervalSince(last) > 3 * 86400 { missedYouUntil = now.addingTimeInterval(600) }
        defaults.set(now, forKey: Keys.lastVisit)
        refresh(now: now)
    }

    func refresh(now: Date = .now) {
        var c = PetContext()
        let session = AVAudioSession.sharedInstance()
        c.audioPlaying = session.isOtherAudioPlaying
        let headphonePorts: Set<AVAudioSession.Port> = [.headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP]
        c.headphones = session.currentRoute.outputs.contains { headphonePorts.contains($0.portType) }
        let battery = UIDevice.current
        c.charging = battery.batteryState == .charging || battery.batteryState == .full
        c.lowBattery = !c.charging && (ProcessInfo.processInfo.isLowPowerModeEnabled || (battery.batteryLevel >= 0 && battery.batteryLevel < 0.15))
        c.travelling = travelling(now: now)
        c.offline = offline
        c.missedYou = now < missedYouUntil
        #if DEBUG
        // Screenshot automation: PIP_CONTEXT=travelling,offline,charging,lowBattery,headphones,music,missedYou
        if let forced = ProcessInfo.processInfo.environment["PIP_CONTEXT"] {
            let set = Set(forced.split(separator: ","))
            if set.contains("travelling") { c.travelling = true }
            if set.contains("offline") { c.offline = true }
            if set.contains("charging") { c.charging = true }
            if set.contains("lowBattery") { c.lowBattery = true }
            if set.contains("headphones") { c.headphones = true }
            if set.contains("music") { c.audioPlaying = true }
            if set.contains("missedYou") { c.missedYou = true }
        }
        #endif
        guard c != context else { return }
        context = c
        onChange?(c)
    }

    /// Somewhere new: the time zone changed within the last day. The first visit only records it.
    private func travelling(now: Date) -> Bool {
        let zone = TimeZone.current.identifier
        let known = defaults.string(forKey: Keys.timeZone)
        if known == nil {
            defaults.set(zone, forKey: Keys.timeZone)
        } else if known != zone {
            defaults.set(zone, forKey: Keys.timeZone)
            defaults.set(now, forKey: Keys.zoneChangedAt)
        }
        guard let changed = defaults.object(forKey: Keys.zoneChangedAt) as? Date else { return false }
        return now.timeIntervalSince(changed) < 86400
    }

    private enum Keys {
        static let lastVisit = "context.lastVisit"
        static let timeZone = "context.timeZone"
        static let zoneChangedAt = "context.zoneChangedAt"
    }
}
