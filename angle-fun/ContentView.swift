//
//  ContentView.swift
//  angle-fun
//
//  Created by Владислав Туровец on 3/26/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LidAngleViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Text(viewModel.displayText)
                .font(.system(size: 68, weight: .bold, design: .monospaced))
                .monospacedDigit()
        }
        .padding()
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

#Preview {
    ContentView()
}
