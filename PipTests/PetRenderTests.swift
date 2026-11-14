import SwiftUI
import Testing
import UIKit
import WidgetKit
@testable import Pip

/// Contact sheets from the real renderer, on the simulator. Set `PIP_ART_OUTPUT` to a path to
/// write one (every species in every stance at 150, 60 and 28 pt). PetLab (`tools/PetLab`)
/// renders the same art on the Mac for faster review.
@MainActor
@Suite(.serialized)
struct PetRenderTests {
    @Test func contactSheetRenders() throws {
        let stances: [PetStance] = Mood.allCases.map { .mood($0, .moderate) } + [.life(.reading), .life(.sleeping), .life(.playing)]
        let content = VStack(alignment: .leading, spacing: 10) {
            ForEach(PetSpecies.allCases) { species in
                HStack(spacing: 8) {
                    ForEach(stances, id: \.self) { stance in
                        VStack(spacing: 3) {
                            PetView(species: species, stance: stance).frame(width: 150, height: 150)
                            HStack(spacing: 4) {
                                PetView(species: species, stance: stance, framing: .face, showsShadow: false).frame(width: 60, height: 60)
                                PetView(species: species, stance: stance, framing: .badge, showsShadow: false).frame(width: 28, height: 28)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(red: 0.94, green: 0.95, blue: 0.97))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        #expect(image.size.width > 1000)
        if let path = ProcessInfo.processInfo.environment["PIP_ART_OUTPUT"] {
            try #require(image.pngData()).write(to: URL(fileURLWithPath: path))
        }
    }
    /// Actual shared widget views, not an imitation of their layouts. Exported for optical QA.
    @Test func companionSurfaceSheetsRender() throws {
        guard let output = ProcessInfo.processInfo.environment["PIP_SURFACE_OUTPUT"] else { return }
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 14))!
        // Export appearances in separate test invocations: repeated ImageRenderer passes
        // can reuse incomplete Canvas display lists on the iOS 27 simulator.
        let scheme: ColorScheme = ProcessInfo.processInfo.environment["PIP_SURFACE_SCHEME"] == "dark" ? .dark : .light
        do {
            let sheet = VStack(alignment: .leading, spacing: 16) {
                ForEach(PetSpecies.allCases) { species in
                    let snapshot = PetSnapshot(identity: PetIdentity(species: species), mood: .calm,
                                               intensity: .moderate, loggedAt: date)
                    let moment = PetWidgetMoment(snapshot: snapshot, date: date)
                    HStack(alignment: .top, spacing: 12) {
                        PetHomeWidgetView(moment: moment, family: .systemSmall)
                            .background(PetRoom(mood: .calm, date: date, horizon: 0.8, showsFoliage: false))
                            .frame(width: 170, height: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        VStack(spacing: 12) {
                            PetHomeWidgetView(moment: moment, family: .systemMedium)
                                .background(PetRoom(mood: .calm, date: date, horizon: 0.84, showsFoliage: false))
                                .frame(width: 340, height: 170)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                            PetAccessoryView(moment: moment, family: .accessoryRectangular)
                                .frame(width: 170, height: 64)
                            PetAccessoryView(moment: moment, family: .accessoryCircular)
                                .frame(width: 60, height: 60)
                        }
                        PetHomeWidgetView(moment: moment, family: .systemLarge)
                            .background(PetRoom(mood: .calm, date: date, horizon: 0.5, showsFoliage: false))
                            .frame(width: 340, height: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        PetHomeWidgetView(moment: moment, family: .systemSmall, showsBackground: false)
                            .frame(width: 170, height: 170)
                    }
                }
            }
            .padding(20)
            .background(scheme == .dark ? Color.black : Color(white: 0.96))
            .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: sheet)
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            try #require(image.pngData()).write(to: URL(fileURLWithPath: output + (scheme == .dark ? "-dark.png" : "-light.png")))
        }
    }

    @Test func featureScreensRender() async throws {
        guard let output = ProcessInfo.processInfo.environment["PIP_FEATURE_OUTPUT"] else { return }
        let scheme: ColorScheme = ProcessInfo.processInfo.environment["PIP_SURFACE_SCHEME"] == "dark" ? .dark : .light
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        // One hosted screen per process avoids changing an active SwiftUI root during capture.
        let name = ProcessInfo.processInfo.environment["PIP_FEATURE_SCREEN"] ?? "home"
        let content: AnyView
        switch name {
        case "picker": content = AnyView(PreviewHost { MoodPickerSheet() })
        case "history": content = AnyView(PreviewHost { NavigationStack { HistoryView() } })
        case "pets": content = AnyView(PreviewHost { NavigationStack { PetSelectorView() } })
        case "onboarding": content = AnyView(PreviewHost(seeded: false) { OnboardingView() })
        case "settings": content = AnyView(PreviewHost { NavigationStack { SettingsView() } })
        case "play": content = AnyView(PreviewHost { PlayView() })
        default: content = AnyView(PreviewHost { PetHomeView() })
        }
        let controller = UIHostingController(rootView: content)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(400))
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        try #require(image.pngData()).write(to: URL(fileURLWithPath: output + "-" + name + (scheme == .dark ? "-dark.png" : "-light.png")))
    }

}
