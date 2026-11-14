import Foundation

/// Contact constraints are applied after acting: a prop has an owner, not an averaged position
/// between whatever the two paws happen to be doing. Gestures use the free paw while the
/// supporting paw keeps its grip. Floor props have no body constraint.
public enum PetContact {
    public static func pose(_ source: PetPose, holding prop: PetProp?, species: PetSpecies) -> PetPose {
        var p = source
        switch prop {
        case .mug:
            p.armL = -57 - p.propLift * (species == .penguin ? 34 : 22)
        case .book:
            p.armL = -45
        case .blanket:
            p.armL = -58; p.armR = -58
        case .heldBall:
            p.armL = -55; p.armR = -55
        case .snack:
            p.armL = -78; p.armR = -78
        case .laptop, .ball, nil:
            break
        }
        return p
    }
}
