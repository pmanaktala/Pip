import Foundation

/// The season, from the date and your region (flipped for the southern hemisphere). No
/// location: the region is the phone's own setting.
public enum PetSeason: String, Codable, Sendable, CaseIterable {
    case spring, summer, autumn, winter

    public static func at(_ date: Date, calendar: Calendar = .current, region: String? = Locale.current.region?.identifier) -> PetSeason {
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["PIP_SEASON"], let s = PetSeason(rawValue: forced) { return s }
        #endif
        let month = calendar.component(.month, from: date)
        let north: PetSeason = switch month {
        case 3...5: .spring
        case 6...8: .summer
        case 9...11: .autumn
        default: .winter
        }
        let south: Set<String> = ["AU", "NZ", "ZA", "AR", "CL", "UY", "PY", "BO", "PE", "BR", "NA", "BW", "ZW", "MZ", "MG", "LS", "SZ", "FJ", "NC"]
        guard let region, south.contains(region) else { return north }
        return switch north {
        case .spring: .autumn
        case .summer: .winter
        case .autumn: .spring
        case .winter: .summer
        }
    }
}

/// What the phone quietly tells us, with no permission and nothing stored beyond the device:
/// used only while the app is open, never sent anywhere (Bible §4, "context").
public struct PetContext: Equatable, Sendable {
    /// Another app is playing audio.
    public var audioPlaying = false
    /// Headphones or AirPods are connected.
    public var headphones = false
    public var charging = false
    /// Low Power Mode, or the battery under 15%.
    public var lowBattery = false
    /// The time zone changed in the last day: you're somewhere new.
    public var travelling = false
    /// No network at all (flight mode, or somewhere without signal).
    public var offline = false
    /// You haven't opened Pip for a few days.
    public var missedYou = false

    public init() {}
}

/// On the neck, under the head.
public enum PetNeck: String, Codable, Sendable, Hashable {
    /// Winter, whenever it is awake.
    case scarf
    /// No signal: it has its travel pillow on, as if on a plane.
    case travelPillow
}

/// Sitting on the floor beside the pet (never held).
public enum PetExtra: String, Codable, Sendable, Hashable {
    /// You're somewhere new: its little suitcase came too.
    case suitcase
    /// The day you adopted it, once a year.
    case cake
}

/// A small sign over its head.
public enum PetSign: String, Codable, Sendable, Hashable {
    case charging
    case lowBattery
}

/// Everything the pet has on or around it at a moment, chosen together so it never wears two
/// things in one place and never celebrates while you're having a hard time.
public struct PetDressing: Equatable, Sendable {
    public var head: PetWear?
    public var neck: PetNeck?
    public var extra: PetExtra?
    public var sign: PetSign?
    public var season: PetSeason
    /// Confetti in the room (New Year, its birthday).
    public var confetti: Bool

    public init(head: PetWear? = nil, neck: PetNeck? = nil, extra: PetExtra? = nil, sign: PetSign? = nil, season: PetSeason = .autumn, confetti: Bool = false) {
        self.head = head
        self.neck = neck
        self.extra = extra
        self.sign = sign
        self.season = season
        self.confetti = confetti
    }

    /// New Year's Eve from 18:00 until the end of New Year's Day.
    public static func isNewYear(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.month, .day, .hour], from: date)
        return (c.month == 12 && c.day == 31 && (c.hour ?? 0) >= 18) || (c.month == 1 && c.day == 1)
    }

    /// The anniversary of the day you met (not the day itself).
    public static func isBirthday(adoptedAt: Date?, _ date: Date, calendar: Calendar = .current) -> Bool {
        guard let adoptedAt, date.timeIntervalSince(adoptedAt) > 300 * 86400 else { return false }
        let a = calendar.dateComponents([.month, .day], from: adoptedAt), d = calendar.dateComponents([.month, .day], from: date)
        return a.month == d.month && a.day == d.day
    }

    public static func choose(for stance: PetStance, at date: Date, context: PetContext = PetContext(), adoptedAt: Date? = nil,
                              calendar: Calendar = .current) -> PetDressing {
        let season = PetSeason.at(date, calendar: calendar)
        var d = PetDressing(season: season)
        if stance == .meditating { return d }
        let hard: Bool = if case .mood(let m, _) = stance { [.sad, .stressed, .tired, .frustrated].contains(m) } else { false }
        let celebrate = !hard && !stance.isAsleep
        let newYear = isNewYear(date, calendar: calendar)
        let birthday = isBirthday(adoptedAt: adoptedAt, date, calendar: calendar)

        // Head: asleep always the nightcap; then listening; then a party hat; then bedtime.
        if stance.isAsleep {
            d.head = .nightcap
        } else if context.audioPlaying || context.headphones {
            d.head = .headphones
        } else if celebrate && (newYear || birthday) {
            d.head = .partyHat
        } else if PetDay.isBedtime(date, calendar: calendar) {
            d.head = .nightcap
        }
        // Neck: a travel pillow beats the scarf.
        if context.offline { d.neck = .travelPillow }
        else if season == .winter { d.neck = .scarf }
        // Floor: the suitcase while you're somewhere new; the cake on its birthday.
        if context.travelling { d.extra = .suitcase }
        else if birthday && !hard { d.extra = .cake }
        // Battery: charging is content, low is sleepy.
        if context.charging { d.sign = .charging }
        else if context.lowBattery { d.sign = .lowBattery }
        d.confetti = celebrate && (newYear || birthday)
        return d
    }
}
