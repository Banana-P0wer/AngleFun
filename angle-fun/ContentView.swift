//
//  ContentView.swift
//  angle-fun
//
//  Created by Владислав Туровец on 3/26/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LidAngleViewModel()
    @StateObject private var synthesizer = PianoSynthesizer()

    var body: some View {
        VStack(spacing: 22) {
            Text(viewModel.displayText)
                .font(.system(size: 68, weight: .bold, design: .monospaced))
                .monospacedDigit()

            Text("Наклоняйте крышку, пока удерживаете ноты")
                .font(.headline)
                .foregroundStyle(.secondary)

            pianoKeyboard

            Text("Белые клавиши: A S D F G H J K L ;    Черные: W E T Y U O P")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 610, minHeight: 330)
        .padding(30)
        .background {
            KeyboardCaptureView(
                onKeyDown: synthesizer.keyDown,
                onKeyUp: synthesizer.keyUp,
                onFocusLost: synthesizer.stopAllNotes
            )
            .frame(width: 0, height: 0)
        }
        .onAppear {
            viewModel.start()
            synthesizer.updateAngle(viewModel.currentAngle)
        }
        .onDisappear {
            viewModel.stop()
            synthesizer.stopAllNotes()
        }
        .onChange(of: viewModel.currentAngle) { _, angle in
            synthesizer.updateAngle(angle)
        }
    }

    private var pianoKeyboard: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 2) {
                ForEach(PianoSynthesizer.whiteKeys, id: \.key) { key in
                    PianoKey(
                        key: key.key,
                        note: key.label,
                        isBlack: false,
                        isPressed: synthesizer.pressedKeys.contains(key.key),
                        onPress: { synthesizer.mouseDown(key.key) },
                        onRelease: { synthesizer.mouseUp(key.key) }
                    )
                }
            }

            ForEach(Array(PianoSynthesizer.blackKeys.enumerated()), id: \.element.key) { index, key in
                PianoKey(
                    key: key.key,
                    note: key.label,
                    isBlack: true,
                    isPressed: synthesizer.pressedKeys.contains(key.key),
                    onPress: { synthesizer.mouseDown(key.key) },
                    onRelease: { synthesizer.mouseUp(key.key) }
                )
                .position(x: blackKeyCenters[index], y: 46)
            }
        }
        .frame(width: 518, height: 152)
        .padding(.top, 72)
    }

    private let blackKeyCenters: [CGFloat] = [51, 103, 207, 259, 311, 415, 467]
}

private struct PianoKey: View {
    let key: Character
    let note: String
    let isBlack: Bool
    let isPressed: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Text(note)
                .font(.caption2)
            Text(String(key).uppercased())
                .font(.system(.caption, design: .monospaced, weight: .bold))
        }
        .foregroundStyle(isBlack ? .white : .black)
        .padding(.bottom, 8)
        .frame(width: isBlack ? 34 : 50, height: isBlack ? 92 : 150)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(isPressed ? Color.accentColor : (isBlack ? .black : .white))
                .shadow(color: .black.opacity(isBlack ? 0.24 : 0.12), radius: 2, y: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(.black.opacity(isBlack ? 0 : 0.2))
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    onPress()
                }
                .onEnded { _ in
                    onRelease()
                }
        )
    }
}

#Preview {
    ContentView()
}
