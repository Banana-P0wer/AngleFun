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
    struct PianoKeyDefinition {
        let key: Character
        let keyCode: UInt16
        let note: Int
        let label: String
    }

    static let whiteKeys: [PianoKeyDefinition] = [
        PianoKeyDefinition(key: "a", keyCode: 0, note: 60, label: "C"),
        PianoKeyDefinition(key: "s", keyCode: 1, note: 62, label: "D"),
        PianoKeyDefinition(key: "d", keyCode: 2, note: 64, label: "E"),
        PianoKeyDefinition(key: "f", keyCode: 3, note: 65, label: "F"),
        PianoKeyDefinition(key: "g", keyCode: 5, note: 67, label: "G"),
        PianoKeyDefinition(key: "h", keyCode: 4, note: 69, label: "A"),
        PianoKeyDefinition(key: "j", keyCode: 38, note: 71, label: "B"),
        PianoKeyDefinition(key: "k", keyCode: 40, note: 72, label: "C"),
        PianoKeyDefinition(key: "l", keyCode: 37, note: 74, label: "D"),
        PianoKeyDefinition(key: ";", keyCode: 41, note: 76, label: "E")
    ]
    static let blackKeys: [PianoKeyDefinition] = [
        PianoKeyDefinition(key: "w", keyCode: 13, note: 61, label: "C#"),
        PianoKeyDefinition(key: "e", keyCode: 14, note: 63, label: "D#"),
        PianoKeyDefinition(key: "t", keyCode: 17, note: 66, label: "F#"),
        PianoKeyDefinition(key: "y", keyCode: 16, note: 68, label: "G#"),
        PianoKeyDefinition(key: "u", keyCode: 32, note: 70, label: "A#"),
        PianoKeyDefinition(key: "o", keyCode: 31, note: 73, label: "C#"),
        PianoKeyDefinition(key: "p", keyCode: 35, note: 75, label: "D#")
    ]

    @Published private(set) var pressedKeys: Set<Character> = []

    private let engine = AVAudioEngine()
    private let state = SynthRenderState()
    private var sourceNode: AVAudioSourceNode?
    private var keyboardPressedKeys: Set<Character> = []
    private var mousePressedKeys: Set<Character> = []

    private static let definitionsByKey: [Character: PianoKeyDefinition] = Dictionary(
        uniqueKeysWithValues: (whiteKeys + blackKeys).map { ($0.key, $0) }
    )
    private static let definitionsByKeyCode: [UInt16: PianoKeyDefinition] = Dictionary(
        uniqueKeysWithValues: (whiteKeys + blackKeys).map { ($0.keyCode, $0) }
    )

    init() {
        prepareEngine()
    }

    func updateAngle(_ angle: Int?) {
        state.setAngle(angle)
    }

    func keyDown(_ keyCode: UInt16) {
        guard let definition = Self.definitionsByKeyCode[keyCode],
              !keyboardPressedKeys.contains(definition.key) else { return }
        keyboardPressedKeys.insert(definition.key)
        updatePressedState(for: definition)
    }

    func keyUp(_ keyCode: UInt16) {
        guard let definition = Self.definitionsByKeyCode[keyCode] else { return }
        keyboardPressedKeys.remove(definition.key)
        updatePressedState(for: definition)
    }

    func mouseDown(_ key: Character) {
        guard let definition = Self.definitionsByKey[key],
              !mousePressedKeys.contains(key) else { return }
        mousePressedKeys.insert(key)
        updatePressedState(for: definition)
    }

    func mouseUp(_ key: Character) {
        guard let definition = Self.definitionsByKey[key] else { return }
        mousePressedKeys.remove(key)
        updatePressedState(for: definition)
    }

    func stopAllNotes() {
        for key in pressedKeys {
            guard let definition = Self.definitionsByKey[key] else { continue }
            state.noteOff(definition.note)
        }
        keyboardPressedKeys.removeAll()
        mousePressedKeys.removeAll()
        pressedKeys.removeAll()
    }

    private func updatePressedState(for definition: PianoKeyDefinition) {
        let isPressed = keyboardPressedKeys.contains(definition.key) || mousePressedKeys.contains(definition.key)
        let wasPressed = pressedKeys.contains(definition.key)
        guard isPressed != wasPressed else { return }

        if isPressed {
            pressedKeys.insert(definition.key)
            state.noteOn(definition.note)
        } else {
            pressedKeys.remove(definition.key)
            state.noteOff(definition.note)
        }
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
