import Foundation

/// The pet's own day, used whenever no mood is fresh. A pure function of the local clock, so the
/// phone, the watch, widgets and complications all agree on what the pet is doing.
public enum PetDay {
    public static func activity(at date: Date, calendar: Calendar = .current) -> PetActivity {
        let c = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        var h = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["PIP_HOUR"], let fh = Double(forced) { h = fh }
        #endif
        let day = Double(calendar.ordinality(of: .day, in: .era, for: date) ?? 0)
        switch h {
        case 22.5..., ..<6: return .sleeping
        case ..<9: return .waking
        case 21.5...: return .windingDown
        case 18.5...: return .reading
        case 14..<15 where PetMath.hash01(day * 3.1) < 0.55: return .napping
        case 9..<12 where isWeekday(c.weekday): return .working
        case 13.5..<17.5 where isWeekday(c.weekday): return .working
        default:
            // Ninety-minute blocks through the day, never the same thing twice in a row.
            let options: [PetActivity] = [.daydreaming, .playing, .reading]
            let block = Int((h - 8) / 1.5)
            func pick(_ b: Int) -> Int { Int(PetMath.hash01(day * 10 + Double(b) * 1.37) * 3) % 3 }
            var i = pick(block)
            if block > 0, i == pick(block - 1) { i = (i + 1) % 3 }
            return options[i]
        }
    }

    static func isWeekday(_ weekday: Int?) -> Bool {
        guard let weekday else { return false }
        return weekday != 1 && weekday != 7
    }

    /// Bedtime: 21:30 until 6:00. The pet wears its nightcap whatever else it is doing.
    public static func isBedtime(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        var h = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["PIP_HOUR"], let fh = Double(forced) { h = fh }
        #endif
        return h >= 21.5 || h < 6
    }

    /// Deep night, when a pet left alone falls asleep: 22:30 until 6:00.
    public static func isNight(_ date: Date, calendar: Calendar = .current) -> Bool {
        activity(at: date, calendar: calendar) == .sleeping
    }

    /// When the current activity ends — used to schedule widget timeline entries at the change.
    public static func nextChange(after date: Date, calendar: Calendar = .current) -> Date {
        let now = activity(at: date, calendar: calendar)
        var t = date
        for _ in 0..<96 {
            t = t.addingTimeInterval(15 * 60)
            if activity(at: t, calendar: calendar) != now { return t }
        }
        return date.addingTimeInterval(3600)
    }
}

/// The breathing guide for sitting together: four seconds in, six out, eased. The pet's chest,
/// the ring and the words all read this one curve.
public enum PetBreath {
    public static let period: TimeInterval = 10

    /// 0 (empty) … 1 (full) at `date`.
    public static func guide(at date: Date) -> Double {
        let u = date.timeIntervalSince1970.truncatingRemainder(dividingBy: period) / period
        return u < 0.4 ? PetMath.easeInOut(u / 0.4) : 1 - PetMath.easeInOut((u - 0.4) / 0.6)
    }

    public static func isInhaling(at date: Date) -> Bool {
        date.timeIntervalSince1970.truncatingRemainder(dividingBy: period) / period < 0.4
    }
}
