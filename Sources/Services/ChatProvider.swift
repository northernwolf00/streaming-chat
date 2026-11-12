//
//  ChatProvider.swift
//  StreamingChat
//
//  Abstraction over "something that streams an assistant reply". Two concrete
//  providers exist:
//    - CloudProvider      → OpenRouter over the network (see OpenRouterClient)
//    - OnDeviceProvider    → Apple Foundation Models (iOS 26+/macOS 26+), offline
//
//  All Foundation Models code is behind `#if canImport(FoundationModels)` and
//  `if #available(iOS 26.0, macOS 26.0, *)`, so the app still builds and runs on
//  iOS 18 unchanged.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Streams an assistant reply as text deltas (token-by-token).
protocol ChatProvider {
    func streamReply(messages: [APIMessage], modelOverride: String?) -> AsyncThrowingStream<String, Error>
}

// MARK: - On-device availability

enum OnDeviceAvailability: Equatable {
    case available
    case unavailable(reason: String)
    case unsupportedOS            // running on iOS < 26 (no Foundation Models)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    /// Short reason string when not available (nil when available).
    var reason: String? {
        switch self {
        case .available: return nil
        case .unsupportedOS: return "On-device AI needs iOS 26 or later."
        case .unavailable(let reason): return reason
        }
    }

    static var current: OnDeviceAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return .unavailable(reason: "This device doesn't support Apple Intelligence.")
                case .appleIntelligenceNotEnabled:
                    return .unavailable(reason: "Turn on Apple Intelligence in Settings to use offline mode.")
                case .modelNotReady:
                    return .unavailable(reason: "The on-device model is still downloading. Try again later.")
                @unknown default:
                    return .unavailable(reason: "On-device model is unavailable.")
                }
            @unknown default:
                return .unavailable(reason: "On-device model is unavailable.")
            }
        } else {
            return .unsupportedOS
        }
        #else
        return .unsupportedOS
        #endif
    }
}

// MARK: - On-device provider

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
final class OnDeviceProvider: ChatProvider {

    /// Rough budget for the prompt so we stay inside the model's context window.
    private let maxPromptCharacters = 4000

    func streamReply(messages: [APIMessage], modelOverride: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (instructions, prompt) = Self.buildPrompt(
                        from: messages, budget: maxPromptCharacters
                    )
                    let session = LanguageModelSession(instructions: instructions)

                    var previous = ""
                    let stream = session.streamResponse(to: prompt)
                    for try await snapshot in stream {
                        try Task.checkCancellation()
                        let text = snapshot.content
                        if text.count >= previous.count {
                            let delta = String(text.dropFirst(previous.count))
                            if !delta.isEmpty { continuation.yield(delta) }
                        } else {
                            continuation.yield(text)
                        }
                        previous = text
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: ChatError.cancelled)
                } catch {
                    continuation.finish(throwing: ChatError.onDevice(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Build (instructions, prompt) from the conversation, trimming old turns to
    /// stay within the context budget. Images are ignored (offline is text-only).
    private static func buildPrompt(from messages: [APIMessage],
                                    budget: Int) -> (String, String) {
        let instructions = messages.first { $0.role == Role.system.rawValue }?.text
            ?? "You are a helpful, concise assistant."
        let turns = messages.filter { $0.role != Role.system.rawValue }

        // Keep the most recent turns that fit the budget.
        var kept: [APIMessage] = []
        var total = 0
        for message in turns.reversed() {
            total += message.text.count + 12
            if total > budget && !kept.isEmpty { break }
            kept.insert(message, at: 0)
        }

        var lines: [String] = []
        for message in kept {
            let who = message.role == Role.user.rawValue ? "User" : "Assistant"
            lines.append("\(who): \(message.text)")
        }
        lines.append("Assistant:")
        return (instructions, lines.joined(separator: "\n"))
    }
}
#endif
