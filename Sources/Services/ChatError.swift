//
//  ChatError.swift
//  StreamingChat
//
//  User-facing error states for the chat flow.
//

import Foundation

enum ChatError: LocalizedError, Equatable {
    case noNetwork
    case rateLimited          // HTTP 429 — free-tier daily limit reached
    case server(status: Int)  // other non-success HTTP status
    case missingKey           // placeholder key still in place
    case decoding
    case cancelled            // user pressed Stop
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "No internet connection. Check your network and try again."
        case .rateLimited:
            return "API limit reached. The free daily quota is used up — try again later."
        case .server(let status):
            return "Server error (HTTP \(status)). Please try again."
        case .missingKey:
            return "No API key configured. Set the OpenRouter key in APIKey.swift."
        case .decoding:
            return "Couldn't read the response from the server."
        case .cancelled:
            return "Generation stopped."
        case .unknown(let message):
            return message
        }
    }

    /// Whether showing a Retry button makes sense for this error.
    var isRetryable: Bool {
        switch self {
        case .cancelled, .missingKey:
            return false
        default:
            return true
        }
    }

    /// Map a low-level error to a ChatError.
    static func from(_ error: Error) -> ChatError {
        if error is CancellationError { return .cancelled }
        if let chatError = error as? ChatError { return chatError }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost,
                 .cannotConnectToHost, .cannotFindHost, .timedOut,
                 .dataNotAllowed, .internationalRoamingOff:
                return .noNetwork
            case .cancelled:
                return .cancelled
            default:
                return .unknown(urlError.localizedDescription)
            }
        }
        return .unknown(error.localizedDescription)
    }
}
