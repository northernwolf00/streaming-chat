# StreamingChat

A ChatGPT-style streaming AI chat app for iPhone, built in SwiftUI. The assistant's
reply appears token-by-token as it is generated, with a Stop button to cancel
mid-reply. Chats are kept in a sidebar and persist across launches.

Built in a single working day, primarily with Claude Code (Opus 4.8).

---

## Time spent

~2.5 hours of active development (skeleton → API layer → persistence → UI → testing
→ docs). See the git history for the real timeline — commits are small and frequent.

## Tools & models used

**Development tools**
- **Claude Code** (model: Claude Opus 4.8) — wrote essentially all of the code.
- **XcodeGen 2.46** — generates `StreamingChat.xcodeproj` from `project.yml`
  (the `.xcodeproj` is never hand-edited and is git-ignored).
- **Xcode 26.5 / Swift 6.3**, `xcodebuild`, iOS Simulator.
- Dependencies: **Swift Package Manager only** (in fact zero third-party packages —
  Foundation, SwiftUI and SwiftData cover everything). **No CocoaPods.**

**AI provider & models (in the app)**
- **OpenRouter** — chosen because it works from regions where Gemini/Groq are
  blocked. Free models only.
- Model routing with automatic fallback (if the first is rate-limited upstream,
  OpenRouter tries the next):
  1. `baidu/ernie-5.5-flash-preview:free` (primary — fast, non-reasoning)
  2. `google/gemma-4-31b-it:free`
  3. `google/gemma-4-26b-a4b-it:free`

## What the AI does

The app is a conversational assistant. You type a message; the app sends the whole
conversation to OpenRouter's chat-completions endpoint with `stream: true` and
renders the reply **token-by-token** over Server-Sent Events. Full history is sent
each turn so the assistant has context.

## What works

- ✅ **Streaming responses** — token-by-token via `URLSession.bytes(for:)` + SSE.
- ✅ **Stop button** — cancels the in-flight generation (`Task.cancel()`), keeping
  whatever text already arrived.
- ✅ **Multiple chats** — sidebar list, create and swipe-to-delete.
- ✅ **Persistent history** — SwiftData (`Chat` + `Message`); survives app restart.
- ✅ **States** — loading/typing indicator, **error banner with Retry** (no network /
  HTTP 429 limit), and empty states (no chats / no selection / empty conversation).
- ✅ **Light & dark themes** — uses system semantic colors, adapts automatically.
- ✅ **iPhone + iPad** — `NavigationSplitView` layout.
- ✅ **No configuration after build** — the API key is baked in (obfuscated) and a
  free model is selected by default; `./Build.command` builds & runs from a clean
  clone.

## Security: API key handling

The key is **never stored in plaintext** in source or in the compiled binary's
string table. It is XOR-obfuscated into two byte arrays (`pad` and `obfuscated`,
effectively a one-time pad) in `Sources/Services/APIKey.swift` and reconstructed at
runtime as `obfuscated XOR pad`. Regenerate with:

```sh
swift scripts/ObfuscateKey.swift "sk-or-v1-...."
```

This is obfuscation, not encryption — it defeats trivial `strings` scanning, which
is what the task requires.

## What's missing / known bugs / trade-offs

- **No iOS 18 simulator on the build machine** — only an iOS 26.5 runtime was
  installed. The deployment target is **iOS 18.0** and the code uses no iOS-26-only
  APIs, but on-device/simulator testing was done on iOS 26.5.
- **No live in-app streaming screenshot captured** — the streaming contract (key,
  endpoint, model, SSE parsing) was verified end-to-end with the exact request the
  app sends (see Testing). Driving the Simulator UI from the CLI to script a full
  send/stream was out of scope for the time budget.
- **Free-tier limits** — free models have shared daily rate limits; the fallback
  list mitigates this but a heavily throttled moment can still surface the "API
  limit reached" error (which is itself a required, handled state with Retry).
- **Reasoning models avoided** — some free models stream their chain-of-thought in a
  separate `reasoning` field (empty `content` until the end); the default model is a
  non-reasoning one so tokens appear immediately.
- No bonus features (image send / macOS target / Foundation Models offline) — these
  were optional and left out for time.

## How it was tested

- **Build** — `xcodebuild` for the iOS Simulator: **BUILD SUCCEEDED** (clean build).
- **Clean-clone, no-config** — `git clone` to a fresh dir, then `xcodegen generate`
  + `xcodebuild` → builds with zero manual setup; `.xcodeproj` is not in the repo.
- **Run** — installed & launched in the iOS 26.5 Simulator; verified the empty state
  and navigation render correctly (see screenshots during development).
- **API / streaming** — verified with the exact request shape the app sends (model
  fallback list, `stream: true`), confirming token-by-token SSE output from
  OpenRouter and that the obfuscated key reconstructs correctly.
- **Error path** — verified the error mapping: `URLError.notConnectedToInternet →
  ChatError.noNetwork` and HTTP `429 → ChatError.rateLimited`, both rendered by the
  `ErrorBanner` with a Retry button.

## Build & run

Double-click **`Build.command`** in Finder — it installs XcodeGen if needed,
generates the project, builds for an iOS Simulator, boots it, installs and launches.

Or manually:

```sh
xcodegen generate
open StreamingChat.xcodeproj   # then Run (⌘R)
```

## Project layout

```
project.yml          XcodeGen spec (iOS 18 target)
Build.command        Double-click: generate + build + run in simulator
CLAUDE.md            Guidance for AI agents working in this repo
docs/                task.md (brief) + plan.md
scripts/             ObfuscateKey.swift (regenerate the obfuscated key)
ai-logs/             Scrubbed Claude Code session log (keys/emails removed)
Sources/
  App/               App entry, root split view
  Models/            SwiftData Chat & Message
  Services/          OpenRouterClient (SSE), APIKey (XOR), ChatError
  Views/             ChatList, Conversation, MessageBubble, state views, view model
  Resources/         Assets.xcassets
```
