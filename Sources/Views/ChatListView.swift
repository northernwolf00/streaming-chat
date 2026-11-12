//
//  ChatListView.swift
//  StreamingChat
//
//  Sidebar / home: app-bar "Chats" title, chat history list, and a prominent
//  "New Chat" button pinned to the bottom.
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
                emptyState
            } else {
                List(selection: $selectedChatID) {
                    ForEach(chats) { chat in
                        ChatRow(chat: chat)
                            .tag(chat.id)
                    }
                    .onDelete(perform: deleteChats)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Chats")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            newChatButton
        }
    }

    // MARK: - Bottom action

    private var newChatButton: some View {
        Button(action: createChat) {
            Label("New Chat", systemImage: "square.and.pencil")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text("No Chats")
                .font(.title3.bold())
            Text("Start a new conversation to begin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

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

// MARK: - Row

private struct ChatRow: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.15))
                Text(monogram)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(chat.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(chat.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(Self.timeLabel(chat.updatedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var monogram: String {
        let trimmed = chat.title.trimmingCharacters(in: .whitespaces)
        if let first = trimmed.first {
            return String(first).uppercased()
        }
        return "#"
    }

    /// Short relative timestamp (today → time, this week → weekday, else date).
    static func timeLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(date: .numeric, time: .omitted)
    }
}
