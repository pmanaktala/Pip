import WidgetKit
import SwiftUI
import Testing
import UIKit
@testable import Pip

/// Frame-level review of motion. Every gesture is a pure function of time, so the exact frames
/// of each mood's signature bit, each transition and the tap reaction can be rendered offscreen
/// and inspected as filmstrips. Set `PIP_FILM_OUTPUT` to a directory to write the PNGs.
@MainActor
struct AnimationFilmstripTests {
    private var outputDir: URL? {
        ProcessInfo.processInfo.environment["PIP_FILM_OUTPUT"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// The first slot after `from` in which `motion`'s *signature* bit plays, and its duration.
    /// Alternates are skipped so every strip shows the bit its label names.
    private func bitWindow(_ motion: PetMotionProfile, from: Double = 0) -> (start: Double, duration: Double)? {
        if motion.bit == .meditate { return (from, 6) }
        var t = from
        for _ in 0..<12 {
            guard let next = PetAnimator.nextBit(motion, from: t) else { return nil }
            if next.bit == motion.bit { return (next.start, next.bit.duration) }
            t = next.start + next.bit.duration + 0.01
        }
        return nil
    }

    private func strip(_ label: String, frames: [(String, AnyView)]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12, weight: .bold, design: .rounded))
            HStack(spacing: 4) {
                ForEach(Array(frames.enumerated()), id: \.offset) { _, f in
                    VStack(spacing: 1) {
                        f.1.frame(width: 96, height: 96)
                        Text(f.0).font(.system(size: 8, design: .rounded)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func write(_ view: some View, name: String) throws {
        let renderer = ImageRenderer(content: view.padding(12).background(Color(red: 0.97, green: 0.95, blue: 0.91)).environment(\.colorScheme, .light))
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        #expect(image.size.width > 100)
        if let dir = outputDir {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try #require(image.pngData()).write(to: dir.appendingPathComponent("\(name).png"))
        }
    }

    /// One filmstrip per mood: every species across the bit's window.
    @Test func signatureBits() throws {
        for mood in Mood.allCases {
            var rows: [AnyView] = []
            for species in PetSpecies.allCases {
                let identity = PetIdentity(species: species)
                let state = PetStateResolver.resolve(mood: mood, identity: identity)
                guard let window = bitWindow(state.motion) else { continue }
                let n = 10
                let frames: [(String, AnyView)] = (0..<n).map { i in
                    let t = window.start - 0.15 + (window.duration + 0.4) * Double(i) / Double(n - 1)
                    return (String(format: "%.2f", t - window.start), AnyView(PetSceneView(identity: identity, state: state, time: t, petScale: 0.9, petVerticalPosition: 0.5, showsFloor: false, showsBackground: false)))
                }
                rows.append(AnyView(strip("\(species.defaultName) · \(mood.displayName) · \(state.motion.bit.rawValue)", frames: frames)))
            }
            try write(VStack(alignment: .leading, spacing: 8) { ForEach(Array(rows.enumerated()), id: \.offset) { $0.element } }, name: "bit-\(mood.rawValue)")
        }
    }

    /// Transitions: the interpolated rig between two moods must look like a pose at every step.
    @Test func transitions() throws {
        let pairs: [(Mood, Mood)] = [(.neutral, .sad), (.sad, .excited), (.happy, .tired), (.tired, .stressed), (.calm, .frustrated), (.excited, .calm)]
        var rows: [AnyView] = []
        for species in PetSpecies.allCases {
            let identity = PetIdentity(species: species)
            for (a, b) in pairs {
                let from = PetStateResolver.resolve(mood: a, identity: identity)
                let to = PetStateResolver.resolve(mood: b, identity: identity)
                let frames: [(String, AnyView)] = (0...8).map { i in
                    let t = Double(i) / 8
                    var mid = to
                    mid.rig = PetRig.lerp(from.rig, to.rig, t)
                    mid.accessory = nil
                    return (String(format: "%.0f%%", t * 100), AnyView(PetView(identity: identity, state: mid, time: nil)))
                }
                rows.append(AnyView(strip("\(species.defaultName) · \(a.displayName) → \(b.displayName)", frames: frames)))
            }
        }
        try write(VStack(alignment: .leading, spacing: 8) { ForEach(Array(rows.enumerated()), id: \.offset) { $0.element } }, name: "transitions")
    }

    /// The tap repertoire: for every mood, the base, the hello (first beat, second beat), the
    /// giggle on a quick second tap, the dizzy sixth tap, and the petting overlay.
    @Test func tapReactions() throws {
        let state = AppState(container: PipModelContainer.make(inMemory: true), preferences: Preferences(defaults: UserDefaults(suiteName: "film.\(UUID().uuidString)")!))
        var rows: [AnyView] = []
        for species in [PetSpecies.penguin, .cat] {
            let identity = PetIdentity(species: species)
            for mood in Mood.allCases {
                let base = PetStateResolver.resolve(mood: mood, identity: identity)
                let hello = PetReaction.tap(on: base, streak: 1)
                let giggle = PetReaction.tap(on: base, streak: 2)
                let dizzy = PetReaction.tap(on: base, streak: 6)
                let frames: [(String, AnyView)] = [
                    ("rest", AnyView(PetSceneView(identity: identity, state: base, time: 1.7, petScale: 0.9, showsFloor: false, showsBackground: false))),
                    ("hello 1", AnyView(PetSceneView(identity: identity, state: hello.first, time: 1.7, petScale: 0.9, showsFloor: false, showsBackground: false))),
                    ("hello 2", AnyView(PetSceneView(identity: identity, state: hello.second, time: 1.7, petScale: 0.9, showsFloor: false, showsBackground: false))),
                    ("giggle 1", AnyView(PetSceneView(identity: identity, state: giggle.first, time: 1.7, petScale: 0.9, showsFloor: false, showsBackground: false))),
                    ("giggle 2", AnyView(PetSceneView(identity: identity, state: giggle.second, time: 1.7, petScale: 0.9, showsFloor: false, showsBackground: false))),
                    ("dizzy 1", AnyView(PetSceneView(identity: identity, state: dizzy.first, time: 1.7, petScale: 0.9, showsFloor: false, showsBackground: false))),
                    ("dizzy 2", AnyView(PetSceneView(identity: identity, state: dizzy.second, time: 1.7, petScale: 0.9, showsFloor: false, showsBackground: false))),
                    ("petting", AnyView(PetSceneView(identity: identity, state: state.pettingOverlay(base), time: 1.7, petScale: 0.9, showsFloor: false, showsBackground: false))),
                    ("look ←", AnyView(PetSceneView(identity: identity, state: state.lookOverlay(base, target: CGPoint(x: -1, y: 0.3)), time: 1.7, petScale: 0.9, showsFloor: false, showsBackground: false))),
                    ("look ↗", AnyView(PetSceneView(identity: identity, state: state.lookOverlay(base, target: CGPoint(x: 0.8, y: -1)), time: 1.7, petScale: 0.9, showsFloor: false, showsBackground: false))),
                ]
                rows.append(AnyView(strip("\(species.defaultName) · \(mood.displayName)", frames: frames)))
            }
        }
        try write(VStack(alignment: .leading, spacing: 8) { ForEach(Array(rows.enumerated()), id: \.offset) { $0.element } }, name: "tap-reactions")
    }

    /// The pet's own day: every life activity for every species, mid-bit, with its prop.
    @Test func lifeActivities() throws {
        var rows: [AnyView] = []
        for species in PetSpecies.allCases {
            let identity = PetIdentity(species: species)
            var frames: [(String, AnyView)] = []
            for activity in PetLife.allCases {
                let state = activity.state(identity: identity)
                let window = bitWindow(state.motion) ?? (0, 1)
                for k in [0.0, 0.3, 0.7] {
                    let t = window.start + window.duration * k
                    frames.append(("\(activity.rawValue) \(String(format: "%.0f", k * 100))%", AnyView(PetSceneView(identity: identity, state: state, time: t, petScale: 0.9, petVerticalPosition: 0.5, showsFloor: false, showsBackground: false))))
                }
            }
            rows.append(AnyView(strip(species.defaultName, frames: Array(frames.prefix(9)))))
            rows.append(AnyView(strip("", frames: Array(frames.dropFirst(9)))))
        }
        try write(VStack(alignment: .leading, spacing: 8) { ForEach(Array(rows.enumerated()), id: \.offset) { $0.element } }, name: "life")
    }

    /// The widget families as they look at five moments with no fresh mood: the pet's day on the
    /// Home Screen and Lock Screen, including the room's light at each hour.
    @Test func widgetsThroughTheDay() throws {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        var rows: [AnyView] = []
        let identity = PetIdentity(species: .penguin)
        let stale = PetSnapshot(identity: identity, mood: .calm, intensity: .moderate, loggedAt: .now.addingTimeInterval(-40 * 3600))
        for hour in [7, 11, 15, 20, 23] {
            var c = cal.dateComponents([.year, .month, .day], from: .now); c.hour = hour; c.minute = 15
            let date = cal.date(from: c)!
            // Lock Screen families need a real widget host (AccessoryWidgetBackground); the small
            // Home Screen widget and the room are enough to check the schedule and the light.
            let state = stale.state(at: date, calendar: cal)
            let frames: [(String, AnyView)] = [
                ("\(hour):15 room", AnyView(ZStack { PetRoom(mood: nil, date: date, horizon: 0.77, showsFoliage: false); PetSceneView(identity: identity, state: state, time: nil, petScale: 0.70, petVerticalPosition: 0.53, showsFloor: false, showsBackground: false, date: date) }.frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: 20)))),
                ("face", AnyView(PetView(identity: identity, state: state, showsShadow: false, framing: .face).frame(width: 48, height: 48))),
                ("badge", AnyView(PetView(identity: identity, state: state, showsShadow: false, framing: .badge).frame(width: 28, height: 28))),
            ]
            rows.append(AnyView(strip(PetLife.activity(at: date, calendar: cal).rawValue, frames: frames)))
        }
        try write(VStack(alignment: .leading, spacing: 8) { ForEach(Array(rows.enumerated()), id: \.offset) { $0.element } }, name: "widgets-day")
    }

    /// Species × mood × intensity at rest, the full matrix, for silhouette and expression review.
    @Test func restMatrix() throws {
        var rows: [AnyView] = []
        for species in PetSpecies.allCases {
            let identity = PetIdentity(species: species)
            var frames: [(String, AnyView)] = []
            for mood in Mood.allCases {
                for intensity in MoodIntensity.allCases {
                    let state = PetStateResolver.resolve(mood: mood, intensity: intensity, identity: identity)
                    frames.append(("\(mood.displayName) \(intensity.rawValue)", AnyView(PetSceneView(identity: identity, state: state, time: 1.7, petScale: 0.9, petVerticalPosition: 0.5, showsFloor: false, showsBackground: false))))
                }
            }
            rows.append(AnyView(strip(species.defaultName, frames: Array(frames.prefix(12)))))
            rows.append(AnyView(strip("", frames: Array(frames.dropFirst(12)))))
        }
        try write(VStack(alignment: .leading, spacing: 8) { ForEach(Array(rows.enumerated()), id: \.offset) { $0.element } }, name: "rest-matrix")
    }
}
