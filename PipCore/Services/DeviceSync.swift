#if os(iOS) || os(watchOS)
import Foundation
import OSLog
import SwiftData
import WatchConnectivity

/// Direct iPhone ↔ Apple Watch sync over WatchConnectivity, so a mood logged on the wrist is on
/// the phone within seconds (and vice versa) without waiting for iCloud. CloudKit mirroring
/// remains the long-term store; this is the fast path. Everything is merged by entry ID, so a
/// record arriving twice (once here, once via iCloud) is applied once.
///
/// Three kinds of message: a logged or updated entry, a deleted entry, and the pet itself
/// (species, name, personality). Entries and deletions use `transferUserInfo`, which queues and
/// delivers even when the counterpart app is not running; the pet rides the application
/// context, which always reflects the latest value.
@MainActor
public final class DeviceSync: NSObject {
    public static let shared = DeviceSync()

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private var container: ModelContainer?
    private var sharedStore: SharedStateStore = .shared
    /// Called after a remote change has been merged, so the UI can refresh.
    public var onRemoteChange: (@MainActor () -> Void)?
    /// Called when the other device's pet did something (a boop, petting, a wave), so this
    /// device's pet can do it too while both are on screen.
    public var onPetEvent: (@MainActor (PetEvent) -> Void)?
    /// Transfers requested before the session finished activating; flushed on activation.
    private var pending: [[String: Any]] = []
    private var pendingIdentity: PetIdentity?
    private static let log = Logger(subsystem: "com.pmanaktala.Pip", category: "DeviceSync")

    /// Starts the session against the store remote changes should be merged into.
    public func start(container: ModelContainer, sharedStore: SharedStateStore = .shared) {
        self.container = container
        self.sharedStore = sharedStore
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: Sending

    public func send(_ entry: MoodEntry) {
        let info: [String: Any] = ["entry": Payload(entry).dictionary]
        transfer(info)
        // The latest entry also rides the application context: it is always delivered, last
        // value wins, and it survives the counterpart app being closed.
        latestForContext = info["entry"] as? [String: Any]
        pushContext()
    }

    /// A pet event is only worth anything live: sent as a message when the other app is up,
    /// dropped otherwise (never queued — a boop from an hour ago means nothing).
    public func send(_ event: PetEvent) {
        guard let session, session.activationState == .activated, session.isReachable,
              let data = try? JSONEncoder().encode(event) else { return }
        session.sendMessage(["petEvent": data], replyHandler: nil, errorHandler: nil)
    }

    public func sendDeletion(of id: UUID) {
        transfer(["deleted": id.uuidString])
    }

    public func send(identity: PetIdentity) {
        guard let session else { return }
        guard session.activationState == .activated else { pendingIdentity = identity; return }
        identityForContext = ["species": identity.species.rawValue, "name": identity.name, "personality": identity.personality.rawValue]
        pushContext()
    }

    private var identityForContext: [String: String]?
    private var latestForContext: [String: Any]?

    private func pushContext() {
        guard let session, session.activationState == .activated else { return }
        var context: [String: Any] = [:]
        if let identityForContext { context["pet"] = identityForContext }
        if let latestForContext { context["latest"] = latestForContext }
        guard !context.isEmpty else { return }
        do { try session.updateApplicationContext(context) } catch { Self.log.error("context: \(error.localizedDescription, privacy: .public)") }
    }

    /// Queues while the session is still activating (a log a second after launch is common on
    /// the watch); WatchConnectivity itself queues once activated, even if the other app is closed.
    private func transfer(_ userInfo: [String: Any]) {
        guard let session else { return }
        guard session.activationState == .activated else { pending.append(userInfo); Self.log.info("queued transfer until activation"); return }
        if session.isReachable {
            // Counterpart app is up: deliver now; fall back to the queue if the message fails.
            session.sendMessage(userInfo, replyHandler: nil) { _ in session.transferUserInfo(userInfo) }
            Self.log.info("sent \(userInfo.keys.joined(separator: ","), privacy: .public)")
        } else {
            session.transferUserInfo(userInfo)
            Self.log.info("transferred \(userInfo.keys.joined(separator: ","), privacy: .public)")
        }
    }

    private func flushPending() {
        guard let session, session.activationState == .activated else { return }
        for info in pending { session.transferUserInfo(info) }
        pending.removeAll()
        if let identity = pendingIdentity { pendingIdentity = nil; send(identity: identity) }
    }

    // MARK: Merging

    private func merge(_ userInfo: [String: Any]) {
        if let data = userInfo["petEvent"] as? Data, let event = try? JSONDecoder().decode(PetEvent.self, from: data) {
            onPetEvent?(event)
            return
        }
        Self.log.info("received \(userInfo.keys.joined(separator: ","), privacy: .public)")
        guard let container else { Self.log.error("no container to merge into"); return }
        let context = container.mainContext
        var changed = false
        if let raw = userInfo["entry"] as? [String: Any], let payload = Payload(raw) {
            if let existing = PipQueries.entry(id: payload.id, in: context) {
                // Last write wins, by the sender's modification time.
                if payload.modifiedAt > existing.modifiedAt {
                    existing.moodRaw = payload.mood
                    existing.intensityRaw = payload.intensity
                    existing.contextsRaw = payload.contexts
                    existing.note = payload.note
                    existing.timestamp = payload.timestamp
                    existing.modifiedAt = payload.modifiedAt
                    changed = true
                }
            } else {
                let entry = MoodEntry(mood: Mood(rawValue: payload.mood) ?? .neutral,
                                      intensity: MoodIntensity(rawValue: payload.intensity) ?? .moderate,
                                      contexts: payload.contexts.split(separator: ",").compactMap { MoodContext(rawValue: String($0)) },
                                      note: payload.note, timestamp: payload.timestamp)
                entry.id = payload.id
                entry.createdAt = payload.createdAt
                entry.modifiedAt = payload.modifiedAt
                context.insert(entry)
                changed = true
            }
        }
        if let raw = userInfo["deleted"] as? String, let id = UUID(uuidString: raw), let existing = PipQueries.entry(id: id, in: context) {
            context.delete(existing)
            changed = true
        }
        guard changed else { Self.log.info("nothing to merge"); return }
        do { try context.save() } catch { Self.log.error("save failed: \(error.localizedDescription, privacy: .public)") }
        sharedStore.save(PipQueries.buildSnapshot(in: context))
        Self.log.info("merged; notifying")
        onRemoteChange?()
    }

    private func mergeContext(_ context: [String: Any]) {
        if let latest = context["latest"] as? [String: Any] { merge(["entry": latest]) }
        mergePet(context)
    }

    private func mergePet(_ context: [String: Any]) {
        guard let container, let raw = context["pet"] as? [String: String],
              let species = raw["species"].flatMap(PetSpecies.init(rawValue:)), let name = raw["name"] else { return }
        let modelContext = container.mainContext
        guard let profile = PipQueries.petProfile(in: modelContext) else { return }
        let identity = PetIdentity(species: species, name: name, personality: raw["personality"].flatMap(PetPersonality.init(rawValue:)) ?? species.defaultPersonality)
        guard profile.identity != identity else { return }
        profile.identity = identity
        try? modelContext.save()
        sharedStore.save(PipQueries.buildSnapshot(in: modelContext))
        onRemoteChange?()
    }

    /// The wire form of an entry. Dates travel as seconds so both platforms agree.
    struct Payload {
        var id: UUID
        var timestamp: Date
        var mood: String
        var intensity: Int
        var contexts: String
        var note: String?
        var createdAt: Date
        var modifiedAt: Date

        init(_ e: MoodEntry) {
            id = e.id; timestamp = e.timestamp; mood = e.moodRaw; intensity = e.intensityRaw
            contexts = e.contextsRaw; note = e.note; createdAt = e.createdAt; modifiedAt = e.modifiedAt
        }

        init?(_ d: [String: Any]) {
            guard let idRaw = d["id"] as? String, let id = UUID(uuidString: idRaw),
                  let t = d["timestamp"] as? Double, let mood = d["mood"] as? String, let intensity = d["intensity"] as? Int else { return nil }
            self.id = id
            timestamp = Date(timeIntervalSince1970: t)
            self.mood = mood
            self.intensity = intensity
            contexts = d["contexts"] as? String ?? ""
            note = d["note"] as? String
            createdAt = Date(timeIntervalSince1970: d["createdAt"] as? Double ?? t)
            modifiedAt = Date(timeIntervalSince1970: d["modifiedAt"] as? Double ?? t)
        }

        var dictionary: [String: Any] {
            var d: [String: Any] = ["id": id.uuidString, "timestamp": timestamp.timeIntervalSince1970, "mood": mood, "intensity": intensity,
                                    "contexts": contexts, "createdAt": createdAt.timeIntervalSince1970, "modifiedAt": modifiedAt.timeIntervalSince1970]
            if let note { d["note"] = note }
            return d
        }
    }
}

extension DeviceSync: WCSessionDelegate {
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Self.log.info("activation: \(activationState.rawValue) error: \(error?.localizedDescription ?? "none", privacy: .public)")
        // Once both ends are up, push the pet so a fresh watch shows the right companion at once.
        Task { @MainActor in
            guard activationState == .activated else { return }
            self.flushPending()
            if let container = self.container, let identity = PipQueries.petProfile(in: container.mainContext, createIfMissing: false)?.identity {
                self.send(identity: identity)
            }
            let received = session.receivedApplicationContext
            if !received.isEmpty { self.mergeContext(received) }
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.merge(userInfo) }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.merge(message) }
    }

    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.mergeContext(applicationContext) }
    }

    nonisolated public func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: (any Error)?) {
        if let error { Self.log.error("transfer failed: \(error.localizedDescription, privacy: .public)") }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {}

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated public func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}

/// Registers with `MoodLogger` so every log on this device is offered to the other one.
public struct DeviceSyncSideEffect: MoodLogSideEffect {
    public init() {}
    @MainActor public func moodLogged(_ entry: MoodEntry, identity: PetIdentity, snapshot: PetSnapshot) {
        DeviceSync.shared.send(entry)
    }
}
#endif
