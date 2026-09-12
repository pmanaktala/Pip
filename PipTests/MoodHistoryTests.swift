import Foundation
import Testing
@testable import Pip

struct MoodHistoryTests {
    private func stamp(_ mood: Mood, hour: Int, day: Date = .now) -> MoodStamp {
        let cal = Calendar.current
        let t = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return MoodStamp(mood: mood, intensity: .moderate, time: t)
    }

    @Test func dominantPrefersMostFrequentThenLatest() {
        let s = [stamp(.happy, hour: 9), stamp(.sad, hour: 12), stamp(.happy, hour: 15)]
        #expect(MoodHistory.dominant(s)?.mood == .happy)
        let tie = [stamp(.happy, hour: 9), stamp(.sad, hour: 12)]
        #expect(MoodHistory.dominant(tie)?.mood == .sad)
        #expect(MoodHistory.dominant([]) == nil)
    }

    @Test func recapBuildsScenesPerDayPart() {
        let s = [stamp(.tired, hour: 8), stamp(.stressed, hour: 14), stamp(.happy, hour: 20)]
        let recap = MoodHistory.recap(for: .now, stamps: s, petName: "Mochi")
        #expect(recap?.title == "Mochi had a chaotic day.")
        #expect(recap?.scenes.map(\.part) == [.morning, .afternoon, .evening])
        #expect(recap?.scenes.map(\.stamp.mood) == [.tired, .stressed, .happy])
    }

    @Test func recapAdjectives() {
        #expect(MoodHistory.adjective(for: [stamp(.sad, hour: 9)]) == "heavy")
        #expect(MoodHistory.adjective(for: [stamp(.calm, hour: 9), stamp(.happy, hour: 12)]) == "lovely")
        #expect(MoodHistory.adjective(for: [stamp(.tired, hour: 9), stamp(.tired, hour: 12), stamp(.happy, hour: 15)]) == "sleepy")
    }

    @Test func monthGridHasLeadingBlanksAndEveryDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let sept2026 = cal.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let grid = MoodHistory.monthGrid(for: sept2026, calendar: cal)
        // 1 Sep 2026 is a Tuesday → two leading blanks (Sun, Mon).
        #expect(grid.prefix(2).allSatisfy { $0 == nil })
        #expect(grid.compactMap { $0 }.count == 30)
    }

    @Test func snapshotRoundTripsThroughJSON() throws {
        let snapshot = PetSnapshot(identity: PetIdentity(species: .penguin, name: "Pebble"), mood: .excited, intensity: .strong, loggedAt: .now, today: [stamp(.excited, hour: 10)])
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PetSnapshot.self, from: data)
        #expect(decoded == snapshot)
        #expect(decoded.state().mood == .excited)
    }

    @Test func snapshotFadesOldMoodsAndSleepsAtNight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let id = PetIdentity(species: .cat)
        let loggedAt = cal.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 10))!
        let snapshot = PetSnapshot(identity: id, mood: .stressed, intensity: .strong, loggedAt: loggedAt)
        let soon = loggedAt.addingTimeInterval(3600)
        #expect(snapshot.state(at: soon, calendar: cal).intensity == .strong)
        let later = loggedAt.addingTimeInterval(9 * 3600)
        #expect(snapshot.state(at: later, calendar: cal).intensity == .slight)
        let night = cal.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 1))!
        #expect(snapshot.state(at: night, calendar: cal).mood == .tired)
    }
}
