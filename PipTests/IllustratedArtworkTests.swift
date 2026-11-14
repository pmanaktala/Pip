import Foundation
import SwiftUI
import Testing
@testable import Pip

struct IllustratedArtworkTests {
    @Test func gripCoordinatesStayCompatibleAcrossArtStyles() {
        // Every authored held-prop keyframe must remain on the same paw after a style change.
        for species in PetSpecies.allCases {
            let old = PetFigure.of(species, style: .original)
            let new = PetFigure.of(species, style: .illustrated)
            for prop in [PetProp.mug, .book, .blanket, .heldBall, .snack] {
                for lift in [0.0, 0.5, 1.0] {
                    var source = PetPose.zero
                    source.propLift = lift
                    let pose = PetContact.pose(source, holding: prop, species: species)
                    #expect(old.paw(species, angle: pose.armL) == new.paw(species, angle: pose.armL))
                    if [.blanket, .heldBall, .snack].contains(prop) {
                        #expect(old.paw(species, angle: pose.armR) == new.paw(species, angle: pose.armR))
                    }
                }
            }
        }
    }

    @Test func sleepingSettlesContinuouslyAndWakingStandsUp() {
        for species in PetSpecies.allCases {
            let awake = PetStance.mood(.neutral, .moderate).rest(species)
            for activity in [PetActivity.sleeping, .napping] {
                let asleep = PetStance.life(activity).rest(species)
                #expect(awake.recline == 0)
                #expect(asleep.recline == 1)
                #expect(PetPose.mix(awake, asleep, 0.5).recline == 0.5)
                var animated = awake
                animated.vector = asleep.vector
                #expect(animated.recline == 1)
            }
            #expect(PetStance.life(.waking).rest(species).recline == 0)
        }
    }

    @MainActor @Test func bothRigsRenderEveryMoodAndActivity() throws {
        let stances = Mood.allCases.flatMap { mood in MoodIntensity.allCases.map { PetStance.mood(mood, $0) } }
            + PetActivity.allCases.map { PetStance.life($0) } + [.meditating]
        for style in PetArtStyle.allCases {
            for species in PetSpecies.allCases {
                for stance in stances {
                    let scene = PetScene(species: species, stance: stance)
                    let pose = PetDirector.hold(scene)
                    let image = ImageRenderer(content: Canvas { ctx, _ in
                        PetRenderer.draw(ctx, PetPaint(species: species, pose: pose, prop: scene.prop, wear: scene.wear, style: style))
                    }.frame(width: 200, height: 200))
                    #expect(try #require(image.uiImage).size.width == 200)
                }
            }
        }
    }
}
