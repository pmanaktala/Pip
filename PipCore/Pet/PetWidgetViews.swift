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

    // Small: just the pet. In StandBy (no container background) it sits on a desk-like floor.
    private var small: some View {
        PetSceneView(identity: identity, state: state, time: nil, petScale: 1.0, petVerticalPosition: 0.5, showsFloor: true, showsAccessory: showsBackground)
            .accessibilityLabel(accessibilityLabel)
    }

    private var medium: some View {
        HStack(spacing: 0) {
            PetSceneView(identity: identity, state: state, time: nil, petScale: 0.92, petVerticalPosition: 0.5)
                .frame(width: 150)
            VStack(alignment: .leading, spacing: 8) {
                Text(identity.name)
                    .font(PipFont.headline)
                Text(statusLine)
                    .font(PipFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    ForEach([Mood.happy, .calm, .stressed], id: \.self) { mood in
                        Button(intent: LogMoodIntent(mood: mood)) {
                            PetView(identity: identity, state: PetStateResolver.resolve(mood: mood, identity: identity), showsShadow: false, framing: .face)
                                .frame(width: 36, height: 36)
                                .padding(3)
                                .background(PetPalette.ambient(for: mood).opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Log \(mood.displayName)")
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.trailing, 14)
        }
        .accessibilityElement(children: .contain)
    }

    private var large: some View {
        VStack(spacing: 0) {
            PetSceneView(identity: identity, state: state, time: nil, petScale: 0.72, petVerticalPosition: 0.5)
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.today.isEmpty ? "Today, so far: nothing yet." : "Today, so far")
                    .font(PipFont.caption)
                    .foregroundStyle(.secondary)
                if !snapshot.today.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(snapshot.today.suffix(6)) { stamp in
                            VStack(spacing: 1) {
                                PetView(identity: identity, state: PetStateResolver.resolve(mood: stamp.mood, intensity: stamp.intensity, identity: identity), showsShadow: false, framing: .face)
                                    .frame(width: 40, height: 40)
                                Text(stamp.time, style: .time)
                                    .font(.system(size: 9, design: .rounded))
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
                PetView(identity: identity, state: state, showsShadow: false, framing: .face)
                    .padding(4)
            }
            .accessibilityLabel("\(identity.name) \(state.mood.petDescription).")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                PetView(identity: identity, state: state, showsShadow: false, framing: .face)
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
