import AppKit
import SwiftUI

/// PetLab renders the real pet code to PNGs on the Mac, for fast art review.
@main
struct PetLab {
    @MainActor static func main() {
        let args = CommandLine.arguments
        let command = args.count > 1 ? args[1] : "poses"
        let out = args.count > 2 ? args[2] : "/tmp/petlab.png"
        let view: AnyView
        switch command {
        case "check": LabCheck.choices(); return
        case "tokens": view = AnyView(LabTokens.sheet())
        case "reactions": view = AnyView(LabFilm.strips(species: species(args), rows: LabFilm.reactions(species(args))))
        case "vignettes": view = AnyView(LabFilm.strips(species: species(args), rows: LabFilm.vignettes(species(args)), size: 90))
        case "stances":
            let s = species(args)
            let stances: [PetStance] = Mood.allCases.map { .mood($0, .moderate) } + PetActivity.allCases.map { .life($0) } + [.meditating]
            view = AnyView(LabFilm.strips(species: s, rows: stances.map { st in LabFilm.Row(title: "\(st)", frames: st.holds(s).map { ($0, st.prop) }) }, size: 140))
        case "director":
            let s = species(args)
            let stances: [PetStance] = [.mood(.happy, .moderate), .mood(.stressed, .moderate), .mood(.sad, .moderate), .life(.reading), .life(.sleeping)]
            view = AnyView(LabFilm.strips(species: s, rows: stances.map { LabFilm.director(s, stance: $0, seconds: 22, frames: 14) }, size: 90))
        default: view = AnyView(LabSheets.poses())
        }
        save(view, to: out)
    }

    static func species(_ args: [String]) -> PetSpecies { args.count > 3 ? PetSpecies(rawValue: args[3]) ?? .penguin : .penguin }

    @MainActor static func save(_ view: AnyView, to path: String) {
        let r = ImageRenderer(content: view.environment(\.colorScheme, .light))
        r.scale = 2
        guard let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { print("render failed"); return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}

struct LabPet: View {
    var species: PetSpecies
    var pose: PetPose
    var prop: PetProp? = nil
    var detail: PetDetail = .full
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 200
            var c = ctx
            c.scaleBy(x: s, y: s)
            if detail == .badge {
                PetPoseView.frame(&c, species: species, framing: .badge)
            }
            PetRenderer.draw(c, PetPaint(species: species, pose: pose, prop: prop, detail: detail, time: 0.4))
        }
    }
}

enum LabSheets {
    static func cell(_ title: String, _ v: some View, size: CGFloat = 220, bg: Color = Color(red: 0.93, green: 0.95, blue: 0.97)) -> some View {
        VStack(spacing: 2) {
            v.frame(width: size, height: size).background(bg)
            Text(title).font(.system(size: 11, design: .rounded)).foregroundStyle(.black)
        }
    }

    @MainActor static func poses() -> some View {
        var smile = PetPose(); smile.smile = 0.8; smile.smileEyes = 0.5; smile.blush = 0.8; smile.armR = 120; smile.armL = 20; smile.headTilt = 8
        var sad = PetPose(); sad.smile = -0.6; sad.lidL = 0.35; sad.lidR = 0.35; sad.lidSlant = -0.8; sad.slump = 0.6; sad.headNod = 0.4; sad.armL = -30; sad.armR = -30; sad.earL = -0.7; sad.earR = -0.7; sad.tears = 0.8
        var cross = PetPose(); cross.lidSlant = 0.9; cross.lidL = 0.3; cross.lidR = 0.3; cross.smile = -0.4; cross.armL = -60; cross.armR = -60; cross.cheekPuff = 1; cross.steam = 1; cross.browShow = 1; cross.browSlant = 1
        var mug = PetPose(); mug.armL = -58; mug.armR = -58; mug.smileEyes = 0.3; mug.lidL = 0.3; mug.lidR = 0.3; mug.smile = 0.4
        var joy = PetPose(); joy.armL = 150; joy.armR = 150; joy.lift = 10; joy.smileEyes = 1; joy.mouthOpen = 0.8; joy.smile = 1; joy.sparkles = 1; joy.squash = -0.2
        var sleep = PetPose(); sleep.lidL = 1; sleep.lidR = 1; sleep.headNod = 0.5; sleep.headTilt = -10; sleep.slump = 0.4; sleep.zzz = 1; sleep.armL = -40; sleep.armR = -40
        var read = PetPose(); read.armL = -52; read.armR = -52; read.gazeY = 0.8; read.headNod = 0.35; read.lidL = 0.25; read.lidR = 0.25
        let rows: [(String, PetPose, PetProp?)] = [("rest", PetPose(), nil), ("happy wave", smile, nil), ("joy", joy, nil), ("sad", sad, .blanket), ("cross", cross, nil), ("mug", mug, .mug), ("reading", read, .book), ("asleep", sleep, .nightcap)]
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(PetSpecies.allCases, id: \.self) { sp in
                HStack(spacing: 6) {
                    ForEach(rows.indices, id: \.self) { i in
                        cell(rows[i].0, LabPet(species: sp, pose: rows[i].1, prop: rows[i].2), size: 200)
                    }
                    VStack(spacing: 6) {
                        cell("60", LabPet(species: sp, pose: rows[1].1, detail: .face), size: 60)
                        cell("badge 28", LabPet(species: sp, pose: PetPose(), detail: .badge), size: 28)
                    }
                }
            }
        }.padding(12).background(Color.white)
    }
}
