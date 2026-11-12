# Task — StreamingChat

Build a ChatGPT-style AI chat app for iPhone in Swift, in roughly one working
day, using AI coding tools (Claude Code). Both the app **and** how effectively AI
tools were used are evaluated.

## Required features

### Streaming chat
- The AI reply appears token-by-token as it is generated (not all at once).
- A **Stop** button cancels the generation mid-reply.

### Multiple chats
- A list of chats on the left (ChatGPT-style).
- History persists across app restarts (SwiftData or Core Data).

### States
- **Loading** while waiting / streaming.
- **Error**: no internet, or API limit reached — with a **Retry** button.
- **Empty state**: shown when there are no chats.

### UI
- Clean iOS-style UI, light and dark themes.

## Optional / bonus (only if time remains)
- Image sending.
- macOS version (SwiftUI multiplatform target).
- iOS 26 Apple Foundation Models offline mode.
Lowest-effort bonus preferred: image send or Mac target.

## Project constraints
- **Minimum iOS 18.** Guard any iOS 26-only API with `#available`.
- **XcodeGen**: do not hand-create `.xcodeproj`; write `project.yml`.
- **`Build.command`** at repo root: double-click → `xcodegen generate` + build
  for the simulator. Must be `chmod +x`.
- Dependencies via **SPM only**. CocoaPods forbidden.

## AI API
- Free API. Recommended: **OpenRouter** (works from Russia; Gemini/Groq blocked
  there). Use a free model and don't exhaust the daily free limit in testing.
- API key must **not** be in plaintext — obfuscate (e.g. XOR to bytes, rebuild at
  runtime).
- Must work with **no configuration** after building.

## Deliverables (zip, including `.git`)
1. The project, with frequent commits.
2. `docs/` (task + plan) and `CLAUDE.md` at repo root.
3. `ai-logs/` — copied Claude Code logs with API keys / personal data removed.
4. `README` per template: time spent, tools & models used, what the AI does,
   what works, what's missing / known bugs, how it was tested.
