import AppIntents
import SwiftUI
import WidgetKit

/// Widget content, shared so the app can preview it. `family` is passed explicitly.
public struct PetHomeWidgetView: View {
    public var snapshot: PetSnapshot
    public var date: Date
    public var family: WidgetFamily
    public var showsBackground: Bool

    public init(snapshot: PetSnapshot, date: Date = .now, family: WidgetFamily, showsBackground: Bool = true) {
        self.snapshot = snapshot
        self.date = date
        self.family = family
        self.showsBackground = showsBackground
    }

    private var identity: PetIdentity { snapshot.identity }
    private var state: PetMoodState { snapshot.state(at: date) }

    public var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        default: large
        }
    }

    private var mood: Mood? {
        guard let m = snapshot.mood, let at = snapshot.loggedAt, date.timeIntervalSince(at) < PetSnapshot.freshness else { return nil }
        return m
    }

    // Small: just the pet, big.
    private var small: some View {
        ZStack(alignment: .bottomLeading) {
            PetSceneView(identity: identity, state: state, time: nil, petScale: 0.70, petVerticalPosition: 0.53, showsFloor: showsBackground, showsAccessory: showsBackground, showsBackground: false)
            HStack {
                Text(identity.name).font(PipFont.caption)
                Spacer(minLength: 0)
                Image(systemName: state.mood.symbolName).foregroundStyle(MoodColor.bold(state.mood))
            }
            .padding(12)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    // Medium: pet, name and status, three quick-log buttons in their mood colours.
    private var medium: some View {
        HStack(spacing: 0) {
            PetSceneView(identity: identity, state: state, time: nil, petScale: 0.80, petVerticalPosition: 0.55, showsBackground: false)
                .frame(maxWidth: 145)
            VStack(alignment: .leading, spacing: 6) {
                Text(identity.name)
                    .font(.system(.title2, design: .serif, weight: .regular))
                Text(statusLine)
                    .font(PipFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    ForEach([Mood.happy, .calm, .stressed], id: \.self) { m in
                        Button(intent: LogMoodIntent(mood: m)) {
                            PetView(identity: identity, state: PetStateResolver.resolve(mood: m, identity: identity), showsShadow: false, framing: .badge)
                                .frame(width: 34, height: 34)
                                .padding(4)
                                .background(MoodColor.bold(m).opacity(0.18), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Log \(m.displayName)")
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.trailing, 14)
        }
        .accessibilityElement(children: .contain)
    }

    // Large: the pet, then today as a row of mood-coloured chips.
    private var large: some View {
        VStack(spacing: 0) {
            PetSceneView(identity: identity, state: state, time: nil, petScale: 0.70, petVerticalPosition: 0.53, showsBackground: false)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(identity.name).font(PipFont.title2)
                    Spacer()
                    Text(snapshot.today.isEmpty ? "Nothing yet today" : "Today")
                        .font(PipFont.caption)
                        .foregroundStyle(.secondary)
                }
                if !snapshot.today.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(snapshot.today.suffix(6)) { stamp in
                            VStack(spacing: 2) {
                                PetView(identity: identity, state: PetStateResolver.resolve(mood: stamp.mood, intensity: stamp.intensity, identity: identity), showsShadow: false, framing: .badge)
                                    .frame(width: 36, height: 36)
                                    .padding(3)
                                    .background(MoodColor.bold(stamp.mood).opacity(0.18), in: Circle())
                                Text(stamp.time, style: .time)
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("\(stamp.time.formatted(date: .omitted, time: .shortened)): \(stamp.mood.displayName)")
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var statusLine: String {
        if let mood = snapshot.mood, let at = snapshot.loggedAt, date.timeIntervalSince(at) < PetSnapshot.freshness {
            return "\(identity.name) \(mood.petDescription) · \(at.formatted(.relative(presentation: .named)))"
        }
        return "Tap a face to say how you feel."
    }

    private var accessibilityLabel: String { "\(identity.name) \(state.mood.petDescription)." }
}

public struct PetLockScreenView: View {
    public var snapshot: PetSnapshot
    public var date: Date
    public var family: WidgetFamily

    public init(snapshot: PetSnapshot, date: Date = .now, family: WidgetFamily) {
        self.snapshot = snapshot
        self.date = date
        self.family = family
    }

    private var identity: PetIdentity { snapshot.identity }
    private var state: PetMoodState { snapshot.state(at: date) }

    public var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                PetView(identity: identity, state: state, showsShadow: false, framing: .badge)
                    .padding(4)
            }
            .accessibilityLabel("\(identity.name) \(state.mood.petDescription).")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                PetView(identity: identity, state: state, showsShadow: false, framing: .badge)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(identity.name).font(.headline.weight(.semibold)).widgetAccentable()
                    Text(state.mood.petDescription.capitalizedFirst).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        default:
            Label("\(identity.name) \(state.mood.petDescription)", systemImage: state.mood.symbolName)
        }
    }
}

public extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
