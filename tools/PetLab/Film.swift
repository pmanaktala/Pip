import SwiftUI

/// Filmstrips: a clip played over a stance, sampled evenly.
enum LabFilm {
    struct Row: Identifiable {
        let id = UUID(); var title: String; var frames: [(PetPose, PetProp?)]; var wear: PetWear? = nil; var wears: [PetWear?]? = nil
    }

    @MainActor static func strips(species: PetSpecies, rows: [Row], size: CGFloat = 120) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows) { row in
                HStack(spacing: 2) {
                    Text(row.title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.black).frame(width: 90, alignment: .leading)
                    ForEach(row.frames.indices, id: \.self) { i in
                        LabPet(species: species, pose: row.frames[i].0, prop: row.frames[i].1, wear: row.wears?[i] ?? row.wear)
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

enum LabEyes {
    /// A blink frame by frame, and every closed-eye state, large.
    @MainActor static func sheet(_ s: PetSpecies) -> some View {
        let rest = PetStance.mood(.neutral, .moderate).rest(s)
        let blinks: [(String, PetPose)] = [0, 0.3, 0.6, 0.85, 1, 0.6, 0.2].map { b in var p = rest; p.blink = b; return ("blink \(b)", p) }
        let closed: [(String, PetPose)] = [
            ("sleeping", PetStance.life(.sleeping).rest(s)), ("napping", PetStance.life(.napping).rest(s)),
            ("meditating", PetStance.meditating.rest(s)), ("calm token", PetStance.tokenFace(.calm, s)),
            ("tired", PetStance.mood(.tired, .moderate).rest(s)), ("lid 0.5", { var p = rest; p.lidL = 0.5; p.lidR = 0.5; return p }()),
            ("happy ^", { var p = rest; p.smileEyes = 1; return p }()),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            ForEach([blinks, closed].indices, id: \.self) { r in
                let row = [blinks, closed][r]
                HStack(spacing: 6) {
                    ForEach(row.indices, id: \.self) { i in
                        VStack(spacing: 2) {
                            LabPet(species: s, pose: row[i].1, detail: .face).frame(width: 190, height: 190)
                                .background(Color(red: 0.93, green: 0.95, blue: 0.97))
                            Text(row[i].0).font(.system(size: 11)).foregroundStyle(.black)
                        }
                    }
                }
            }
        }.padding(10).background(Color.white)
    }
}

enum LabSmile {
    @MainActor static func sheet() -> some View {
        VStack(spacing: 6) {
            ForEach(PetSpecies.allCases, id: \.self) { s in
                HStack(spacing: 6) {
                    ForEach([0, 0.2, 0.35, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0], id: \.self) { v in
                        let p: PetPose = { var p = PetStance.mood(.neutral, .moderate).rest(s); p.smileEyes = v; p.smile = v * 0.7; return p }()
                        VStack(spacing: 1) {
                            LabPet(species: s, pose: p, detail: .face).frame(width: 150, height: 150).background(Color(red: 0.93, green: 0.95, blue: 0.97))
                            Text("smileEyes \(v, specifier: "%.2f")").font(.system(size: 10)).foregroundStyle(.black)
                        }
                    }
                }
            }
        }.padding(8).background(Color.white)
    }
}

enum LabBlush {
    @MainActor static func sheet() -> some View {
        HStack(spacing: 8) {
            ForEach(PetSpecies.allCases, id: \.self) { s in
                ForEach([0.0, 0.6, 1.0], id: \.self) { e in
                    let p: PetPose = { var p = PetStance.mood(.happy, .moderate).rest(s); p.blush = 1; p.smileEyes = e; p.headTilt = 0; return p }()
                    LabPet(species: s, pose: p, detail: .face).frame(width: 220, height: 220).background(Color(red: 0.93, green: 0.95, blue: 0.97))
                }
            }
        }.padding(8).background(Color.white)
    }
}

enum LabFloorProps {
    @MainActor static func sheet() -> some View {
        let cases: [(PetStance, Double, Double)] = [(.life(.working), 0, 0), (.life(.working), 14, 0), (.life(.working), 0, 16), (.life(.playing), 0, 0), (.life(.playing), 16, 0), (.mood(.calm, .moderate), 12, 10)]
        return HStack(spacing: 6) {
            ForEach(cases.indices, id: \.self) { i in
                let (st, lift, lean) = cases[i]
                let p: PetPose = { var p = st.rest(.dog); p.lift = lift; p.lean = lean; return p }()
                LabPet(species: .dog, pose: p, prop: st.prop).frame(width: 170, height: 170).background(Color(red: 0.93, green: 0.95, blue: 0.97))
            }
        }.padding(8).background(Color.white)
    }
}

enum LabDog {
    @MainActor static func sheet() -> some View {
        let s = PetSpecies.dog
        let states: [PetStance] = [.mood(.neutral, .moderate), .mood(.happy, .moderate), .mood(.sad, .moderate), .life(.working)]
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(states.indices, id: \.self) { i in
                    LabPet(species: s, pose: states[i].holds(s)[0], prop: states[i].prop).frame(width: 300, height: 300)
                        .background(Color(red: 0.93, green: 0.95, blue: 0.97))
                }
            }
            HStack(spacing: 8) {
                ForEach(states.indices, id: \.self) { i in
                    LabPet(species: s, pose: states[i].holds(s)[0], detail: .face).frame(width: 300, height: 300)
                        .background(Color(red: 0.93, green: 0.95, blue: 0.97))
                }
            }
        }.padding(8).background(Color.white)
    }
}

enum LabActions {
    @MainActor static func sheet(_ s: PetSpecies) -> some View {
        func pose(_ f: (inout PetPose) -> Void) -> PetPose { var p = PetStance.mood(.neutral, .moderate).rest(s); f(&p); return p }
        let rows: [(String, PetPose, PetProp?)] = [
            ("wave", pose { $0.armR = 130; $0.smileEyes = 0.6; $0.smile = 0.6 }, nil),
            ("cheer", pose { $0.armR = 150; $0.armL = 150; $0.smileEyes = 1; $0.mouthOpen = 0.6 }, nil),
            ("hug", pose { $0.armR = -55; $0.armL = -55; $0.smile = 0.3 }, nil),
            ("rub eye", pose { $0.armR = -118; $0.lidR = 1 }, nil),
            ("cover eyes", pose { $0.armR = -122; $0.armL = -122; $0.blush = 1 }, nil),
            ("mug", PetStance.mood(.calm, .moderate).rest(s), .mug),
            ("typing", PetStance.life(.working).rest(s), .laptop),
        ]
        return HStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { i in
                VStack(spacing: 2) {
                    LabPet(species: s, pose: rows[i].1.clamped(), prop: rows[i].2).frame(width: 230, height: 230).background(Color(red: 0.93, green: 0.95, blue: 0.97))
                    Text(rows[i].0).font(.system(size: 11)).foregroundStyle(.black)
                }
            }
        }.padding(8).background(Color.white)
    }
}

enum LabComplications {
    @MainActor static func sheet(mono: Bool = false) -> some View {
        let stances: [PetStance] = [.mood(.happy, .moderate), .mood(.neutral, .moderate), .mood(.sad, .moderate), .mood(.frustrated, .moderate), .life(.sleeping)]
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(PetSpecies.allCases, id: \.self) { s in
                HStack(spacing: 14) {
                    ForEach(stances.indices, id: \.self) { i in
                        HStack(spacing: 4) {
                            ForEach(stances[i].badgeMoments(s).indices, id: \.self) { k in
                                LabPet(species: s, pose: stances[i].badgeMoments(s)[k], wear: stances[i].isAsleep ? .nightcap : nil, detail: .badge, mono: mono)
                                    .frame(width: 44, height: 44).padding(3)
                                    .background(Circle().fill(Color(white: 0.16)))
                            }
                        }
                    }
                }
            }
        }.padding(14).background(Color.black)
    }
}
