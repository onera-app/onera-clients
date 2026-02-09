//
//  DemoMode.swift
//  Onera
//
//  Demo/Review Mode for App Store submission
//  Activates by pressing and holding the login screen header for 10 seconds
//

import Foundation
import SwiftUI
import Observation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Notification Name

extension Notification.Name {
    static let demoModeActivated = Notification.Name("demoModeActivated")
}

// MARK: - Demo Mode Manager

@MainActor
@Observable
final class DemoModeManager {
    
    // MARK: - Singleton
    
    static let shared = DemoModeManager()
    
    // MARK: - State
    
    /// Whether demo mode is currently active
    private(set) var isActive = false
    
    /// Whether demo mode was activated this session
    private(set) var wasActivatedThisSession = false
    
    // MARK: - Configuration
    
    /// Number of taps required to activate demo mode
    static let requiredTaps = 10
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Actions
    
    /// Activates demo mode - the activation handler will be called after UI updates
    func activate() {
        guard !isActive else { return }
        
        isActive = true
        wasActivatedThisSession = true
        
        print("[DemoMode] Demo mode activated")
        
        // Platform-specific feedback
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        #elseif os(macOS)
        NSSound.beep()
        #endif
        
        // Post notification for any observers (used for auto-login)
        NotificationCenter.default.post(name: .demoModeActivated, object: nil)
    }
    
    /// Deactivates demo mode (e.g., on sign out)
    func deactivate() {
        isActive = false
        print("[DemoMode] Demo mode deactivated")
    }
    
    /// Resets demo mode completely
    func reset() {
        isActive = false
        wasActivatedThisSession = false
    }
}

// MARK: - Demo Mode View Modifier

/// View modifier that adds demo mode activation gesture (10 taps)
struct DemoModeActivationModifier: ViewModifier {
    
    @State private var tapCount = 0
    @State private var lastTapTime: Date?
    @State private var showActivationFeedback = false
    
    /// Number of taps required to activate demo mode
    private let requiredTaps = 10
    
    /// Maximum time between taps before count resets (in seconds)
    private let tapTimeout: TimeInterval = 1.5
    
    func body(content: Content) -> some View {
        content
            .overlay {
                // Activation feedback
                if showActivationFeedback {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        
                        Text("Demo Mode Activated")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Text("Signing in...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onTapGesture {
                handleTap()
            }
    }
    
    private func handleTap() {
        let now = Date()
        
        // Reset count if too much time has passed since last tap
        if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) > tapTimeout {
            tapCount = 0
        }
        
        tapCount += 1
        lastTapTime = now
        
        // Light feedback on each tap
        #if os(iOS)
        let lightGenerator = UIImpactFeedbackGenerator(style: .light)
        lightGenerator.impactOccurred()
        #elseif os(macOS)
        // Subtle visual feedback handled by tap count logging
        #endif
        
        // Show progress feedback after 5 taps
        if tapCount >= 5 && tapCount < requiredTaps {
            print("[DemoMode] \(requiredTaps - tapCount) more taps to activate...")
        }
        
        // Check if we've reached the required tap count
        if tapCount >= requiredTaps {
            completeActivation()
        }
    }
    
    private func completeActivation() {
        tapCount = 0
        lastTapTime = nil
        
        // Strong feedback on activation
        #if os(iOS)
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        heavyGenerator.impactOccurred()
        #elseif os(macOS)
        NSSound.beep()
        #endif
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showActivationFeedback = true
        }
        
        // Activate demo mode
        DemoModeManager.shared.activate()
        
        // Hide feedback after a delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    showActivationFeedback = false
                }
            }
        }
    }
}

extension View {
    /// Adds demo mode activation gesture (10 rapid taps)
    func demoModeActivation() -> some View {
        modifier(DemoModeActivationModifier())
    }
}

// MARK: - Demo Data

enum DemoData {
    
    // MARK: - Demo User
    
    static let demoUser = User(
        id: "demo-user-001",
        email: "reviewer@apple.com",
        firstName: "App",
        lastName: "Reviewer",
        imageURL: nil,
        createdAt: Date()
    )
    
    // MARK: - Demo Credentials
    
    static let demoCredentials: [DecryptedCredential] = [
        DecryptedCredential(
            id: "demo-anthropic",
            provider: .anthropic,
            name: "Claude API",
            apiKey: "demo-key-anthropic",
            baseUrl: nil,
            orgId: nil,
            config: nil
        ),
        DecryptedCredential(
            id: "demo-openai",
            provider: .openai,
            name: "OpenAI",
            apiKey: "demo-key-openai",
            baseUrl: nil,
            orgId: nil,
            config: nil
        )
    ]
    
    // MARK: - Demo Models
    
    static let demoModels: [ModelOption] = [
        ModelOption(
            id: "demo-anthropic:claude-sonnet-4-20250514",
            name: "Claude Sonnet 4",
            provider: .anthropic,
            credentialId: "demo-anthropic"
        ),
        ModelOption(
            id: "demo-openai:gpt-4o",
            name: "GPT-4o",
            provider: .openai,
            credentialId: "demo-openai"
        )
    ]
    
    // MARK: - Demo Chats
    
    static let demoChats: [ChatSummary] = [
        ChatSummary(
            id: "demo-chat-1",
            title: "Swift async/await patterns",
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-3600)
        ),
        ChatSummary(
            id: "demo-chat-2",
            title: "React best practices",
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date().addingTimeInterval(-86400)
        ),
        ChatSummary(
            id: "demo-chat-3",
            title: "Database optimization strategies",
            createdAt: Date().addingTimeInterval(-172800),
            updatedAt: Date().addingTimeInterval(-172800)
        )
    ]
    
    static func demoChat(id: String) -> Chat {
        switch id {
        case "demo-chat-1":
            return Chat(
                id: id,
                title: "Swift async/await patterns",
                messages: [
                    Message(role: .user, content: "Can you explain async/await in Swift?"),
                    Message(role: .assistant, content: """
                        Absolutely! Async/await in Swift makes asynchronous code much easier to read and write.
                        
                        Here's a simple example:
                        
                        ```swift
                        func fetchUserData() async throws -> User {
                            let url = URL(string: "https://api.example.com/user")!
                            let (data, _) = try await URLSession.shared.data(from: url)
                            return try JSONDecoder().decode(User.self, from: data)
                        }
                        
                        // Calling it:
                        Task {
                            do {
                                let user = try await fetchUserData()
                                print("Got user: \\(user.name)")
                            } catch {
                                print("Error: \\(error)")
                            }
                        }
                        ```
                        
                        Key points:
                        - `async` marks a function as asynchronous
                        - `await` suspends execution until the result is ready
                        - `Task` creates a new async context
                        - Error handling works naturally with `try`/`catch`
                        """)
                ],
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-3600)
            )
            
        case "demo-chat-2":
            return Chat(
                id: id,
                title: "React best practices",
                messages: [
                    Message(role: .user, content: "What are the best practices for React state management?"),
                    Message(role: .assistant, content: """
                        Great question! Here are the key best practices for React state management:
                        
                        **1. Start Simple**
                        - Use `useState` for local component state
                        - Use `useReducer` for complex local state
                        
                        **2. Lift State When Needed**
                        - Move state up to common ancestors when multiple components need it
                        
                        **3. Consider Context for Global State**
                        ```jsx
                        const ThemeContext = createContext();
                        
                        function App() {
                            return (
                                <ThemeContext.Provider value="dark">
                                    <MyComponent />
                                </ThemeContext.Provider>
                            );
                        }
                        ```
                        
                        **4. Use Libraries for Complex Apps**
                        - Zustand (simple, hooks-based)
                        - Redux Toolkit (robust, scalable)
                        - Jotai/Recoil (atomic state)
                        
                        **5. Avoid Over-Engineering**
                        - Don't add state management libraries until you need them
                        - Keep state as close to where it's used as possible
                        """)
                ],
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-86400)
            )
            
        default:
            return Chat(
                id: id,
                title: "Demo Chat",
                messages: [],
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }
    
    // MARK: - Demo Responses
    
    /// Smart demo responses based on user input
    nonisolated static func generateResponse(for userMessage: String) -> String {
        let lowercased = userMessage.lowercased()
        
        // Programming topics
        if lowercased.contains("swift") {
            return """
                Swift is a powerful, modern programming language developed by Apple.
                
                Here are some key features:
                
                **1. Type Safety**
                Swift is type-safe, which helps you catch errors at compile time.
                
                **2. Optionals**
                ```swift
                var name: String? = nil
                if let unwrapped = name {
                    print("Hello, \\(unwrapped)")
                }
                ```
                
                **3. Modern Syntax**
                - Trailing closures
                - Property wrappers
                - Result builders
                
                Is there something specific about Swift you'd like to explore?
                """
        }
        
        if lowercased.contains("python") {
            return """
                Python is an excellent choice for many applications!
                
                **Common Use Cases:**
                - Data Science & Machine Learning
                - Web Development (Django, Flask)
                - Automation & Scripting
                - API Development
                
                **Example Code:**
                ```python
                # Simple list comprehension
                squares = [x**2 for x in range(10)]
                
                # Async function
                async def fetch_data(url):
                    async with aiohttp.ClientSession() as session:
                        async with session.get(url) as response:
                            return await response.json()
                ```
                
                What aspect of Python interests you most?
                """
        }
        
        if lowercased.contains("javascript") || lowercased.contains("react") || lowercased.contains("node") {
            return """
                JavaScript is the backbone of modern web development!
                
                **Modern JS Features:**
                - Arrow functions
                - Destructuring
                - Async/await
                - Modules (ES6+)
                
                **React Example:**
                ```jsx
                function Counter() {
                    const [count, setCount] = useState(0);
                    
                    return (
                        <button onClick={() => setCount(c => c + 1)}>
                            Count: {count}
                        </button>
                    );
                }
                ```
                
                Would you like me to dive deeper into any JavaScript topic?
                """
        }
        
        // General AI/coding assistant responses
        if lowercased.contains("help") || lowercased.contains("can you") {
            return """
                I'd be happy to help! I can assist you with:
                
                **📝 Writing & Editing**
                - Code review and optimization
                - Documentation
                - Technical writing
                
                **💻 Programming**
                - Swift, Python, JavaScript, and more
                - Debugging
                - Architecture advice
                
                **🔍 Research & Analysis**
                - Explaining concepts
                - Comparing technologies
                - Best practices
                
                What would you like to explore today?
                """
        }
        
        if lowercased.contains("hello") || lowercased.contains("hi") || lowercased.contains("hey") {
            return """
                Hello! 👋 Welcome to Onera!
                
                I'm your AI assistant, ready to help with:
                - Answering questions
                - Writing and reviewing code
                - Brainstorming ideas
                - Explaining complex topics
                
                Feel free to ask me anything. What's on your mind?
                """
        }
        
        // Default intelligent response
        return """
            That's a great question! Let me help you with that.
            
            Based on your message, here are some thoughts:
            
            **Key Points:**
            - I can provide detailed explanations
            - Code examples when relevant
            - Step-by-step guidance
            
            **Next Steps:**
            1. Could you provide more context?
            2. What specific aspect interests you most?
            3. Are there any constraints I should know about?
            
            I'm here to help you dive deeper into any topic. What would you like to explore?
            """
    }
}
