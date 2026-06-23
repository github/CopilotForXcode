# Code Completion Pipeline

This document describes the end-to-end flow for GitHub Copilot inline code completions, from user trigger to suggestion display and accept/reject.

## Overview

Completions travel through five distinct layers:

```
EditorExtension (sandboxed, in Xcode)
    │  XPC
    ▼
CommunicationBridge (non-sandboxed relay)
    │  XPC
    ▼
ExtensionService (background NSApp, all logic lives here)
    │
    ▼
GitHubCopilotService (Swift LSP client)
    │  stdio JSON-RPC
    ▼
copilot-language-server (Node.js, bundled)
    │  HTTPS
    ▼
GitHub Copilot API (cloud)
```

---

## Trigger modes

### On-demand

The user invokes **Get Suggestions** from the Xcode editor menu or a keyboard shortcut.

**Entry point:** `EditorExtension/GetSuggestionsCommand.swift`

```swift
func perform(with invocation: XCSourceEditorCommandInvocation, ...) {
    completionHandler(nil)   // return immediately so Xcode doesn't time out
    Task {
        let service = try getService()
        _ = try await service.getSuggestedCode(editorContent: .init(invocation))
    }
}
```

`completionHandler(nil)` is called *before* the async work begins. This is required: Xcode gives editor extension commands a short synchronous budget, so the reply must be returned before the XPC call completes.

### Realtime (prefetch)

`RealtimeSuggestionController` (in `Core/Sources/Service/`) watches for editor changes via the AX API (`XcodeInspector`) and calls `prefetchRealtimeSuggestions` on every keystroke after a debounce delay. The prefetched suggestion is cached in the filespace so it can be displayed immediately when the user pauses.

---

## Layer 1 — EditorExtension

**Files:** `EditorExtension/`

The source editor extension is sandboxed by Apple's XcodeKit framework. Its sole responsibility is to:

1. Package the current editor state into an `EditorContent` value:
   - `content` — full buffer text
   - `lines` — text lines as `[String]`
   - `cursorPosition` — `(line, character)` from the last selection
   - `uti` — file UTI (used for language detection downstream)
   - `tabSize`, `indentSize`, `usesTabsForIndentation`

2. Forward to `XPCExtensionService` via XPC.
3. On reply, apply the returned `UpdatedContent` to the buffer.

`EditorContent.init(_:XCSourceEditorCommandInvocation)` is defined in `EditorExtension/Helpers.swift`.

The extension cannot call GitHub APIs directly — it has no network entitlements and is sandboxed. All substantive work happens in `ExtensionService`.

---

## Layer 2 — XPC transport

**Files:** `Tool/Sources/XPCShared/`

### Protocol

`XPCServiceProtocol` is the `@objc` protocol that defines the raw XPC interface. All parameters are `Data` (JSON-encoded payloads) to satisfy the XPC serialisation requirement.

Completion-related methods:

| Method | Purpose |
|---|---|
| `getSuggestedCode` | Fetch and display the first suggestion |
| `getNextSuggestedCode` | Cycle to the next suggestion |
| `getPreviousSuggestedCode` | Cycle to the previous suggestion |
| `getSuggestionAcceptedCode` | Accept the current suggestion |
| `getSuggestionRejectedCode` | Reject the current suggestion |
| `getRealtimeSuggestedCode` | Return a prefetched realtime suggestion |
| `prefetchRealtimeSuggestions` | Prime the cache ahead of a user pause |
| `getNESSuggestionAcceptedCode` | Accept a Next Edit Suggestion (NES) |
| `getNESSuggestionRejectedCode` | Reject a Next Edit Suggestion (NES) |

### Client wrapper

`XPCExtensionService` (in `XPCShared/`) wraps the raw protocol with a type-safe async API. `suggestionRequest(_:_:)` handles encode/decode and routes through `CommunicationBridge`:

```swift
private func suggestionRequest(_ editorContent: EditorContent, _ fn: ...) async throws -> UpdatedContent? {
    let data = try JSONEncoder().encode(editorContent)
    return try await withXPCServiceConnected { service, continuation in
        fn(service)(data) { updatedData, error in ... }
    }
}
```

### CommunicationBridge

Because the `EditorExtension` is sandboxed, it cannot connect directly to `ExtensionService`. `CommunicationBridge` is a trusted, non-sandboxed intermediary that holds a persistent XPC connection to `ExtensionService` and relays requests. It is registered in `EditorExtension.entitlements` under `com.apple.security.temporary-exception.mach-lookup.global-name`.

---

## Layer 3 — ExtensionService / XPCService

**Files:** `Core/Sources/Service/`

`XPCService` (in `Core/Sources/Service/`) implements `XPCServiceProtocol`. On receiving `getSuggestedCode`:

1. **Decode** `Data` → `EditorContent`.
2. **Locate workspace** — uses `XcodeInspector` (AX API) to find the open workspace and the active file URL.
3. **Delegate to `WorkspaceSuggestionService`** — which manages per-filespace suggestion state (current index, suggestion list, snapshot for invalidation checks).
4. **Inject into filespace** — `SuggestionInjector` computes the line modifications.
5. **Encode** `UpdatedContent` → `Data` and reply.

---

## Layer 4 — Suggestion service & middleware

**Files:** `Core/Sources/SuggestionService/`

`SuggestionService` is an `actor` that wraps a `SuggestionServiceProvider` with a middleware chain:

```swift
for middleware in middlewares.reversed() {
    getSuggestion = { [getSuggestion] request, workspaceInfo in
        try await middleware.getSuggestion(request, configuration: configuration, next: getSuggestion)
    }
}
return try await getSuggestion(request, workspaceInfo)
```

### Active middleware

**`PostProcessingSuggestionServiceMiddleware`** (in `Tool/Sources/SuggestionProvider/`) filters completions from the LSP before they reach the UI:

- Removes suggestions whose text is entirely whitespace or newlines.
- Trims trailing whitespace/newlines from suggestion text.
- Discards no-op suggestions (text that would produce no change after being accepted).

### Provider

`GitHubCopilotSuggestionService` (in `Tool/Sources/GitHubCopilotService/Services/`) is the concrete provider. It resolves the per-workspace `GitHubCopilotService` instance and calls:

- `getCompletions(fileURL:content:cursorPosition:...)` for standard completions
- `getCopilotInlineEdit(fileURL:content:cursorPosition:)` for NES (Next Edit Suggestions)

---

## Layer 5 — LSP client

**Files:** `Tool/Sources/GitHubCopilotService/LanguageServer/`

### GitHubCopilotService

`GitHubCopilotService` is the main LSP client. It:

- Initialises and manages a `CopilotLocalProcessServer` (the stdio subprocess).
- Syncs the text document lifecycle to the LSP server (`notifyOpenTextDocument`, `notifyChangeTextDocument`, `notifyCloseTextDocument`).
- Translates Swift types to `GitHubCopilotDoc` for outbound requests.
- Translates `GitHubCopilotCodeSuggestion` responses back to `CodeSuggestion`.

### LSP request methods

| Swift type | JSON-RPC method | Purpose |
|---|---|---|
| `GetCompletionsCycling` | `getCompletionsCycling` | Fetch a set of completions to cycle through |
| `InlineCompletion` | `textDocument/inlineCompletion` | Standard LSP inline completion |
| `CopilotInlineEdit` | `textDocument/copilotInlineEdit` | NES / Next Edit Suggestion |
| `NotifyAccepted` | `notifyAccepted` | Telemetry: user accepted a suggestion |
| `NotifyRejected` | `notifyRejected` | Telemetry: user rejected suggestions |
| `NotifyShown` | `notifyShown` | Telemetry: suggestion was displayed |

### CopilotLocalProcessServer

`CopilotLocalProcessServer` spawns `copilot-language-server` via `stdio` and multiplexes JSON-RPC 2.0 over a pipe.

In-flight request IDs are tracked so completions can be cancelled via `$/cancelRequest` when the user types again before a response arrives. This avoids stale suggestions from slow network responses.

Inbound notifications from the server are forwarded via a `PassthroughSubject`:

| Notification | Meaning |
|---|---|
| `didChangeStatus` | Updates the status-bar indicator (Normal / Warning / Error / Inactive) |
| `$/progress` | Work-done progress for conversation turns |
| `copilot/didChangeFeatureFlags` | Feature flag updates |
| `copilot/mcpTools` | MCP tool availability changes |
| `$/copilot/rateLimitWarning` | Rate limit approaching |
| `copilot/quotaWarning` | Quota approaching |
| `$/copilot/compressionStarted/Completed` | Context window compression events |

### Document sync

`GitHubCopilotExtension` implements `BuiltinExtension` and receives document lifecycle callbacks from the workspace:

- `workspace(_:didOpenDocumentAt:)` — skips files >15 MB; sends `textDocument/didOpen`
- `workspace(_:didUpdateDocumentAt:content:contentChanges:)` — sends `textDocument/didChange`; on `-32602` (parameter incorrect), reopens the document
- `workspace(_:didSaveDocumentAt:)` — sends `textDocument/didSave`
- `workspace(_:didCloseDocumentAt:)` — sends `textDocument/didClose`

---

## Suggestion injection

**Files:** `Core/Sources/SuggestionInjector/`

`SuggestionInjector` converts a `CodeSuggestion` into a `[Modification]` list that can be applied to the editor buffer:

- Handles partial overlaps between typed text and the suggestion prefix.
- Correctly accounts for multi-byte characters (emoji, CJK) in both the existing code and the suggestion text.
- Supports multi-line replacements, appending to line ends, and inserting from a previous line.

`UpdatedContent` carries:
- `modifications: [Modification]` — list of `(line, newContent)` pairs
- `newSelection: CursorRange?` — where to place the cursor after applying

---

## Accept / Reject cycle

```
User presses Tab / accept shortcut
    │
    ▼
AcceptSuggestionCommand.perform(...)
    │  XPC
    ▼
XPCService.getSuggestionAcceptedCode(editorContent:)
    │
    ├── WorkspaceSuggestionService: mark suggestion accepted in filespace
    ├── SuggestionInjector: compute modifications
    └── GitHubCopilotSuggestionService.notifyAccepted(suggestion)
            │  LSP: notifyAccepted { uuid, acceptedLength }
            ▼
        copilot-language-server (telemetry to GitHub)
    │
    ▼
invocation.accept(updatedContent)
    – applies modifications to buffer.lines
    – repositions cursor via buffer.selections
```

Rejection follows the same path, calling `notifyRejected { uuids: [...] }` on the LSP server.

---

## Key source files

| File | Layer | Role |
|---|---|---|
| `EditorExtension/GetSuggestionsCommand.swift` | Extension | On-demand trigger |
| `EditorExtension/Helpers.swift` | Extension | `EditorContent` initialisation, buffer mutation |
| `Tool/Sources/XPCShared/XPCServiceProtocol.swift` | XPC | Raw protocol definition |
| `Tool/Sources/XPCShared/XPCExtensionService.swift` | XPC | Type-safe async wrapper |
| `Core/Sources/Service/XPCService.swift` | Service | Protocol implementation |
| `Core/Sources/Service/RealtimeSuggestionController.swift` | Service | Keystroke-driven prefetch |
| `Core/Sources/SuggestionService/SuggestionService.swift` | Middleware | Middleware chain |
| `Tool/Sources/SuggestionProvider/` | Middleware | Post-processing filters |
| `Tool/Sources/GitHubCopilotService/Services/GitHubCopilotSuggestionService.swift` | LSP | Provider adapter |
| `Tool/Sources/GitHubCopilotService/LanguageServer/GitHubCopilotService.swift` | LSP | LSP client |
| `Tool/Sources/GitHubCopilotService/LanguageServer/CopilotLocalProcessServer.swift` | LSP | stdio subprocess management |
| `Tool/Sources/GitHubCopilotService/LanguageServer/GitHubCopilotRequest.swift` | LSP | JSON-RPC request types |
| `Core/Sources/SuggestionInjector/` | Injection | Buffer modification computation |
