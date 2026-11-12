# Plan — StreamingChat (~6–8 h)

## 0. Before coding (30 min)
- Get an OpenRouter key; verify streaming works with `curl`.
- Write `docs/task.md`, `docs/plan.md`, `CLAUDE.md`.
- Start the time tracker.

## 1. Skeleton (1 h)  ← current
- `project.yml` (XcodeGen, iOS 18 target).
- `Build.command` (`chmod +x`): generate + build + run in simulator.
- `.gitignore` (ignore generated `.xcodeproj`).
- Empty SwiftUI app that builds and runs.
- **First commit.**

## 2. API layer (1–1.5 h)
- `OpenRouterClient`: `URLSession.bytes(for:)` SSE streaming, parse `data:` lines.
- `Task`-based cancellation → **Stop**.
- Error types: no network, HTTP 429 (limit), decoding, generic.
- `APIKey.swift`: XOR-obfuscated key bytes, reconstructed at runtime.

## 3. Persistence (1 h)
- SwiftData `@Model` `Chat` and `Message`.
- `ModelContainer` in the App.
- Create / delete chats; list them.

## 4. UI & states (1.5–2 h)
- `NavigationSplitView`: chat list ↔ conversation.
- Message bubbles (user vs assistant).
- Empty state, error banner + **Retry**, loading/streaming indicator.
- Light & dark theme.

## 5. Testing (1 h)
- Build & run on iOS Simulator (iOS 26.5; target iOS 18).
- Offline test → error + Retry flow.
- Run `./Build.command` from a clean clone.

## 6. README & zip (30 min)
- Fill README template; copy & scrub `ai-logs/`; zip with `.git`.

## Architecture overview
```
Sources/
  App/        StreamingChatApp, ContentView (root split view)
  Models/     Chat, Message  (SwiftData @Model)
  Services/   OpenRouterClient (SSE), APIKey (XOR), ChatError
  Views/      ChatListView, ConversationView, MessageBubble, state views
  Resources/  Assets.xcassets
```

## Risk notes
- 8 GB RAM: keep one simulator at a time; build from terminal, not Xcode GUI.
- Only iOS 26.5 simulator present — target is iOS 18, tested on 26.5.
- Free-tier daily limits — minimal live API calls during dev.
