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

    private static let cacheKey = "petWords.cache.v2"
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
            options.maximumResponseTokens = 48
            options.temperature = 0.3
            do {
                let response = try await session.respond(to: prompt(kind: kind, entries: entries), options: options)
                if let text = sanitize(response.content, moods: Set(entries.map { $0.mood.lowercased() })) {
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
        let period = kind == .week ? "week" : "day"
        return """
        You summarise someone's mood journal for their \(period) in one short, plain sentence.

        Rules:
        - One sentence, at most 16 words, addressed to them as "you".
        - Use only what is in the entries: the moods, the time of day, what it was about, and what they wrote. \
        Never add events, people, feelings, places or details that are not in the entries.
        - Plain, everyday words. No imagery, metaphors, poetry, weather, nature, light, colours or sounds.
        - Describe; never advise. Never use should, try, need, must, better, worse, improve or fix.
        - No numbers, counts, streaks, averages, scores or goals. No medical or clinical words.
        - If an entry mentions harm or crisis, write only: I'm here with you.
        - No emoji, quotation marks, lists or preamble.

        Good:
        - A tired morning, then happier by the evening after time with friends.
        - Mostly calm this week, with a stressful Tuesday about work.
        - Frustrated about money today, and a little calmer tonight.

        Bad (never write like this):
        - The sky held soft light as joy slipped in like a quiet wave.
        - Your laughter warmed the quiet hours.
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

    /// The model's sentence, or nil if it broke a rule the instructions cannot fully enforce:
    /// advice or numbers, poetry and imagery, or nothing grounded in the moods actually logged.
    static func sanitize(_ raw: String, moods: Set<String> = []) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "“", with: "").replacingOccurrences(of: "”", with: "")
        if let firstLine = text.split(separator: "\n").first { text = String(firstLine) }
        let words = text.split(separator: " ")
        guard words.count >= 3, words.count <= 20 else { return nil }
        let lowered = text.lowercased()
        let banned = ["should", "you need", "try to", "must", "improve", "diagnos", "disorder", "depress", "anxiety disorder", "streak", "average", "score", "%", "therapy"]
        if banned.contains(where: { lowered.contains($0) }) { return nil }
        // Poetry and imagery: the journal is about moods, not skies.
        let imagery = ["sky", "sun", "moon", "star", "light", "glow", "shine", "shining", "wave", "tide", "ocean", "sea", "breeze", "wind",
                       "whisper", "echo", "bloom", "blossom", "petal", "ice", "snow", "rain", "storm", "cloud", "dawn", "dusk", "golden", "velvet",
                       "melody", "song", "dance", "danced", "heartbeat", "soul", "warmed", "painted", "slipped", "drifted", "hours", "stars", "waves", "skies"]
        // Whole words (so "Sunday" isn't "sun"); a few stems catch their forms.
        let tokens = lowered.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        let stems = ["sparkl", "shimmer", "glimmer"]
        if tokens.contains(where: { t in imagery.contains(t) || stems.contains(where: { t.hasPrefix($0) }) }) { return nil }
        // Grounded: it names at least one of the moods actually logged (or says it is here).
        if !moods.isEmpty, !moods.contains(where: { lowered.contains($0) }), !lowered.contains("i'm here") { return nil }
        if text.rangeOfCharacter(from: .decimalDigits) != nil { return nil }
        if !text.hasSuffix(".") && !text.hasSuffix("!") { text += "." }
        return text
    }
}
