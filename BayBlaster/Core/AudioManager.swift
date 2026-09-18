import AVFoundation
import Foundation

/// Tiny procedural synth: every sound is generated into a PCM buffer at startup and played
/// through a pool of AVAudioPlayerNodes. No audio files needed. Respects the persisted mute flag.
final class AudioManager {
    static let shared = AudioManager()

    enum Sound: CaseIterable {
        case launch, splash, coin, rocket, sink, bump, purchase, tick, whale, hurt, lock
    }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var started = false

    var isMuted: Bool { SaveManager.shared.isMuted }

    private init() {
        for _ in 0..<8 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        engine.mainMixerNode.outputVolume = 0.8
        for s in Sound.allCases { buffers[s] = render(s) }
    }

    /// Call once the app is on screen (audio session activation is cheap but not free).
    func warmUp() {
        guard !started else { return }
        started = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            print("[Audio] engine failed to start: \(error)")
        }
    }

    func play(_ sound: Sound, volume: Float = 1) {
        guard !isMuted else { return }
        if !started { warmUp() }
        guard engine.isRunning, let buf = buffers[sound] else { return }
        let p = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        p.stop()
        p.volume = volume
        p.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        p.play()
    }

    // MARK: - Synthesis

    private struct Voice {
        var freqStart: Float
        var freqEnd: Float
        var duration: Float
        var attack: Float = 0.005
        var decay: Float = 0.2         // exponential decay time constant
        var amp: Float = 0.5
        var noise: Float = 0           // 0 = pure tone, 1 = pure noise
        var square: Bool = false
        var startAt: Float = 0
    }

    private func render(_ sound: Sound) -> AVAudioPCMBuffer {
        let voices: [Voice]
        switch sound {
        case .launch:
            voices = [Voice(freqStart: 140, freqEnd: 50, duration: 0.45, decay: 0.16, amp: 0.9),
                      Voice(freqStart: 0, freqEnd: 0, duration: 0.25, decay: 0.08, amp: 0.5, noise: 1)]
        case .splash:
            voices = [Voice(freqStart: 0, freqEnd: 0, duration: 0.35, attack: 0.01, decay: 0.12, amp: 0.45, noise: 1),
                      Voice(freqStart: 420, freqEnd: 180, duration: 0.2, decay: 0.07, amp: 0.25)]
        case .coin:
            voices = [Voice(freqStart: 1046, freqEnd: 1046, duration: 0.09, decay: 0.06, amp: 0.35, square: true),
                      Voice(freqStart: 1568, freqEnd: 1568, duration: 0.18, decay: 0.09, amp: 0.35, square: true, startAt: 0.08)]
        case .rocket:
            voices = [Voice(freqStart: 0, freqEnd: 0, duration: 0.5, attack: 0.02, decay: 0.25, amp: 0.4, noise: 1),
                      Voice(freqStart: 220, freqEnd: 660, duration: 0.45, attack: 0.02, decay: 0.3, amp: 0.25)]
        case .sink:
            voices = [Voice(freqStart: 330, freqEnd: 70, duration: 1.1, attack: 0.02, decay: 0.6, amp: 0.5),
                      Voice(freqStart: 0, freqEnd: 0, duration: 0.8, attack: 0.05, decay: 0.4, amp: 0.25, noise: 1)]
        case .bump:
            voices = [Voice(freqStart: 300, freqEnd: 520, duration: 0.18, decay: 0.09, amp: 0.5)]
        case .purchase:
            voices = [Voice(freqStart: 523, freqEnd: 523, duration: 0.12, decay: 0.08, amp: 0.3, square: true),
                      Voice(freqStart: 659, freqEnd: 659, duration: 0.12, decay: 0.08, amp: 0.3, square: true, startAt: 0.1),
                      Voice(freqStart: 784, freqEnd: 784, duration: 0.25, decay: 0.14, amp: 0.3, square: true, startAt: 0.2)]
        case .tick:
            voices = [Voice(freqStart: 900, freqEnd: 700, duration: 0.04, decay: 0.02, amp: 0.3)]
        case .whale:
            voices = [Voice(freqStart: 180, freqEnd: 520, duration: 0.6, attack: 0.05, decay: 0.4, amp: 0.4),
                      Voice(freqStart: 0, freqEnd: 0, duration: 0.5, attack: 0.05, decay: 0.3, amp: 0.2, noise: 1)]
        case .hurt:
            voices = [Voice(freqStart: 200, freqEnd: 90, duration: 0.3, decay: 0.1, amp: 0.6, square: true),
                      Voice(freqStart: 0, freqEnd: 0, duration: 0.15, decay: 0.05, amp: 0.4, noise: 1)]
        case .lock:
            voices = [Voice(freqStart: 600, freqEnd: 900, duration: 0.08, decay: 0.05, amp: 0.35, square: true)]
        }

        let sr = Float(format.sampleRate)
        let total = voices.map { $0.startAt + $0.duration }.max() ?? 0.1
        let frames = AVAudioFrameCount(total * sr) + 1
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let out = buffer.floatChannelData![0]
        for i in 0..<Int(frames) { out[i] = 0 }

        var rng = UInt32(0x9E3779B9)
        func noise() -> Float {
            rng = rng &* 1664525 &+ 1013904223
            return Float(rng >> 8) / Float(1 << 24) * 2 - 1
        }

        for v in voices {
            let start = Int(v.startAt * sr)
            let n = Int(v.duration * sr)
            var phase: Float = 0
            var lowpass: Float = 0
            for i in 0..<n {
                let t = Float(i) / sr
                let u = t / v.duration
                let freq = v.freqStart + (v.freqEnd - v.freqStart) * u
                phase += 2 * Float.pi * freq / sr
                var s: Float
                if v.square {
                    s = sin(phase) >= 0 ? 1 : -1
                    s *= 0.6
                } else {
                    s = sin(phase)
                }
                if v.noise > 0 {
                    // one-pole low-passed noise so splashes sound watery rather than harsh
                    lowpass += (noise() - lowpass) * 0.35
                    s = s * (1 - v.noise) + lowpass * v.noise
                }
                let env = min(1, t / max(v.attack, 0.0001)) * exp(-t / v.decay)
                let idx = start + i
                if idx < Int(frames) { out[idx] += s * env * v.amp }
            }
        }
        // soft clip
        for i in 0..<Int(frames) { out[i] = tanh(out[i]) }
        return buffer
    }
}
