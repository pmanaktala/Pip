import Testing
@testable import Pip

struct PetStateResolverTests {
    @Test func everyMoodResolvesForEveryIntensityAndSpecies() {
        for species in PetSpecies.allCases {
            for mood in Mood.allCases {
                for intensity in MoodIntensity.allCases {
                    let state = PetStateResolver.resolve(mood: mood, intensity: intensity, species: species, personality: species.defaultPersonality)
                    #expect(state.mood == mood)
                    #expect(state.intensity == intensity)
                    #expect((0...1).contains(state.rig.eyeOpen))
                    #expect((-1...1).contains(state.rig.mouthCurve))
                }
            }
        }
    }

    @Test func intensityScalesExpression() {
        let id = PetIdentity(species: .cat)
        let slight = PetStateResolver.resolve(mood: .sad, intensity: .slight, identity: id)
        let strong = PetStateResolver.resolve(mood: .sad, intensity: .strong, identity: id)
        #expect(strong.rig.mouthCurve < slight.rig.mouthCurve)
        #expect(strong.rig.earLift < slight.rig.earLift)
    }

    @Test func personalityChangesReaction() {
        let dramatic = PetStateResolver.resolve(mood: .stressed, intensity: .strong, species: .cat, personality: .dramatic)
        let serene = PetStateResolver.resolve(mood: .stressed, intensity: .strong, species: .cat, personality: .serene)
        #expect(dramatic.rig.lying > serene.rig.lying)
        #expect(dramatic.motion.shiver > serene.motion.shiver)

        let optimistic = PetStateResolver.resolve(mood: .sad, intensity: .strong, species: .dog, personality: .optimistic)
        #expect(optimistic.rig.mouthCurve >= -0.15)
    }

    @Test func rigVectorRoundTrips() {
        let state = PetStateResolver.resolve(mood: .excited, intensity: .strong, identity: PetIdentity(species: .penguin))
        var copy = PetRig()
        copy.vector = state.rig.vector
        #expect(copy == state.rig)
    }

    @Test func moodValenceOrdering() {
        #expect(Mood.excited.valence > Mood.neutral.valence)
        #expect(Mood.neutral.valence > Mood.sad.valence)
        #expect(Mood.allCases.count == 8)
    }
}
