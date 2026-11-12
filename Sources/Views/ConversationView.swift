//
//  ConversationView.swift
//  StreamingChat
//
//  The open conversation: message list, streaming, Stop, error banner, input,
//  and optional photo attachment.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ConversationView: View {
    @Environment(\.modelContext) private var context
    @Bindable var chat: Chat
    @StateObject private var viewModel = ChatViewModel()
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    // Photo attachment state.
    @State private var pickerItem: PhotosPickerItem?
    @State private var attachedImageData: Data?
    @State private var isProcessingImage = false

    private var messages: [Message] { chat.sortedMessages }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if let error = viewModel.error {
                ErrorBanner(error: error) {
                    viewModel.retry(chat: chat, context: context)
                }
            }
            if attachedImageData != nil || isProcessingImage {
                attachmentPreview
            }
            inputBar
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, newItem in
            loadAttachment(newItem)
        }
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

    // MARK: - Attachment preview

    private var attachmentPreview: some View {
        HStack {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let data = attachedImageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: 60, height: 60)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if attachedImageData != nil {
                    Button {
                        attachedImageData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.6))
                            .font(.title3)
                    }
                    .offset(x: 6, y: -6)
                    .accessibilityLabel("Remove photo")
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        // Capture the main-actor state locally so it isn't read inside the
        // PhotosPicker label (a Sendable closure).
        let streaming = viewModel.isStreaming
        return HStack(alignment: .bottom, spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .foregroundStyle(streaming ? Color.gray : Color.accentColor)
            }
            .disabled(streaming)
            .accessibilityLabel("Attach photo")

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
        let hasText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || attachedImageData != nil) && !isProcessingImage
    }

    private var lastContent: String {
        messages.last?.content ?? ""
    }

    private func send() {
        let text = draft
        let image = attachedImageData
        draft = ""
        attachedImageData = nil
        viewModel.send(text, imageData: image, to: chat, context: context)
    }

    /// Load the picked photo, downscale and compress it to keep requests small.
    private func loadAttachment(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isProcessingImage = true
        Task {
            defer {
                isProcessingImage = false
                pickerItem = nil
            }
            if let data = try? await item.loadTransferable(type: Data.self),
               let jpeg = Self.downscaledJPEG(from: data) {
                attachedImageData = jpeg
            }
        }
    }

    /// Resize so the longest side is <= `maxSide` and re-encode as JPEG.
    static func downscaledJPEG(from data: Data,
                               maxSide: CGFloat = 1024,
                               quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let newSize = CGSize(width: image.size.width * scale,
                             height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: quality)
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
