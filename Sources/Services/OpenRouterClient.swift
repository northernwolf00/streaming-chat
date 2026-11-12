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
//  Images: a message may carry an attached JPEG. When any message has an image,
//  the request is sent in the OpenAI-compatible multimodal format (an array of
//  `content` parts: `text` + `image_url` with a base64 data URL) and routed to a
//  vision-capable model.
//

import Foundation

/// A single message. If `imageData` is set, it is encoded as multimodal content
/// parts; otherwise `content` is a plain string.
struct APIMessage: Encodable {
    let role: String      // "system" | "user" | "assistant"
    let text: String
    let imageData: Data?

    init(role: String, text: String, imageData: Data? = nil) {
        self.role = role
        self.text = text
        self.imageData = imageData
    }

    var hasImage: Bool { imageData != nil }

    private enum CodingKeys: String, CodingKey { case role, content }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        if let imageData {
            var parts: [ContentPart] = []
            if !text.isEmpty { parts.append(.text(text)) }
            let base64 = imageData.base64EncodedString()
            parts.append(.imageURL("data:image/jpeg;base64,\(base64)"))
            try container.encode(parts, forKey: .content)
        } else {
            try container.encode(text, forKey: .content)
        }
    }
}

/// One part of a multimodal message.
private enum ContentPart: Encodable {
    case text(String)
    case imageURL(String)

    private enum Keys: String, CodingKey { case type, text, image_url }
    private enum ImageKeys: String, CodingKey { case url }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .text)
        case .imageURL(let url):
            try container.encode("image_url", forKey: .type)
            var image = container.nestedContainer(keyedBy: ImageKeys.self, forKey: .image_url)
            try image.encode(url, forKey: .url)
        }
    }
}

/// The cloud provider: OpenRouter over the network.
final class OpenRouterClient: ChatProvider {

    static let shared = OpenRouterClient()

    private let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    /// Free text models (":free" => no credits used, subject to a daily limit).
    /// OpenRouter tries them in order, so if the first is rate-limited upstream
    /// it automatically falls back to the next — keeps the app working.
    let models: [String]

    /// Free models that accept image input, used when a message has a photo.
    let visionModels: [String]

    private let session: URLSession

    init(
        models: [String] = [
            "baidu/ernie-5.5-flash-preview:free",
            "google/gemma-4-31b-it:free",
            "google/gemma-4-26b-a4b-it:free"
        ],
        // OpenRouter allows at most 3 models in the fallback array. Gemma is
        // preferred but often rate-limited on the shared free pool, so the chain
        // falls through to Nemotron-VL and finally `openrouter/free` (an
        // auto-router over available free models) so a photo reply still works.
        visionModels: [String] = [
            "google/gemma-4-31b-it:free",
            "nvidia/nemotron-3.5-super-vl:free",
            "openrouter/free"
        ]
    ) {
        self.models = models
        self.visionModels = visionModels
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    /// Streams the assistant's reply token-by-token for the given conversation.
    /// - Parameter modelOverride: a specific model id to pin, or `nil` for the
    ///   automatic fallback chain.
    /// - Throws: `ChatError` (via the stream) on failure.
    func streamReply(messages: [APIMessage],
                     modelOverride: String? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.performStream(messages: messages, modelOverride: modelOverride) { token in
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
                               modelOverride: String?,
                               onToken: (String) -> Void) async throws {
        guard !APIKey.isPlaceholder else { throw ChatError.missingKey }

        // A pinned model is sent alone; otherwise use the automatic fallback
        // chain (vision chain when any message carries an image).
        let hasImage = messages.contains { $0.hasImage }
        let chosenModels: [String]
        if let modelOverride {
            chosenModels = [modelOverride]
        } else {
            chosenModels = hasImage ? visionModels : models
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIKey.openRouter)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Optional attribution headers recommended by OpenRouter.
        request.setValue("https://github.com/streaming-chat", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("StreamingChat", forHTTPHeaderField: "X-Title")

        let body = RequestBody(models: chosenModels, messages: messages, stream: true)
        request.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await session.bytes(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ChatError.unknown("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw await mapError(status: http.statusCode, body: bytes, hasImage: hasImage)
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

    /// Map a non-success HTTP status (reading a little of the error body) to a ChatError.
    private func mapError(status: Int,
                          body: URLSession.AsyncBytes,
                          hasImage: Bool) async -> ChatError {
        var text = ""
        if let collected = try? await collectBody(body) { text = collected.lowercased() }

        switch status {
        case 429: return .rateLimited
        case 401, 403: return .missingKey
        case 413: return .imageTooLarge
        default: break
        }
        if hasImage {
            if text.contains("too large") || text.contains("maximum") || text.contains("exceed") {
                return .imageTooLarge
            }
            if text.contains("image") || text.contains("modal") || text.contains("no endpoints") {
                return .imageUnsupported
            }
        }
        return .server(status: status)
    }

    private func collectBody(_ bytes: URLSession.AsyncBytes) async throws -> String {
        var text = ""
        for try await line in bytes.lines {
            text += line
            if text.count > 2000 { break }
        }
        return text
    }

    // MARK: - Wire formats

    private struct RequestBody: Encodable {
        let models: [String]
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
