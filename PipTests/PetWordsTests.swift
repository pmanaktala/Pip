import Foundation
import Testing
@testable import Pip

/// The on-device model can't run in the simulator; what can be tested is everything around it —
/// the guardrails on its output, the shape of what it is shown, and the cache.
struct PetWordsTests {
    @Test func sanitizerKeepsAWarmSentence() {
        #expect(PetWords.sanitize("Pebble noticed the week began quietly and brightened by Sunday") == "Pebble noticed the week began quietly and brightened by Sunday.")
        #expect(PetWords.sanitize("  “A calm week, mostly.”  ") == "A calm week, mostly.")
    }

    @Test func sanitizerRefusesAdviceNumbersAndClinicalLanguage() {
        #expect(PetWords.sanitize("You should try to sleep more this week.") == nil)
        #expect(PetWords.sanitize("You logged 5 moods, a 3-day streak!") == nil)
        #expect(PetWords.sanitize("This looks like depression.") == nil)
        #expect(PetWords.sanitize("Ok.") == nil, "too short to be a sentence")
        #expect(PetWords.sanitize(String(repeating: "word ", count: 40)) == nil, "too long")
    }

    @Test func promptShowsOnlyWhatTheModelNeeds() {
        let prompt = PetWords.prompt(kind: .day, entries: [
            PetWords.Entry(dayName: "Today", partOfDay: "morning", mood: "stressed", intensity: "very", contexts: ["work"], note: "deadline"),
        ])
        #expect(prompt.contains("Today morning: very stressed (about: work)"))
        #expect(prompt.contains("deadline"))
        #expect(!prompt.contains("UUID"))
    }

    @Test func instructionsCarryTheGuardrails() {
        let text = PetWords.instructions(petName: "Pebble", species: "penguin", kind: .week)
        for rule in ["Never advise", "streaks", "diagnose", "one sentence", "crisis"] {
            #expect(text.localizedCaseInsensitiveContains(rule), "missing rule: \(rule)")
        }
    }

    @Test func cacheRoundTrips() throws {
        let suite = "PetWordsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(PetWords.cached("k", defaults: defaults) == nil)
        PetWords.store("A gentle day.", for: "k", defaults: defaults)
        #expect(PetWords.cached("k", defaults: defaults) == "A gentle day.")
        PetWords.clearCache(defaults: defaults)
        #expect(PetWords.cached("k", defaults: defaults) == nil)
    }
}
