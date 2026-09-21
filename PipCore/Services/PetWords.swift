import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The pet's words: one warm sentence about a day or a week, written on the device by Apple
/// Intelligence's system model from the actual entries (moods, why, notes). Nothing leaves the
/// device — only the on-device model is ever used, never Private Cloud Compute — and every
/// sentence is cached so a screen never waits on generation. When the model is unavailable, the
/// user has turned it off, or the model declines, the deterministic phrase is used instead.
///
/// Guardrails matter more than eloquence here: the instructions forbid advice, judgement,
/// numbers, streaks, diagnosis and "should"; the output is capped and checked before use.
public enum PetWords {
    public enum Kind: String, Sendable { case week, day }

    /// Whether the on-device model can write right now (device eligible, Apple Intelligence on, model ready).
    public static var isAvailable: Bool {
        #if canImport(FoundationModels) && os(iOS)
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Why it is unavailable, for Settings copy. `nil` when available or when the framework is absent.
    public static var unavailableReason: String? {
        #if canImport(FoundationModels) && os(iOS)
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return nil
            case .unavailable(.deviceNotEligible): return "This iPhone doesn’t support Apple Intelligence."
            case .unavailable(.appleIntelligenceNotEnabled): return "Turn on Apple Intelligence in Settings to let \(PetIdentity.placeholder.name) write these."
            case .unavailable(.modelNotReady): return "Apple Intelligence is still getting ready."
            case .unavailable: return "Apple Intelligence isn’t available right now."
            }
        }
        #endif
        return nil
    }

    // MARK: Cache

    private static let cacheKey = "petWords.cache.v1"
    private static let cacheLimit = 120

    /// A cached sentence for `key`, if one has been written.
    public static func cached(_ key: String, defaults: UserDefaults = SharedStateStore.shared.defaultsSuite) -> String? {
        (defaults.dictionary(forKey: cacheKey) as? [String: String])?[key]
    }

    static func store(_ text: String, for key: String, defaults: UserDefaults = SharedStateStore.shared.defaultsSuite) {
        var cache = defaults.dictionary(forKey: cacheKey) as? [String: String] ?? [:]
        if cache.count >= cacheLimit, let victim = cache.keys.sorted().first { cache.removeValue(forKey: victim) }
        cache[key] = text
        defaults.set(cache, forKey: cacheKey)
    }

    public static func clearCache(defaults: UserDefaults = SharedStateStore.shared.defaultsSuite) {
        defaults.removeObject(forKey: cacheKey)
    }

    // MARK: Writing

    /// One line describing `stamps` for the pet named `petName`. Returns the cached or freshly
    /// written sentence, or `nil` when the pet has nothing to say (unavailable, declined, unsafe).
    /// `key` must change whenever the entries change so a stale sentence is never shown.
    public static func line(kind: Kind, key: String, petName: String, species: String, entries: [Entry]) async -> String? {
        if let hit = cached(key) { return hit }
        guard isAvailable, !entries.isEmpty else { return nil }
        #if canImport(FoundationModels) && os(iOS)
        if #available(iOS 26, *) {
            let session = LanguageModelSession(instructions: instructions(petName: petName, species: species, kind: kind))
            var options = GenerationOptions()
            options.maximumResponseTokens = 60
            options.temperature = 0.6
            do {
                let response = try await session.respond(to: prompt(kind: kind, entries: entries), options: options)
                if let text = sanitize(response.content) {
                    store(text, for: key)
                    return text
                }
            } catch {
                // The model declined or errored; the deterministic phrase stands in. Nothing to log.
            }
        }
        #endif
        return nil
    }

    /// One entry as the model sees it: no identifiers, no timestamps beyond the part of day.
    public struct Entry: Sendable {
        public var dayName: String
        public var partOfDay: String
        public var mood: String
        public var intensity: String
        public var contexts: [String]
        public var note: String?

        public init(dayName: String, partOfDay: String, mood: String, intensity: String, contexts: [String], note: String?) {
            self.dayName = dayName
            self.partOfDay = partOfDay
            self.mood = mood
            self.intensity = intensity
            self.contexts = contexts
            self.note = note
        }
    }

    static func instructions(petName: String, species: String, kind: Kind) -> String {
        """
        You are \(petName), a small \(species) who keeps someone company in a mood journal. \
        Write exactly one sentence, at most 22 words, describing their \(kind == .week ? "week" : "day") \
        from the entries provided. Speak as \(petName), warm and specific, in plain English. \
        Describe; never advise. Never use the words should, try, need, must, better, worse, improve, or fix. \
        Never mention numbers, counts, streaks, averages, scores, progress, or goals. \
        Never diagnose or use medical or clinical language. \
        If an entry mentions harm or crisis, respond only with gentle acknowledgment that you are here. \
        No emoji, no quotation marks, no lists, no preamble. Output the sentence only.
        """
    }

    static func prompt(kind: Kind, entries: [Entry]) -> String {
        var lines: [String] = []
        for e in entries {
            var s = "\(e.dayName) \(e.partOfDay): \(e.intensity) \(e.mood)"
            if !e.contexts.isEmpty { s += " (about: \(e.contexts.joined(separator: ", ")))" }
            if let note = e.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                s += " — they wrote: “\(String(note.prefix(160)))”"
            }
            lines.append(s)
        }
        return "Entries this \(kind == .week ? "week" : "day"):\n" + lines.joined(separator: "\n")
    }

    /// The model's sentence, or nil if it broke a rule the instructions cannot fully enforce.
    static func sanitize(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "“", with: "").replacingOccurrences(of: "”", with: "")
        if let firstLine = text.split(separator: "\n").first { text = String(firstLine) }
        let words = text.split(separator: " ")
        guard words.count >= 3, words.count <= 26 else { return nil }
        let lowered = text.lowercased()
        let banned = ["should", "you need", "try to", "must", "improve", "diagnos", "disorder", "depress", "anxiety disorder", "streak", "average", "score", "%", "therapy"]
        if banned.contains(where: { lowered.contains($0) }) { return nil }
        if text.rangeOfCharacter(from: .decimalDigits) != nil { return nil }
        if !text.hasSuffix(".") && !text.hasSuffix("!") { text += "." }
        return text
    }
}
