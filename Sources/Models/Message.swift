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

    /// Optional attached image (compressed JPEG). Stored outside the main
    /// database file via external storage so large blobs don't bloat it.
    @Attribute(.externalStorage) var imageData: Data?

    var role: Role {
        get { Role(rawValue: roleRaw) ?? .assistant }
        set { roleRaw = newValue.rawValue }
    }

    var hasImage: Bool { imageData != nil }

    init(role: Role, content: String, imageData: Data? = nil, createdAt: Date = .now) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.content = content
        self.imageData = imageData
        self.createdAt = createdAt
    }
}
