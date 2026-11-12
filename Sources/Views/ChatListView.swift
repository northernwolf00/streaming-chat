//
//  ChatListView.swift
//  StreamingChat
//
//  Sidebar: the list of chats, plus create/delete.
//

import SwiftUI
import SwiftData

struct ChatListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Chat.updatedAt, order: .reverse) private var chats: [Chat]
    @Binding var selectedChatID: UUID?

    var body: some View {
        Group {
            if chats.isEmpty {
                EmptyChatsView(onCreate: createChat)
            } else {
                List(selection: $selectedChatID) {
                    ForEach(chats) { chat in
                        ChatRow(chat: chat)
                            .tag(chat.id)
                    }
                    .onDelete(perform: deleteChats)
                }
            }
        }
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createChat) {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
            }
        }
    }

    private func createChat() {
        let chat = Chat()
        context.insert(chat)
        try? context.save()
        selectedChatID = chat.id
    }

    private func deleteChats(at offsets: IndexSet) {
        for index in offsets {
            let chat = chats[index]
            if chat.id == selectedChatID { selectedChatID = nil }
            context.delete(chat)
        }
        try? context.save()
    }
}

private struct ChatRow: View {
    let chat: Chat

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(chat.title)
                .font(.headline)
                .lineLimit(1)
            Text(chat.preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}
