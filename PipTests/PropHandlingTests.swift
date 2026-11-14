import CoreGraphics
import Foundation
import Testing
@testable import Pip

@Suite struct PropHandlingTests {
    private let start = Date(timeIntervalSince1970: 1000)

    @Test func oldObjectsLandBeforeNewObjectsArePickedUp() throws {
        for species in PetSpecies.allCases {
            for style in PetArtStyle.allCases {
                for pair in [(PetProp.mug, PetProp.book), (.book, .mug)] {
                    let old = PetContact.pose(.zero, holding: pair.0, species: species)
                    var plan = PetPropHandling(prop: pair.0)
                    plan.request(pair.1, at: start, source: old, species: species, style: style)
                    let deposit = try #require(plan.steps.first)
                    #expect(deposit.action == .putDown(pair.0))
                    let landed = plan.frame(at: deposit.end, base: old, fallback: pair.1, species: species, style: style)
                    #expect(landed.prop == nil)
                    #expect(landed.stage.carried == nil)
                    #expect(plan.steps.firstIndex(where: { $0.action == .pickUp(pair.1) })! > 0)
                    let done = plan.frame(at: try #require(plan.end), base: old, fallback: pair.1, species: species, style: style)
                    #expect(done.prop == pair.1)
                    #expect(!done.handling)
                }
            }
        }
    }

    @Test func carriesKeepPawsOnObjectsAndNeverGoBelowTheirSupport() throws {
        for species in PetSpecies.allCases {
            for style in PetArtStyle.allCases {
                for prop in [PetProp.mug, .book] {
                    var pose = PetPose.zero
                    pose.lean = -12; pose.slump = 0.4; pose.headTilt = 8
                    pose = PetContact.pose(pose, holding: prop, species: species)
                    var plan = PetPropHandling(prop: prop)
                    plan.request(nil, at: start, source: pose, species: species, style: style)
                    let segment = try #require(plan.steps.first)
                    for tick in 0..<100 {
                        let date = start.addingTimeInterval(Double(tick) / 100 * segment.action.duration)
                        let frame = plan.frame(at: date, base: pose, fallback: nil, species: species, style: style)
                        #expect(frame.prop == prop)
                        let hand = PetBodyGeometry.leftHand(frame.pose, species: species, style: style)
                        #expect(abs(hand.x - frame.pose.leftHandX) < 0.001)
                        #expect(abs(hand.y - frame.pose.leftHandY) < 0.001)
                        let bottom = hand.y + (prop == .mug ? 6 : 10 * (1 - frame.pose.bookClose * 0.8))
                        #expect(bottom <= (prop == .mug ? 148 : 168) + 0.01)
                    }
                }
            }
        }
    }

    @Test func rapidInterruptionsKeepCurrentCarryAndRouteToLatestRequest() throws {
        for species in PetSpecies.allCases {
            let pose = PetContact.pose(.zero, holding: .mug, species: species)
            var plan = PetPropHandling(prop: .mug)
            plan.request(.book, at: start, source: pose, species: species, style: .illustrated)
            let active = try #require(plan.steps.first)
            let interrupt = start.addingTimeInterval(0.3)
            let before = plan.frame(at: interrupt, base: pose, fallback: .book, species: species, style: .illustrated)
            plan.request(.mug, at: interrupt, source: pose, species: species, style: .illustrated)
            let after = plan.frame(at: interrupt, base: pose, fallback: .mug, species: species, style: .illustrated)
            #expect(plan.steps.first == active)
            #expect(before.prop == after.prop)
            #expect(before.pose.leftHandX == after.pose.leftHandX)
            #expect(before.pose.leftHandY == after.pose.leftHandY)
            #expect(!plan.steps.contains(where: { $0.action == .pickUp(.book) }))
            #expect(plan.frame(at: try #require(plan.end), base: pose, fallback: .mug, species: species, style: .illustrated).prop == .mug)
        }
    }

    @Test func everyPhaseRemainsContinuousWhenTheRequestedBodyPoseChanges() throws {
        for species in PetSpecies.allCases {
            for style in PetArtStyle.allCases {
                for time in [0.2, 0.65, 1.35, 1.8, 2.4] {
                    let old = PetContact.pose(PetStance.mood(.calm, .moderate).rest(species), holding: .mug, species: species)
                    let reading = PetStance.life(.reading).rest(species)
                    let stressed = PetStance.mood(.stressed, .strong).rest(species)
                    var plan = PetPropHandling(prop: .mug)
                    plan.request(.book, at: start, source: old, species: species, style: style)
                    let now = start.addingTimeInterval(time)
                    let before = plan.frame(at: now, base: reading, fallback: .book, species: species, style: style)
                    plan.request(nil, at: now, source: reading, species: species, style: style)
                    let after = plan.frame(at: now, base: stressed, fallback: nil, species: species, style: style)
                    #expect(before.prop == after.prop)
                    #expect(abs(before.pose.leftHandX - after.pose.leftHandX) < 0.001)
                    #expect(abs(before.pose.leftHandY - after.pose.leftHandY) < 0.001)
                    #expect(abs(before.pose.lean - after.pose.lean) < 0.001)
                    #expect(abs(before.pose.lift - after.pose.lift) < 0.001)
                }
            }
        }
    }

    @Test func plansStayBoundedAndObjectsHaveOneOwner() throws {
        var plan = PetPropHandling(prop: nil)
        let pose = PetPose.zero
        for tick in 0..<300 {
            let now = start.addingTimeInterval(Double(tick) * 0.16)
            let target: PetProp? = tick % 3 == 0 ? nil : (tick % 3 == 1 ? .book : .mug)
            plan.request(target, at: now, source: pose, species: .cat, style: .illustrated)
            #expect(plan.steps.count < 10)
            let frame = plan.frame(at: now, base: pose, fallback: target, species: .cat, style: .illustrated)
            if let prop = frame.prop { #expect(frame.stage.carried == prop) }
        }
    }

    @Test func aSleepingPetStandsBeforeReachingForAnObject() throws {
        for species in PetSpecies.allCases {
            let asleep = PetStance.life(.sleeping).rest(species)
            let awake = PetStance.mood(.calm, .moderate).rest(species)
            var plan = PetPropHandling(prop: nil)
            plan.request(.mug, at: start, source: asleep, species: species, style: .illustrated)
            let prepare = try #require(plan.steps.first)
            #expect(prepare.action == .prepare(.mug))
            let initial = plan.frame(at: start, base: awake, fallback: .mug, species: species, style: .illustrated)
            #expect(initial.pose.recline == 1)
            #expect(initial.prop == nil)
            let middle = plan.frame(at: start.addingTimeInterval(prepare.action.duration / 2), base: awake, fallback: .mug, species: species, style: .illustrated)
            #expect(abs(middle.pose.recline - 0.5) < 0.001)
            let reach = plan.frame(at: prepare.end, base: awake, fallback: .mug, species: species, style: .illustrated)
            #expect(reach.pose.recline == 0)
            #expect(reach.prop == nil)
        }
    }

    @Test func cancelledWakeupSettlesBackToSleepWithoutAPoseJump() throws {
        let asleep = PetStance.life(.sleeping).rest(.penguin)
        let awake = PetStance.mood(.calm, .moderate).rest(.penguin)
        var plan = PetPropHandling(prop: nil)
        plan.request(.mug, at: start, source: asleep, species: .penguin, style: .illustrated)
        let prepareEnd = try #require(plan.steps.first).end
        plan.request(nil, at: start.addingTimeInterval(0.2), source: awake, species: .penguin, style: .illustrated)
        let justBefore = plan.frame(at: prepareEnd.addingTimeInterval(-0.00001), base: asleep, fallback: .blanket, species: .penguin, style: .illustrated)
        let justAfter = plan.frame(at: prepareEnd, base: asleep, fallback: .blanket, species: .penguin, style: .illustrated)
        #expect(abs(justBefore.pose.recline - justAfter.pose.recline) < 0.001)
        #expect(justAfter.pose.recline == 0)
        #expect(!plan.steps.contains(where: { $0.action == .pickUp(.mug) }))
        let end = plan.frame(at: try #require(plan.end), base: asleep, fallback: .blanket, species: .penguin, style: .illustrated)
        #expect(end.pose.recline == 1)
        #expect(!end.handling)
    }

    @Test func geometryMatchesTheCanvasBodyTransform() throws {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        var p = PetPose.zero
        p.x = 7; p.lift = 9; p.lean = -17; p.squash = 0.4; p.slump = 0.6
        let floor = PetFigure.floor, lean = CGFloat(p.lean * .pi / 180), sq = CGFloat(p.squash) * 0.14
        context.translateBy(x: CGFloat(p.x), y: -CGFloat(p.lift))
        context.concatenate(CGAffineTransform(a: 1, b: 0, c: -tan(lean) * 0.75, d: 1, tx: tan(lean) * 0.75 * floor, ty: 0))
        context.translateBy(x: 100, y: floor)
        context.rotate(by: lean * 0.25)
        context.scaleBy(x: 1 + sq, y: 1 - sq - CGFloat(p.slump) * 0.05)
        context.translateBy(x: -100, y: -floor)
        let actual = PetBodyGeometry.transform(p, style: .original)
        for point in [CGPoint.zero, CGPoint(x: 100, y: 170), CGPoint(x: 70, y: 110)] {
            let a = point.applying(actual), b = point.applying(context.ctm)
            #expect(abs(a.x - b.x) < 0.001)
            #expect(abs(a.y - b.y) < 0.001)
        }
    }
}
