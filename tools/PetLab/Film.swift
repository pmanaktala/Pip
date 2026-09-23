import SwiftUI

/// Filmstrips: a clip played over a stance, sampled evenly.
enum LabFilm {
    struct Row: Identifiable { let id = UUID(); var title: String; var frames: [(PetPose, PetProp?)] }

    @MainActor static func strips(species: PetSpecies, rows: [Row], size: CGFloat = 120) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows) { row in
                HStack(spacing: 2) {
                    Text(row.title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.black).frame(width: 90, alignment: .leading)
                    ForEach(row.frames.indices, id: \.self) { i in
                        LabPet(species: species, pose: row.frames[i].0, prop: row.frames[i].1)
                            .frame(width: size, height: size).background(Color(red: 0.93, green: 0.95, blue: 0.97))
                    }
                }
            }
        }.padding(10).background(Color.white)
    }

    static func sample(_ clip: PetClip, stance: PetStance, species: PetSpecies, frames n: Int = 9) -> Row {
        let rest = stance.rest(species)
        var out: [(PetPose, PetProp?)] = []
        for i in 0..<n {
            let t = clip.duration * Double(i) / Double(n - 1)
            out.append((clip.apply(to: rest, at: t).clamped(), stance.prop))
        }
        return Row(title: clip.name, frames: out)
    }

    static func reactions(_ s: PetSpecies) -> [Row] {
        Mood.allCases.map { m in
            var r = sample(PetClips.reaction(to: m, s), stance: .mood(m, .moderate), species: s)
            r.title = "→ \(m.rawValue)"
            return r
        } + [sample(PetClips.arrive(.mood(.neutral, .moderate), s), stance: .mood(.neutral, .moderate), species: s),
             sample(PetClips.boop(s), stance: .mood(.happy, .moderate), species: s),
             sample(PetClips.tickle(s), stance: .mood(.neutral, .moderate), species: s),
             sample(PetClips.flustered(s), stance: .mood(.neutral, .moderate), species: s)]
    }

    static func vignettes(_ s: PetSpecies) -> [Row] {
        PetVignette.allCases.map { v in
            let stance: PetStance = switch v {
            case .sip: .mood(.calm, .moderate)
            case .pageTurn, .chuckle: .life(.reading)
            case .snore, .stir: .life(.sleeping)
            case .batBall: .life(.playing)
            case .patSpot, .lookUpSmile: .mood(.sad, .moderate)
            case .nodOff, .rubEye, .yawn: .mood(.tired, .moderate)
            case .huff, .stomp: .mood(.frustrated, .moderate)
            default: .mood(.neutral, .moderate)
            }
            return sample(PetClips.vignette(v, s), stance: stance, species: s)
        }
    }

    /// The director over time, for a stance: what a viewer would actually see.
    static func director(_ s: PetSpecies, stance: PetStance, seconds: Double, frames n: Int = 12, start: Double = 1_800_000_000) -> Row {
        let scene = PetScene(species: s, stance: stance)
        var out: [(PetPose, PetProp?)] = []
        for i in 0..<n {
            let t = start + seconds * Double(i) / Double(n - 1)
            out.append((PetDirector.pose(scene, at: Date(timeIntervalSince1970: t)), scene.prop))
        }
        return Row(title: "\(stance)".replacingOccurrences(of: "PipCore.", with: ""), frames: out)
    }
}

enum LabTokens {
    @MainActor static func sheet() -> some View {
        VStack(spacing: 10) {
            ForEach(PetSpecies.allCases, id: \.self) { s in
                HStack(spacing: 10) {
                    ForEach(Mood.allCases, id: \.self) { m in
                        VStack(spacing: 2) {
                            LabPet(species: s, pose: PetStance.tokenFace(m, s), detail: .badge)
                                .frame(width: 66, height: 66).background(Circle().fill(m.tint.alpha(0.2).color))
                            LabPet(species: s, pose: PetStance.tokenFace(m, s), detail: .badge)
                                .frame(width: 30, height: 30)
                            Text(m.displayName).font(.system(size: 10)).foregroundStyle(.black)
                        }
                    }
                }
            }
        }.padding(12).background(Color.white)
    }
}

enum LabCast {
    @MainActor static func sheet() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(PetSpecies.allCases, id: \.self) { s in
                HStack(spacing: 10) {
                    ForEach(Mood.allCases, id: \.self) { m in
                        let st = PetStance.mood(m, .moderate)
                        VStack(spacing: 4) {
                            LabPet(species: s, pose: st.holds(s)[0], prop: st.prop).frame(width: 150, height: 150)
                            LabPet(species: s, pose: PetStance.tokenFace(m, s), detail: .badge).frame(width: 40, height: 40)
                                .background(Circle().fill(m.tint.alpha(0.2).color))
                            Text("\(s.defaultName) · \(m.displayName)").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.black)
                        }
                    }
                }
            }
        }
        .padding(24).background(Color(red: 0.96, green: 0.95, blue: 0.93))
    }
}
