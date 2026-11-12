//
//  MessageBubble.swift
//  StreamingChat
//
//  A single chat bubble, styled by role. Adapts to light and dark themes.
//

import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: Message
    /// True for the assistant bubble currently receiving tokens.
    var isStreaming: Bool = false

    private var isUser: Bool { message.role == .user }

    private var attachedImage: UIImage? {
        guard let data = message.imageData else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if let image = attachedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if message.content.isEmpty && isStreaming {
                    TypingIndicator()
                } else if !message.content.isEmpty {
                    Text(message.content)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if !isUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            Color.accentColor
        } else {
            Color(.secondarySystemBackground)
        }
    }
}

/// Animated three-dot "typing…" indicator shown before the first token.
struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 7, height: 7)
                    .foregroundStyle(.secondary)
                    .opacity(opacity(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
    }

    private func opacity(for index: Int) -> Double {
        let distance = abs(phase - Double(index))
        return max(0.3, 1 - distance * 0.5)
    }
}
