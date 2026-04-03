//
//  KeyboardCaptureView.swift
//  angle-fun
//
//  Created by Codex on 5/24/26.
//

import AppKit
import SwiftUI

struct KeyboardCaptureView: NSViewRepresentable {
    let onKeyDown: (String) -> Void
    let onKeyUp: (String) -> Void
    let onFocusLost: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyDown = onKeyDown
        view.onKeyUp = onKeyUp
        view.onFocusLost = onFocusLost
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.onKeyUp = onKeyUp
        nsView.onFocusLost = onFocusLost
        DispatchQueue.main.async {
            if nsView.window?.firstResponder !== nsView {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

final class KeyCaptureNSView: NSView {
    var onKeyDown: ((String) -> Void)?
    var onKeyUp: ((String) -> Void)?
    var onFocusLost: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat, let characters = event.charactersIgnoringModifiers else { return }
        onKeyDown?(characters)
    }

    override func keyUp(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }
        onKeyUp?(characters)
    }

    override func resignFirstResponder() -> Bool {
        onFocusLost?()
        return super.resignFirstResponder()
    }
}
