//
//  StateViews.swift
//  StreamingChat
//
//  Reusable empty / error state views.
//

import SwiftUI

/// Shown in the detail pane when no chat is selected.
struct NoSelectionView: View {
    var body: some View {
        ContentUnavailableView(
            "Select a Chat",
            systemImage: "bubble.left.and.bubble.right",
            description: Text("Choose a conversation on the left, or create a new one.")
        )
    }
}

/// Shown inside an open chat that has no messages yet.
struct EmptyConversationView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Ask me anything")
                .font(.title3.weight(.semibold))
            Text("Type a message below to start the conversation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Inline error banner with an optional Retry button.
struct ErrorBanner: View {
    let error: ChatError
    var onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(error.errorDescription ?? "Something went wrong.")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            if error.isRetryable {
                Button("Retry", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}
