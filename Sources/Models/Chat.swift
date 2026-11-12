//
//  Chat.swift
//  StreamingChat
//
//  A conversation containing many messages, persisted with SwiftData.
//

import Foundation
import SwiftData

@Model
final class Chat {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    /// Deleting a chat deletes its messages.
    @Relationship(deleteRule: .cascade, inverse: \Message.chat)
    var messages: [Message]

    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
        self.messages = []
    }

    /// Messages in chronological order.
    var sortedMessages: [Message] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    /// A short preview used in the chat list.
    var preview: String {
        sortedMessages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? "No messages yet"
    }
}
