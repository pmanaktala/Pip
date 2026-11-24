import CoreGraphics
import Foundation
import Testing
@testable import Pip

struct BlanketHandlingTests {
    private let start = Date(timeIntervalSince1970: 2000)

    @Test func bothPawsKeepTheirFabricCornersDuringEveryPhase() throws {
        for species in PetSpecies.allCases {
            for style in PetArtStyle.allCases {
                for incoming in [true, false] {
                    let source = incoming ? PetStance.mood(.calm, .moderate).rest(species) : PetStance.mood(.sad, .moderate).rest(species)
                    let target = incoming ? PetStance.mood(.sad, .moderate).rest(species) : PetStance.life(.reading).rest(species)
                    var plan = PetPropHandling(prop: incoming ? .mug : .blanket)
                    plan.request(incoming ? .blanket : .book, at: start, source: source, species: species, style: style)
                    let duration = try #require(plan.end).timeIntervalSince(start)
                    for index in 0...160 {
                        let frame = plan.frame(at: start.addingTimeInterval(Double(index) / 160 * duration), base: target,
                                               fallback: incoming ? .blanket : .book, species: species, style: style)
                        guard frame.prop == .blanket else { continue }
                        #expect(frame.stage.carried == .blanket)
                        let paint = PetPaint(species: species, pose: frame.pose, prop: .blanket, style: style, staging: frame.stage)
                        let panels = PetBlanketGeometry.panels(paint.pose, species: species, style: style)
                        for (panel, side) in zip(panels, [CGFloat(-1), 1]) {
                            let hand = PetBodyGeometry.hand(paint.pose, species: species, style: style, side: side)
                            #expect(abs(panel.grip.x - hand.x) < 0.001)
                            #expect(abs(panel.grip.y - hand.y) < 0.001)
                            for p in [panel.grip, panel.shoulder, panel.crown, panel.outerHem, panel.outerControl,
                                      panel.innerHem, panel.hemControl, panel.chest, panel.chestControl] {
                                #expect(p.y <= PetFigure.floor + 0.001)
                            }
                        }
                        if paint.pose.blanketFold == 1 {
                            #expect(abs(panels[1].grip.x - panels[0].grip.x - 32) < 0.001)
                            #expect(abs(panels[1].grip.y - panels[0].grip.y) < 0.001)
                        }
                    }
                }
            }
        }
    }

    @Test func lowerShelfItemsLeaveTheCompartmentBeforeRising() throws {
        for species in PetSpecies.allCases {
            for style in PetArtStyle.allCases {
                for prop in [PetProp.book, .blanket] {
                    let held = PetContact.pose(PetPose.zero, holding: prop, species: species)
                    for incoming in [true, false] {
                        var plan = PetPropHandling(prop: incoming ? nil : prop)
                        plan.request(incoming ? prop : nil, at: start, source: held, species: species, style: style)
                        let duration = try #require(plan.end).timeIntervalSince(start)
                        let shelf = PetPropStage.grip(for: prop)
                        for index in 0...180 {
                            let frame = plan.frame(at: start.addingTimeInterval(Double(index) / 180 * duration), base: held,
                                                   fallback: incoming ? prop : nil, species: species, style: style)
                            guard frame.prop == prop else { continue }
                            let hand = PetBodyGeometry.leftHand(frame.pose, species: species, style: style)
                            if hand.x < 60 {
                                #expect(abs(hand.y - shelf.y) < 0.001)
                                #expect(prop == .book ? frame.pose.bookClose == 1 : frame.pose.blanketFold == 1)
                            }
                        }
                    }
                }
            }
        }
    }

    @Test func foldedBlanketFitsItsSupportAndSleepKeepsItParked() {
        for species in PetSpecies.allCases {
            for style in PetArtStyle.allCases {
                var pose = PetPose.zero
                pose.leftHandIK = 1; pose.rightHandIK = 1; pose.blanketFold = 1
                pose.leftHandX = 20; pose.rightHandX = 52
                pose.leftHandY = 152; pose.rightHandY = 152
                let panels = PetBlanketGeometry.panels(pose, species: species, style: style)
                for panel in panels {
                    #expect(panel.grip.y == 152)
                    #expect(panel.outerHem.y == 158)
                    #expect(panel.innerHem.y == 158)
                }
            }
            let scene = PetScene(species: species, stance: .life(.sleeping))
            #expect(scene.handlingProp(style: .illustrated) == nil)
            #expect(scene.handlingProp(style: .original) == .blanket)
            var originalSleep = PetPropHandling(prop: .blanket)
            originalSleep.request(.book, at: start, source: PetStance.life(.sleeping).rest(species), species: species, style: .original)
            #expect(originalSleep.steps.first?.action == .putDown(.blanket))
            #expect(!originalSleep.steps.contains(where: { $0.action == .prepare(.book) }))
            let sad = PetScene(species: species, stance: .mood(.sad, .moderate))
            #expect(sad.prop == scene.prop)
            #expect(sad.handlingProp(style: .illustrated) == .blanket)
            #expect(sad.handlingProp(style: .illustrated) != scene.handlingProp(style: .illustrated))
        }
    }

    @Test func rapidChangesPreserveBothGripsAndTheFold() throws {
        for species in PetSpecies.allCases {
            for style in PetArtStyle.allCases {
                let sad = PetStance.mood(.sad, .moderate).rest(species)
                let reading = PetStance.life(.reading).rest(species)
                for initial in [PetProp.mug, .blanket] {
                    for delay in [0.15, 0.75, 1.3, 1.8, 2.5, 2.9] {
                        let first: PetProp = initial == .mug ? .blanket : .book
                        var plan = PetPropHandling(prop: initial)
                        plan.request(first, at: start, source: sad, species: species, style: style)
                        let now = start.addingTimeInterval(delay)
                        let before = plan.frame(at: now, base: sad, fallback: first, species: species, style: style)
                        plan.request(.mug, at: now, source: sad, species: species, style: style)
                        let after = plan.frame(at: now, base: reading, fallback: .mug, species: species, style: style)
                        #expect(before.prop == after.prop)
                        if before.handling {
                            #expect(abs(before.pose.leftHandX - after.pose.leftHandX) < 0.001)
                            #expect(abs(before.pose.rightHandX - after.pose.rightHandX) < 0.001)
                            #expect(abs(before.pose.blanketFold - after.pose.blanketFold) < 0.001)
                        }
                        #expect(plan.steps.count < 10)
                        #expect(plan.frame(at: try #require(plan.end), base: sad, fallback: .mug, species: species, style: style).prop == .mug)
                    }
                }
            }
        }
    }
}
