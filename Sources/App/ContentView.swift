//
//  ContentView.swift
//  StreamingChat
//
//  Root split view: chat list on the left, conversation on the right.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Chat.updatedAt, order: .reverse) private var chats: [Chat]
    @State private var selectedChatID: UUID?

    private var selectedChat: Chat? {
        chats.first { $0.id == selectedChatID }
    }

    var body: some View {
        NavigationSplitView {
            ChatListView(selectedChatID: $selectedChatID)
        } detail: {
            if let chat = selectedChat {
                ConversationView(chat: chat)
                    .id(chat.id)
            } else {
                NoSelectionView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Chat.self, Message.self], inMemory: true)
}
