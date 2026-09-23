import Foundation

enum LabCheck {
    static func choices() {
        let stances: [PetStance] = Mood.allCases.map { .mood($0, .moderate) } + PetActivity.allCases.map { .life($0) }
        for st in stances {
            let list = st.repertoire(.dog)
            var prev: PetVignette?
            var fails = 0
            for slot in 0..<300 { let v = PetDirector.choice(list, slot: slot); if v == prev { fails += 1 }; prev = v }
            if fails > 0 { print(st, list.map(\.rawValue), "repeats:", fails, PetDirector.shuffled(list.count, seed: 3)) }
        }
    }
}
