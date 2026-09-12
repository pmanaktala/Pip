import Foundation
import Testing
@testable import Pip

struct PetMomentSchedulerTests {
    private func makeScheduler() -> PetMomentScheduler {
        let defaults = UserDefaults(suiteName: "PetMomentSchedulerTests.\(UUID().uuidString)")!
        return PetMomentScheduler(defaults: defaults)
    }

    @Test func moodLogKindsFollowMood() {
        let s = makeScheduler()
        let id = PetIdentity(species: .cat)
        #expect(s.moodLogged(.excited, intensity: .strong, identity: id, liveActivitiesEnabled: true)?.kind == .celebration)
        #expect(s.moodLogged(.stressed, intensity: .moderate, identity: id, liveActivitiesEnabled: true)?.kind == .breather)
        #expect(s.moodLogged(.stressed, intensity: .moderate, identity: id, liveActivitiesEnabled: true)?.mood == .calm)
        #expect(s.moodLogged(.calm, intensity: .moderate, identity: id, liveActivitiesEnabled: true)?.kind == .moodChange)
        #expect(s.moodLogged(.calm, intensity: .moderate, identity: id, liveActivitiesEnabled: false) == nil)
    }

    @Test func foregroundMomentsAreRateLimitedPerDay() {
        let s = makeScheduler()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let scheduler = PetMomentScheduler(defaults: UserDefaults(suiteName: "PetMomentSchedulerTests.\(UUID().uuidString)")!, calendar: cal)
        _ = s
        let snapshot = PetSnapshot(identity: .placeholder)
        // Find an evening where the seeded roll produces a wind-down, then verify it never repeats that day.
        var found = false
        for day in 1...60 {
            let evening = cal.date(from: DateComponents(year: 2026, month: 1, day: day, hour: 21))!
            if let d = scheduler.foreground(snapshot: snapshot, petMomentsEnabled: true, now: evening), d.kind == .windDown {
                found = true
                let later = evening.addingTimeInterval(1800)
                #expect(scheduler.foreground(snapshot: snapshot, petMomentsEnabled: true, now: later)?.kind != .windDown)
                break
            }
        }
        #expect(found)
        #expect(scheduler.foreground(snapshot: snapshot, petMomentsEnabled: false) == nil)
    }
}
