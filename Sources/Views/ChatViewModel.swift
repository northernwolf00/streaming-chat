//
//  ChatViewModel.swift
//  StreamingChat
//
//  Drives one conversation: sending a message, streaming the reply token by
//  token, stopping mid-stream, and surfacing error states for Retry.
//

import Foundation
import SwiftData

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var isStreaming = false
    @Published var error: ChatError?
    /// True while the last/active reply is generated on-device (offline).
    @Published var isOffline = false

    private var streamTask: Task<Void, Never>?

    private let systemPrompt = APIMessage(
        role: Role.system.rawValue,
        text: "You are a helpful, concise assistant."
    )

    // MARK: - Actions

    /// Append the user's message (optionally with a photo) and start streaming
    /// the assistant reply.
    func send(_ text: String, imageData: Data? = nil, modelID: String = AIModel.autoID,
              forceOnDevice: Bool = false, to chat: Chat, context: ModelContext) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Allow sending with text, a photo, or both.
        guard (!trimmed.isEmpty || imageData != nil), !isStreaming else { return }

        error = nil
        let userMessage = Message(role: .user, content: trimmed, imageData: imageData)
        userMessage.chat = chat
        chat.messages.append(userMessage)
        if chat.title == "New Chat" {
            chat.title = trimmed.isEmpty ? "Photo" : String(trimmed.prefix(40))
        }
        chat.updatedAt = .now
        try? context.save()

        startStreaming(for: chat, context: context, modelID: modelID, forceOnDevice: forceOnDevice)
    }

    /// Stop the current generation, keeping whatever text already arrived.
    func stop() {
        streamTask?.cancel()
    }

    /// Retry after an error: drop any failed assistant bubble and stream again.
    /// Uses the currently selected model, so switching model then tapping Retry
    /// (e.g. to a vision model after an imageUnsupported error) works.
    func retry(chat: Chat, context: ModelContext, modelID: String = AIModel.autoID,
               forceOnDevice: Bool = false) {
        guard !isStreaming else { return }
        error = nil
        if let last = chat.sortedMessages.last, last.role == .assistant {
            chat.messages.removeAll { $0.id == last.id }
            context.delete(last)
        }
        startStreaming(for: chat, context: context, modelID: modelID, forceOnDevice: forceOnDevice)
    }

    // MARK: - Streaming

    private func startStreaming(for chat: Chat, context: ModelContext,
                                modelID: String, forceOnDevice: Bool) {
        // Build the request history BEFORE adding the empty assistant bubble.
        var history = [systemPrompt]
        history += chat.sortedMessages.map {
            APIMessage(role: $0.role.rawValue, text: $0.content, imageData: $0.imageData)
        }

        // Choose the provider: on-device (offline) vs cloud.
        let online = NetworkMonitor.shared.isOnline
        let availability = OnDeviceAvailability.current
        let useOnDevice = availability.isAvailable && (forceOnDevice || !online)

        let provider: ChatProvider
        if useOnDevice, let onDevice = Self.makeOnDeviceProvider() {
            provider = onDevice
            isOffline = true
        } else if !online {
            // No network and no on-device model → the classic No network error.
            error = .noNetwork
            return
        } else {
            // Cloud path: fail fast if a pinned (non-Auto) model can't read a photo.
            let model = ModelCatalog.model(id: modelID)
            let hasImage = history.contains { $0.hasImage }
            if !model.isAuto, hasImage, !model.supportsVision {
                error = .imageUnsupported
                return
            }
            provider = OpenRouterClient.shared
            isOffline = false
        }

        let model = ModelCatalog.model(id: modelID)
        let modelOverride = model.isAuto ? nil : model.id

        let assistant = Message(role: .assistant, content: "")
        assistant.chat = chat
        chat.messages.append(assistant)
        try? context.save()

        isStreaming = true
        streamTask = Task { [weak self] in
            guard let self else { return }
            var failure: ChatError?
            do {
                let stream = provider.streamReply(messages: history, modelOverride: modelOverride)
                for try await token in stream {
                    if Task.isCancelled { break }
                    assistant.content += token
                }
            } catch {
                failure = ChatError.from(error)
            }

            // An assistant bubble with no text (empty reply, immediate stop, or a
            // failure) should not linger — remove it so the UI is clean.
            if assistant.content.isEmpty {
                chat.messages.removeAll { $0.id == assistant.id }
                context.delete(assistant)
            }

            if let failure, failure != .cancelled {
                self.error = failure
            }

            chat.updatedAt = .now
            try? context.save()
            self.isStreaming = false
            self.streamTask = nil
        }
    }

    /// Create the on-device provider when the OS and framework allow it.
    private static func makeOnDeviceProvider() -> ChatProvider? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return OnDeviceProvider()
        }
        #endif
        return nil
    }
}
