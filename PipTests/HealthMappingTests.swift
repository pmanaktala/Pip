import HealthKit
import Testing
@testable import Pip

struct HealthMappingTests {
    @Test func everyMoodHasALabel() {
        let labels = Mood.allCases.map(HealthMapping.label(for:))
        #expect(Set(labels).count == Mood.allCases.count)
        #expect(HealthMapping.label(for: .tired) == .drained)
        #expect(HealthMapping.label(for: .neutral) == .indifferent)
    }

    @Test func contextsMapToAssociations() {
        #expect(HealthMapping.association(for: .relationship) == .partner)
        #expect(HealthMapping.association(for: .social) == .community)
        #expect(HealthMapping.association(for: .random) == nil)
        for c in MoodContext.allCases where c != .random {
            #expect(HealthMapping.association(for: c) != nil)
        }
    }

    @Test func valenceScalesWithIntensityAndStaysInRange() {
        #expect(HealthMapping.valence(for: .excited, intensity: .strong) <= 1)
        #expect(HealthMapping.valence(for: .sad, intensity: .strong) >= -1)
        #expect(HealthMapping.valence(for: .sad, intensity: .strong) < HealthMapping.valence(for: .sad, intensity: .slight))
        #expect(HealthMapping.valence(for: .neutral, intensity: .strong) == 0)
    }

    @Test func sampleCarriesExternalUUID() {
        let entry = MoodEntry(mood: .stressed, intensity: .moderate, contexts: [.work, .random])
        let sample = HealthMapping.sample(for: entry)
        #expect(sample.metadata?[HKMetadataKeyExternalUUID] as? String == entry.id.uuidString)
        #expect(sample.labels == [.stressed])
        #expect(sample.associations == [.work])
        #expect(sample.kind == .momentaryEmotion)
    }
}
