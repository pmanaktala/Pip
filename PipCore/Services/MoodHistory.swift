import Foundation

/// Pure history calculations: dominant mood per day, week strips, daily recaps. Unit-tested.
public enum MoodHistory {

    /// The mood that best represents a day: most frequent; ties go to the latest.
    public static func dominant(_ stamps: [MoodStamp]) -> MoodStamp? {
        guard !stamps.isEmpty else { return nil }
        var counts: [Mood: Int] = [:]
        for s in stamps { counts[s.mood, default: 0] += 1 }
        let best = counts.values.max() ?? 0
        let candidates = Set(counts.filter { $0.value == best }.map(\.key))
        return stamps.filter { candidates.contains($0.mood) }.max { $0.time < $1.time }
    }

    /// Groups stamps by start-of-day.
    public static func byDay(_ stamps: [MoodStamp], calendar: Calendar = .current) -> [Date: [MoodStamp]] {
        Dictionary(grouping: stamps) { calendar.startOfDay(for: $0.time) }
    }

    public enum DayPart: String, CaseIterable, Sendable {
        case morning, afternoon, evening

        public var displayName: String { rawValue.capitalized }

        public static func part(of date: Date, calendar: Calendar = .current) -> DayPart {
            let h = calendar.component(.hour, from: date)
            if h < 12 { return .morning }
            if h < 18 { return .afternoon }
            return .evening
        }
    }

    /// "Mochi had a chaotic Tuesday." plus up to three small scenes.
    public struct DailyRecap: Equatable, Sendable {
        public var title: String
        public var scenes: [(part: DayPart, stamp: MoodStamp)]

        public static func == (lhs: DailyRecap, rhs: DailyRecap) -> Bool {
            lhs.title == rhs.title && lhs.scenes.map(\.stamp) == rhs.scenes.map(\.stamp)
        }
    }

    public static func recap(for day: Date, stamps: [MoodStamp], petName: String, calendar: Calendar = .current) -> DailyRecap? {
        let dayStamps = stamps.filter { calendar.isDate($0.time, inSameDayAs: day) }.sorted { $0.time < $1.time }
        guard !dayStamps.isEmpty else { return nil }

        let weekday = calendar.isDateInToday(day) ? "day" : day.formatted(.dateTime.weekday(.wide))
        let adjective = adjective(for: dayStamps)
        let article = ["a", "e", "i", "o", "u"].contains(String(adjective.prefix(1))) ? "an" : "a"
        let title = "\(petName) had \(article) \(adjective) \(weekday)."

        var scenes: [(DayPart, MoodStamp)] = []
        for part in DayPart.allCases {
            let inPart = dayStamps.filter { DayPart.part(of: $0.time, calendar: calendar) == part }
            if let d = dominant(inPart) { scenes.append((part, d)) }
        }
        return DailyRecap(title: title, scenes: scenes)
    }

    static func adjective(for stamps: [MoodStamp]) -> String {
        let moods = stamps.map(\.mood)
        let distinct = Set(moods)
        let positives = moods.filter { $0.valence > 0.2 }.count
        let negatives = moods.filter { $0.valence < -0.2 }.count

        if stamps.count == 1 {
            switch moods[0] {
            case .happy, .excited: return "bright"
            case .calm: return "gentle"
            case .neutral: return "quiet"
            case .tired: return "sleepy"
            case .stressed: return "tense"
            case .sad: return "heavy"
            case .frustrated: return "prickly"
            }
        }
        if distinct.count >= 3 && positives > 0 && negatives > 0 { return "chaotic" }
        if negatives == 0 && positives == moods.count { return "lovely" }
        if moods.filter({ $0 == .tired }).count * 2 >= moods.count { return "sleepy" }
        if moods.filter({ $0 == .stressed || $0 == .frustrated }).count * 2 >= moods.count { return "tense" }
        if moods.filter({ $0 == .sad }).count * 2 >= moods.count { return "heavy" }
        if moods.filter({ $0 == .calm || $0 == .neutral }).count * 2 >= moods.count { return "steady" }
        if positives > negatives { return "mostly good" }
        return "mixed"
    }

    /// Dates for a month grid: leading blanks (nil) then each day.
    public static func monthGrid(for month: Date, calendar: Calendar = .current) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let first = interval.start
        let weekdayOffset = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: weekdayOffset)
        var day = first
        while day < interval.end {
            cells.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return cells
    }

    /// The last `count` days ending today, oldest first.
    public static func recentDays(count: Int, ending: Date = .now, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: ending)
        return (0..<count).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }
}
