//
//  PianoSynthesizer.swift
//  angle-fun
//
//  Created by Codex on 5/24/26.
//

@preconcurrency import AVFoundation
import Combine
import Foundation

private final class SynthRenderState: @unchecked Sendable {
    struct Voice {
        let midiNote: Int
        var phase: Double = 0
        var amplitude: Double = 0
        var isReleased = false
    }

    let lock = NSLock()
    var voices: [Int: Voice] = [:]
    var pitchBendSemitones = 0.0
    var brightness = 0.2

    func noteOn(_ midiNote: Int) {
        lock.lock()
        voices[midiNote] = Voice(midiNote: midiNote)
        lock.unlock()
    }

    func noteOff(_ midiNote: Int) {
        lock.lock()
        voices[midiNote]?.isReleased = true
        lock.unlock()
    }

    func setAngle(_ angle: Int?) {
        let normalized = min(max((Double(angle ?? 80) - 20) / 120, 0), 1)
        lock.lock()
        pitchBendSemitones = (normalized - 0.5) * 4
        brightness = 0.08 + normalized * 0.48
        lock.unlock()
    }

    func render(frameCount: Int, sampleRate: Double, into buffers: UnsafeMutableAudioBufferListPointer) {
        lock.lock()
        defer { lock.unlock() }

        for frame in 0..<frameCount {
            var sample = 0.0

            for note in Array(voices.keys) {
                guard var voice = voices[note] else { continue }
                let target = voice.isReleased ? 0.0 : 0.19
                let smoothing = voice.isReleased ? 0.005 : 0.012
                voice.amplitude += (target - voice.amplitude) * smoothing

                let bentNote = Double(voice.midiNote) + pitchBendSemitones
                let frequency = 440 * pow(2, (bentNote - 69) / 12)
                voice.phase += 2 * .pi * frequency / sampleRate
                if voice.phase >= 2 * .pi {
                    voice.phase -= 2 * .pi
                }

                sample += (sin(voice.phase) + brightness * sin(voice.phase * 2)) * voice.amplitude
                if voice.isReleased, voice.amplitude < 0.0005 {
                    voices.removeValue(forKey: note)
                } else {
                    voices[note] = voice
                }
            }

            let limitedSample = Float(tanh(sample))
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                data[frame] = limitedSample
            }
        }
    }
}

final class PianoSynthesizer: ObservableObject {
    static let whiteKeys: [(key: Character, note: Int, label: String)] = [
        ("a", 60, "C"), ("s", 62, "D"), ("d", 64, "E"), ("f", 65, "F"), ("g", 67, "G"),
        ("h", 69, "A"), ("j", 71, "B"), ("k", 72, "C"), ("l", 74, "D"), (";", 76, "E")
    ]
    static let blackKeys: [(key: Character, note: Int, label: String)] = [
        ("w", 61, "C#"), ("e", 63, "D#"), ("t", 66, "F#"), ("y", 68, "G#"),
        ("u", 70, "A#"), ("o", 73, "C#"), ("p", 75, "D#")
    ]

    @Published private(set) var pressedKeys: Set<Character> = []

    private let engine = AVAudioEngine()
    private let state = SynthRenderState()
    private var sourceNode: AVAudioSourceNode?

    private static let notesByKey: [Character: Int] = Dictionary(
        uniqueKeysWithValues: (whiteKeys + blackKeys).map { ($0.key, $0.note) }
    )

    init() {
        prepareEngine()
    }

    func updateAngle(_ angle: Int?) {
        state.setAngle(angle)
    }

    func keyDown(_ characters: String) {
        guard let key = characters.lowercased().first,
              let note = Self.notesByKey[key],
              !pressedKeys.contains(key) else { return }

        pressedKeys.insert(key)
        state.noteOn(note)
    }

    func keyUp(_ characters: String) {
        guard let key = characters.lowercased().first,
              let note = Self.notesByKey[key] else { return }

        pressedKeys.remove(key)
        state.noteOff(note)
    }

    func stopAllNotes() {
        for key in pressedKeys {
            guard let note = Self.notesByKey[key] else { continue }
            state.noteOff(note)
        }
        pressedKeys.removeAll()
    }

    private func prepareEngine() {
        let format = engine.outputNode.inputFormat(forBus: 0)
        let state = state
        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            state.render(frameCount: Int(frameCount), sampleRate: format.sampleRate, into: buffers)
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        self.sourceNode = sourceNode

        do {
            try engine.start()
        } catch {
            print("Unable to start synthesizer audio engine: \(error)")
        }
    }
}
