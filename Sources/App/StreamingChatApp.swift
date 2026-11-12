//
//  StreamingChatApp.swift
//  StreamingChat
//
//  Entry point. SwiftData container is wired up in a later step.
//

import SwiftUI
import SwiftData

@main
struct StreamingChatApp: App {
    /// Shared SwiftData container holding chats and messages.
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: Chat.self, Message.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
