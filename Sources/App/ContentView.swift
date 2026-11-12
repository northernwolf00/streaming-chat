//
//  ContentView.swift
//  StreamingChat
//
//  Skeleton placeholder — replaced by the real chat UI in a later step.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("StreamingChat")
                .font(.title2.bold())
            Text("Skeleton — ready to build on")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
