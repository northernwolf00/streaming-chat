//
//  ConversationView.swift
//  StreamingChat
//
//  The open conversation: message list, streaming, Stop, error banner, input.
//

import SwiftUI
import SwiftData

struct ConversationView: View {
    @Environment(\.modelContext) private var context
    @Bindable var chat: Chat
    @StateObject private var viewModel = ChatViewModel()
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private var messages: [Message] { chat.sortedMessages }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if let error = viewModel.error {
                ErrorBanner(error: error) {
                    viewModel.retry(chat: chat, context: context)
                }
            }
            inputBar
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty && !viewModel.isStreaming {
                    EmptyConversationView()
                        .frame(minHeight: 400)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
                                isStreaming: viewModel.isStreaming && message.id == messages.last?.id
                            )
                            .id(message.id)
                        }
                        Color.clear.frame(height: 1).id(bottomAnchor)
                    }
                    .padding()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: lastContent) { scrollToBottom(proxy) }
            .onChange(of: messages.count) { scrollToBottom(proxy) }
            .onAppear { scrollToBottom(proxy, animated: false) }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .focused($inputFocused)
                .disabled(viewModel.isStreaming)

            if viewModel.isStreaming {
                Button(action: viewModel.stop) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .background(Color.red, in: Circle())
                }
                .accessibilityLabel("Stop")
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.title3.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .background(canSend ? Color.accentColor : Color.gray, in: Circle())
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Helpers

    private let bottomAnchor = "BOTTOM_ANCHOR"

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var lastContent: String {
        messages.last?.content ?? ""
    }

    private func send() {
        let text = draft
        draft = ""
        viewModel.send(text, to: chat, context: context)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard !messages.isEmpty else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }
}
