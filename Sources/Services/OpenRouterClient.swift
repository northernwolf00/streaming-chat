//
//  OpenRouterClient.swift
//  StreamingChat
//
//  Streams chat completions from OpenRouter over Server-Sent Events (SSE),
//  yielding text deltas as they arrive. Uses `URLSession.bytes(for:)` so we can
//  read the response line-by-line and surface tokens immediately.
//
//  Cancellation: the caller runs the stream inside a `Task`; calling
//  `Task.cancel()` (the Stop button) stops the URLSession read and ends the
//  stream promptly.
//

import Foundation

/// A single message in the format the chat-completions API expects.
struct APIMessage: Encodable {
    let role: String      // "system" | "user" | "assistant"
    let content: String
}

final class OpenRouterClient {

    static let shared = OpenRouterClient()

    private let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    /// A free model. Models suffixed with ":free" don't consume credits
    /// (subject to a daily request limit).
    let model: String

    private let session: URLSession

    init(model: String = "deepseek/deepseek-chat-v3.1:free") {
        self.model = model
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    /// Streams the assistant's reply token-by-token for the given conversation.
    /// - Throws: `ChatError` (via the stream) on failure.
    func streamReply(messages: [APIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.performStream(messages: messages) { token in
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ChatError.from(error))
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Internals

    private func performStream(messages: [APIMessage],
                               onToken: (String) -> Void) async throws {
        guard !APIKey.isPlaceholder else { throw ChatError.missingKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIKey.openRouter)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Optional attribution headers recommended by OpenRouter.
        request.setValue("https://github.com/streaming-chat", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("StreamingChat", forHTTPHeaderField: "X-Title")

        let body = RequestBody(model: model, messages: messages, stream: true)
        request.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await session.bytes(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ChatError.unknown("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            switch http.statusCode {
            case 429:            throw ChatError.rateLimited
            case 401, 403:       throw ChatError.missingKey
            default:             throw ChatError.server(status: http.statusCode)
            }
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            if payload.isEmpty { continue }
            guard let data = payload.data(using: .utf8) else { continue }
            guard let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) else { continue }
            if let token = chunk.choices.first?.delta.content, !token.isEmpty {
                onToken(token)
            }
        }
    }

    // MARK: - Wire formats

    private struct RequestBody: Encodable {
        let model: String
        let messages: [APIMessage]
        let stream: Bool
    }

    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta
        }
        let choices: [Choice]
    }
}
