---
name: watchos-patterns
description: watchOS native patterns - companion apps, WatchConnectivity, complications, quick interactions
---

# watchOS Native Patterns

Comprehensive reference for building watchOS companion apps with native patterns.

---

## Companion App Philosophy

**watchOS apps should be companions to iPhone, NOT standalone apps.**

### Core Principles

| Principle | Implementation |
|-----------|----------------|
| Sync from iPhone | WatchConnectivity for data |
| Quick interactions | < 10 seconds per session |
| No authentication | iPhone handles auth |
| Minimal storage | Cache only |
| Glanceable | Summary, not full detail |

---

## App Structure

### Entry Point

```swift
import SwiftUI
import WatchKit

@main
struct OneraWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var delegate
    @State private var appState = WatchAppState.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.watchAppState, appState)
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchConnectivityManager.shared.activate()
    }
    
    func applicationDidBecomeActive() {
        WatchConnectivityManager.shared.requestSync()
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                WatchConnectivityManager.shared.handleBackgroundTask()
                connectivityTask.setTaskCompletedWithSnapshot(false)
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
```

---

## WatchConnectivity

### Manager

```swift
import WatchConnectivity

@MainActor
@Observable
final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()
    
    private(set) var isReachable = false
    private(set) var recentChats: [WatchChat] = []
    
    private var session: WCSession?
    
    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    func requestSync() {
        guard let session, session.isReachable else { return }
        session.sendMessage(["action": "sync"], replyHandler: nil)
    }
    
    func sendQuickReply(_ reply: String, to chatId: String) {
        guard let session, session.isReachable else { return }
        session.sendMessage([
            "action": "quickReply",
            "chatId": chatId,
            "content": reply
        ], replyHandler: nil)
    }
    
    func handleBackgroundTask() {
        // Process any pending transfers
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
            if session.isReachable { requestSync() }
        }
    }
    
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext context: [String: Any]
    ) {
        Task { @MainActor in
            if let data = context["recentChats"] as? Data {
                recentChats = (try? JSONDecoder().decode([WatchChat].self, from: data)) ?? []
            }
        }
    }
}
```

---

## Navigation

### TabView with Vertical Paging

```swift
struct MainView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ChatListView()
                .tag(0)
            
            QuickReplyView()
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}
```

### NavigationStack

```swift
struct ChatListView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            List(recentChats) { chat in
                NavigationLink(value: chat) {
                    ChatRow(chat: chat)
                }
            }
            .navigationTitle("Chats")
            .navigationDestination(for: WatchChat.self) { chat in
                ChatDetailView(chat: chat)
            }
        }
    }
}
```

---

## Native Components

### List

```swift
List {
    ForEach(items) { item in
        NavigationLink(value: item) {
            HStack {
                Image(systemName: item.icon)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
.listStyle(.carousel)  // or .plain, .elliptical
```

### Buttons

```swift
// Primary
Button("Send") { }
    .buttonStyle(.borderedProminent)

// Secondary
Button("Cancel") { }
    .buttonStyle(.bordered)

// Destructive
Button("Delete", role: .destructive) { }
```

### Text Input

```swift
// Dictation (preferred)
Button {
    presentTextInput()
} label: {
    Label("Dictate", systemImage: "mic.fill")
}

// Pre-set quick replies
ForEach(quickReplies, id: \.self) { reply in
    Button(reply) {
        sendReply(reply)
    }
}

// Text input controller
func presentTextInput() {
    WKExtension.shared().visibleInterfaceController?.presentTextInputController(
        withSuggestions: quickReplies,
        allowedInputMode: .plain
    ) { results in
        if let text = results?.first as? String {
            sendReply(text)
        }
    }
}
```

---

## Quick Reply View

```swift
struct QuickReplyView: View {
    let quickReplies = ["Got it!", "On my way", "Can't talk now", "Call me"]
    
    var body: some View {
        List {
            Section("Quick Replies") {
                ForEach(quickReplies, id: \.self) { reply in
                    Button(reply) {
                        sendReply(reply)
                    }
                }
            }
            
            Section {
                Button {
                    presentDictation()
                } label: {
                    Label("Dictate", systemImage: "mic.fill")
                }
            }
        }
        .navigationTitle("Reply")
    }
}
```

---

## State Views

### Disconnected

```swift
struct DisconnectedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            
            Text("iPhone Required")
                .font(.headline)
            
            Text("Open Onera on your iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
```

### Unauthenticated

```swift
struct UnauthenticatedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            
            Text("Sign In Required")
                .font(.headline)
            
            Text("Sign in on your iPhone first")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
```

---

## Complications

### Timeline Entry

```swift
struct OneraEntry: TimelineEntry {
    let date: Date
    let unreadCount: Int
    let lastChatTitle: String?
}
```

### Complication Views

```swift
// Circular
struct CircularComplication: View {
    var entry: OneraEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack {
                Image(systemName: "bubble.left.fill")
                if entry.unreadCount > 0 {
                    Text("\(entry.unreadCount)")
                        .font(.headline)
                }
            }
        }
    }
}

// Rectangular
struct RectangularComplication: View {
    var entry: OneraEntry
    
    var body: some View {
        HStack {
            Image(systemName: "bubble.left.fill")
            
            VStack(alignment: .leading) {
                Text("Onera")
                    .font(.headline)
                if let title = entry.lastChatTitle {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// Inline
struct InlineComplication: View {
    var entry: OneraEntry
    
    var body: some View {
        Label("\(entry.unreadCount) unread", systemImage: "bubble.left.fill")
    }
}
```

### Widget Configuration

```swift
@main
struct OneraWidgetBundle: WidgetBundle {
    var body: some Widget {
        OneraComplication()
    }
}

struct OneraComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "OneraComplication",
            provider: OneraTimelineProvider()
        ) { entry in
            OneraComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Onera")
        .description("See unread messages")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
```

---

## App State

```swift
@MainActor
@Observable
final class WatchAppState {
    static let shared = WatchAppState()
    
    private(set) var isConnected = false
    private(set) var isAuthenticated = false
    private(set) var recentChats: [WatchChat] = []
    
    private init() {
        observeConnectivity()
    }
    
    private func observeConnectivity() {
        // Observe WatchConnectivityManager changes
    }
}

// Environment
struct WatchAppStateKey: EnvironmentKey {
    @MainActor static let defaultValue = WatchAppState.shared
}

extension EnvironmentValues {
    var watchAppState: WatchAppState {
        get { self[WatchAppStateKey.self] }
        set { self[WatchAppStateKey.self] = newValue }
    }
}
```

---

## Design Guidelines

### Touch Targets

- Minimum **38 × 38 points**
- Buttons should fill width when possible

### Typography

```swift
.font(.headline)   // Primary text
.font(.body)       // Content
.font(.caption)    // Secondary
.font(.caption2)   // Tertiary
```

### Colors

Use system colors for automatic Dark/Light adaptation:

```swift
Color.primary
Color.secondary
Color.accentColor
```

---

## What NOT to Build

| Don't | Instead |
|-------|---------|
| Complex navigation | Simple NavigationStack |
| Long forms | Use iPhone |
| Full chat history | Show recent only |
| Custom auth | iPhone handles auth |
| Heavy processing | Process on iPhone |
| Settings management | Manage on iPhone |
| File attachments | View-only or iPhone |

---

## Accessibility

```swift
Button("Send") { }
    .accessibilityLabel("Send quick reply")
    .accessibilityHint("Sends message to current chat")

// Large text automatically supported with system fonts
Text("Title").font(.headline)
```
