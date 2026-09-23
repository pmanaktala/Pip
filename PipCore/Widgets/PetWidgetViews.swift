import AppIntents
import SwiftUI
import WidgetKit

/// One widget moment: the snapshot, the time it is for, and which still pose to show.
public struct PetWidgetMoment: Sendable {
    public var snapshot: PetSnapshot
    public var date: Date
    public var hold: Int

    public init(snapshot: PetSnapshot, date: Date, hold: Int = 0) {
        self.snapshot = snapshot
        self.date = date
        self.hold = hold
    }

    public var identity: PetIdentity { snapshot.identity }
    public var stance: PetStance { snapshot.stance(at: date) }
    public var scene: PetScene { PetScene(species: identity.species, stance: stance) }
    public var status: String { stance.describe(identity.name) }
    public var freshMood: Mood? { snapshot.freshMood(at: date) }

    /// Entries for a widget timeline: every half hour for eight hours, plus the moment the
    /// pet's day or the mood's freshness changes, each with the next still pose. The system
    /// animates between entries, so the pet visibly shifts now and then without any work.
    public static func timeline(for snapshot: PetSnapshot, from now: Date = .now, calendar: Calendar = .current) -> [PetWidgetMoment] {
        var dates: Set<Date> = [now]
        var t = now
        let end = now.addingTimeInterval(8 * 3600)
        while t < end {
            t = calendar.nextDate(after: t, matching: DateComponents(minute: t.minuteOfHour(calendar) < 30 ? 30 : 0), matchingPolicy: .nextTime) ?? t.addingTimeInterval(1800)
            dates.insert(t)
        }
        var change = now
        for _ in 0..<6 {
            change = PetDay.nextChange(after: change, calendar: calendar)
            if change < end { dates.insert(change) }
        }
        if let at = snapshot.loggedAt {
            let fade = at.addingTimeInterval(PetSnapshot.freshness)
            if fade > now, fade < end { dates.insert(fade) }
        }
        let sorted = dates.sorted()
        return sorted.enumerated().map { PetWidgetMoment(snapshot: snapshot, date: $1, hold: $0) }
    }
}

private extension Date {
    func minuteOfHour(_ calendar: Calendar) -> Int { calendar.component(.minute, from: self) }
}

#if os(iOS)
/// Home Screen widgets. Small: the pet in its room. Medium: the pet, what it is up to, and four
/// faces to log with. Large: the pet above all eight faces and today.
public struct PetHomeWidgetView: View {
    public var moment: PetWidgetMoment
    public var family: WidgetFamily
    public var showsBackground: Bool

    @Environment(\.colorScheme) private var scheme

    public init(moment: PetWidgetMoment, family: WidgetFamily, showsBackground: Bool = true) {
        self.moment = moment
        self.family = family
        self.showsBackground = showsBackground
    }

    /// Where the pet's feet meet the horizon in each family; the container background uses it too.
    public static func floor(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemMedium: 0.84
        case .systemLarge: 0.5
        default: 0.8
        }
    }

    public var body: some View {
        switch family {
        case .systemMedium: medium
        case .systemLarge: large
        default: small
        }
    }

    private var pet: some View {
        PetStage(scene: moment.scene, live: false, hold: moment.hold, petScale: family == .systemLarge ? 0.42 : (family == .systemMedium ? 0.92 : 0.74),
                 floor: Self.floor(for: family), showsRoom: false, date: moment.date)
            .animation(.smooth(duration: 1.2), value: moment.hold)
    }

    private var small: some View {
        ZStack(alignment: .topLeading) {
            pet
            VStack(alignment: .leading, spacing: 0) {
                Text(moment.identity.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
            .padding(12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(moment.status)
    }

    private var medium: some View {
        HStack(spacing: 0) {
            pet.frame(width: 150)
            VStack(alignment: .leading, spacing: 4) {
                Text(moment.identity.name)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text(moment.status)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    ForEach([Mood.happy, .calm, .tired, .stressed], id: \.self) { mood in
                        MoodFaceButton(identity: moment.identity, mood: mood, size: 34)
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.trailing, 14)
            Spacer(minLength: 0)
        }
    }

    private var large: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                pet
                VStack(alignment: .leading, spacing: 2) {
                    Text(moment.identity.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text(moment.status)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .frame(maxHeight: .infinity)
            VStack(spacing: 10) {
                Text("How are you?")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(0..<2) { row in
                        GridRow {
                            ForEach(Mood.allCases[(row * 4)..<(row * 4 + 4)], id: \.self) { mood in
                                MoodFaceButton(identity: moment.identity, mood: mood, size: 40, labeled: true)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .padding(.top, 8)
        }
    }
}

/// A mood as the pet's face on a soft token; logs the mood without opening the app.
public struct MoodFaceButton: View {
    public var identity: PetIdentity
    public var mood: Mood
    public var size: CGFloat
    public var labeled: Bool
    @Environment(\.colorScheme) private var scheme

    public init(identity: PetIdentity, mood: Mood, size: CGFloat, labeled: Bool = false) {
        self.identity = identity
        self.mood = mood
        self.size = size
        self.labeled = labeled
    }

    public var body: some View {
        Button(intent: LogMoodIntent(mood: mood)) {
            VStack(spacing: 3) {
                PetView(species: identity.species, mood: mood, framing: .badge)
                    .frame(width: size - 6, height: size - 6)
                    .padding(3)
                    .background(MoodColor.bold(mood).opacity(scheme == .dark ? 0.3 : 0.2), in: Circle())
                if labeled {
                    Text(mood.displayName)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: labeled ? .infinity : nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log \(mood.displayName)")
    }
}

#endif

/// Lock Screen and watch accessories: the badge face, designed for this size.
public struct PetAccessoryView: View {
    public var moment: PetWidgetMoment
    public var family: WidgetFamily

    public init(moment: PetWidgetMoment, family: WidgetFamily) {
        self.moment = moment
        self.family = family
    }

    private var face: some View {
        PetPoseView(species: moment.identity.species, pose: PetDirector.hold(moment.scene, index: moment.hold),
                    prop: moment.stance.prop == .nightcap ? .nightcap : nil, framing: .badge, showsShadow: false)
    }

    public var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                face.padding(3)
            }
            .accessibilityLabel(moment.status)
        case .accessoryRectangular:
            HStack(spacing: 6) {
                face.frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 1) {
                    Text(moment.identity.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .widgetAccentable()
                    Text(moment.stance.phrase(moment.identity.name))
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        #if os(watchOS)
        case .accessoryCorner:
            face.padding(2)
                .widgetLabel { Text(moment.identity.name) }
                .accessibilityLabel(moment.status)
        #endif
        default:
            Text(moment.status)
        }
    }
}

public extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
