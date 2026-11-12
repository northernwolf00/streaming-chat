//
//  Message.swift
//  StreamingChat
//
//  A single chat message, persisted with SwiftData.
//

import Foundation
import SwiftData

enum Role: String, Codable {
    case user
    case assistant
    case system
}

@Model
final class Message {
    var id: UUID
    /// Stored as a raw string so SwiftData persists it simply.
    var roleRaw: String
    var content: String
    var createdAt: Date
    var chat: Chat?

    var role: Role {
        get { Role(rawValue: roleRaw) ?? .assistant }
        set { roleRaw = newValue.rawValue }
    }

    init(role: Role, content: String, createdAt: Date = .now) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.content = content
        self.createdAt = createdAt
    }
}
