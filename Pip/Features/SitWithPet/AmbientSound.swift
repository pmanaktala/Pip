import AVFoundation
import Observation

/// A soft, generated room tone: filtered noise with a slow swell.
/// Uses the `.ambient` category so it respects the silent switch and mixes with other audio.
@MainActor
@Observable
final class AmbientSound {
    private var engine: AVAudioEngine?
    private var node: AVAudioSourceNode?

    func start() {
        guard engine == nil else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }
        let engine = AVAudioEngine()
        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)
        var phase: Float = 0
        var b0: Float = 0, b1: Float = 0, b2: Float = 0 // pink-noise state
        var lp: Float = 0
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let white = Float.random(in: -1...1)
                // Paul Kellet's economy pink filter.
                b0 = 0.99765 * b0 + white * 0.0990460
                b1 = 0.96300 * b1 + white * 0.2965164
                b2 = 0.57000 * b2 + white * 1.0526913
                let pink = (b0 + b1 + b2 + white * 0.1848) * 0.05
                lp += (pink - lp) * 0.02 // gentle low-pass
                phase += 1 / sampleRate
                let swell = 0.6 + 0.4 * sin(phase * 2 * .pi / 9) // 9-second breath
                let sample = lp * swell * 0.35
                for buffer in buffers {
                    let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    ptr[frame] = sample
                }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0
        do {
            try engine.start()
        } catch {
            return
        }
        self.engine = engine
        self.node = node
        fade(to: 1, over: 2.5)
    }

    func stop() {
        guard let engine else { return }
        fade(to: 0, over: 0.8)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            engine.stop()
            self.engine = nil
            self.node = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func fade(to target: Float, over seconds: Double) {
        guard let mixer = engine?.mainMixerNode else { return }
        let steps = 20
        let start = mixer.outputVolume
        Task { @MainActor in
            for i in 1...steps {
                try? await Task.sleep(for: .seconds(seconds / Double(steps)))
                mixer.outputVolume = start + (target - start) * Float(i) / Float(steps)
            }
        }
    }
}
