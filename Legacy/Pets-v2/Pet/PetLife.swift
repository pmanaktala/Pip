import Foundation

/// What the pet is doing when you haven't told it how you feel for a while.
///
/// A fresh mood always wins — an excited pet at 11pm is excited, not asleep. Once a mood has
/// faded (`PetSnapshot.freshness`), the pet gets on with its own day: asleep under a nightcap at
/// night, a stretch and a yawn in the morning, at a small laptop on weekday office hours, a book
/// in the evening and at weekends. Widgets and Live Activities share the same schedule.
public enum PetLife: String, Sendable, CaseIterable {
    case sleeping, waking, working, reading, lounging

    public static func activity(at date: Date, calendar: Calendar = .current) -> PetLife {
        var hour = Double(calendar.component(.hour, from: date)) + Double(calendar.component(.minute, from: date)) / 60
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["PIP_HOUR"], let h = Double(forced) { hour = h }
        #endif
        let weekend = calendar.isDateInWeekend(date)
        switch hour {
        case ..<6.5, 22...: return .sleeping
        case ..<8.5: return .waking
        case ..<17.5: return weekend ? .lounging : .working
        default: return .reading
        }
    }

    /// The status line for the Pet tab.
    public func describe(_ name: String) -> String {
        switch self {
        case .sleeping: "\(name) is fast asleep."
        case .waking: "\(name) is just waking up."
        case .working: "\(name) is at work. Sort of."
        case .reading: "\(name) is reading."
        case .lounging: "\(name) is lounging about."
        }
    }

    public static func describe(_ name: String, at date: Date) -> String {
        activity(at: date).describe(name)
    }

    /// The pose, motion and prop for the activity. Built on the resolver's moods so the species
    /// and personality still show through.
    public func state(identity: PetIdentity) -> PetMoodState {
        switch self {
        case .sleeping:
            var s = PetStateResolver.resolve(mood: .tired, intensity: .moderate, identity: identity)
            s.rig.eyeOpen = 0
            s.rig.lidHeaviness = 1
            s.rig.lying = 0.55
            s.rig.lean = 0
            s.rig.tilt = 6
            s.rig.headDrop = 0.75
            s.rig.mouthCurve = 0.3
            s.rig.mouthOpen = 0.12
            s.rig.armCross = 0.3
            s.rig.gazeX = 0
            s.rig.gazeY = 0
            s.motion.breathRate = 0.11
            s.motion.breathAmount = 0.045
            s.motion.nod = 0
            s.motion.swayAmount = 0
            s.motion.blinkInterval = .infinity
            s.motion.gazeInterval = .infinity
            s.motion.earTwitch = 0.1
            s.motion.bit = .snore
            s.motion.bitInterval = 9
            s.accessory = .nightcap
            return s

        case .waking:
            var s = PetStateResolver.resolve(mood: .calm, intensity: .slight, identity: identity)
            s.rig.eyeOpen = 0.55
            s.rig.lidHeaviness = 0.6
            s.rig.headDrop = 0.3
            s.rig.tilt = 8
            s.motion.bit = .stretch
            s.motion.bitInterval = 7
            s.motion.alternateBits = [.curious]
            s.accessory = nil
            return s

        case .working:
            var s = PetStateResolver.resolve(mood: .neutral, intensity: .moderate, identity: identity)
            s.rig.armForward = 1 // paws down on the keys, behind the lid
            s.rig.armRaise = 0
            s.rig.armOut = 0
            s.rig.gazeY = 0.45
            s.rig.gazeX = 0
            s.rig.headDrop = 0.2
            s.rig.tilt = 2
            s.rig.eyeOpen = 0.9
            s.motion.swayAmount = 0.6
            s.motion.gazeInterval = .infinity
            s.motion.blinkInterval = 3
            s.motion.bit = .typing
            s.motion.bitInterval = 4
            s.motion.alternateBits = [.typing, .stretch]
            s.accessory = .laptop
            return s

        case .reading:
            var s = PetStateResolver.resolve(mood: .calm, intensity: .slight, identity: identity)
            s.rig.armHold = 1 // the book sits between the paws
            s.rig.armCross = 0
            s.rig.armRaise = 0
            s.rig.gazeY = 0.5
            s.rig.gazeX = 0.1
            s.rig.headDrop = 0.25
            s.rig.eyeOpen = 0.85
            s.rig.lidHeaviness = 0.2
            s.rig.tilt = 5
            s.motion.gazeInterval = .infinity
            s.motion.swayAmount = 0.5
            s.motion.bit = .pageTurn
            s.motion.bitInterval = 6
            s.motion.alternateBits = [.pageTurn, .stretch]
            s.accessory = .book
            return s

        case .lounging:
            var s = PetStateResolver.resolve(mood: .neutral, intensity: .moderate, identity: identity)
            s.motion.bit = .curious
            s.motion.bitInterval = 8
            s.motion.alternateBits = [.curious, .stretch, .wiggle]
            s.motion.swayAmount = 2.2
            return s
        }
    }
}
