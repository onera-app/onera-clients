package chat.onera.mobile.demo

import chat.onera.mobile.domain.model.Credential
import chat.onera.mobile.domain.model.LLMProvider
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.domain.model.MessageRole
import chat.onera.mobile.domain.model.User
import chat.onera.mobile.presentation.features.main.ModelProvider
import chat.onera.mobile.presentation.features.main.model.ChatSummary
import chat.onera.mobile.presentation.features.main.model.ModelOption

/**
 * Demo data for Play Store review mode.
 * 
 * Provides mock users, credentials, chats, and intelligent responses
 * so reviewers can test the app without real API keys.
 */
object DemoData {
    
    // ===== Demo User =====
    
    val demoUser = User(
        id = "demo-user-001",
        email = "reviewer@google.com",
        displayName = "Play Store Reviewer",
        avatarUrl = null,
        hasE2EEKeys = true
    )
    
    // ===== Demo Credentials =====
    
    /**
     * Returns demo credentials using domain model.
     */
    fun getDemoCredentials(): List<Credential> = listOf(
        Credential(
            id = "demo-anthropic",
            provider = LLMProvider.ANTHROPIC,
            name = "Claude API (Demo)",
            apiKey = "demo-key-anthropic"
        ),
        Credential(
            id = "demo-openai",
            provider = LLMProvider.OPENAI,
            name = "OpenAI (Demo)",
            apiKey = "demo-key-openai"
        )
    )
    
    // ===== Demo Models =====
    
    val demoModels = listOf(
        ModelOption(
            id = "claude-sonnet-4-20250514",
            displayName = "Claude Sonnet 4",
            provider = ModelProvider.ANTHROPIC,
            credentialId = "demo-anthropic"
        ),
        ModelOption(
            id = "gpt-4o",
            displayName = "GPT-4o",
            provider = ModelProvider.OPENAI,
            credentialId = "demo-openai"
        )
    )
    
    // ===== Demo Chats =====
    
    val demoChatSummaries = listOf(
        ChatSummary(
            id = "demo-chat-1",
            title = "Kotlin coroutines patterns",
            lastMessage = "Here's how to use Flow effectively...",
            updatedAt = System.currentTimeMillis() - 3600_000, // 1 hour ago
            isEncrypted = true
        ),
        ChatSummary(
            id = "demo-chat-2",
            title = "Android Compose best practices",
            lastMessage = "State hoisting is a key pattern...",
            updatedAt = System.currentTimeMillis() - 86400_000, // 1 day ago
            isEncrypted = true
        ),
        ChatSummary(
            id = "demo-chat-3",
            title = "API design strategies",
            lastMessage = "REST vs GraphQL depends on...",
            updatedAt = System.currentTimeMillis() - 172800_000, // 2 days ago
            isEncrypted = true
        )
    )
    
    fun getDemoChatMessages(chatId: String): List<Message> {
        return when (chatId) {
            "demo-chat-1" -> listOf(
                Message(
                    id = "msg-1-1",
                    chatId = chatId,
                    role = MessageRole.USER,
                    content = "Can you explain Kotlin coroutines and Flow?",
                    createdAt = System.currentTimeMillis() - 3700_000
                ),
                Message(
                    id = "msg-1-2",
                    chatId = chatId,
                    role = MessageRole.ASSISTANT,
                    content = """
                        Absolutely! Kotlin coroutines make asynchronous programming much simpler.
                        
                        **Coroutines Basics:**
                        ```kotlin
                        suspend fun fetchUser(): User {
                            return withContext(Dispatchers.IO) {
                                api.getUser()
                            }
                        }
                        
                        // Calling it:
                        viewModelScope.launch {
                            val user = fetchUser()
                            _state.value = state.value.copy(user = user)
                        }
                        ```
                        
                        **Flow for Streams:**
                        ```kotlin
                        fun observeMessages(): Flow<List<Message>> = flow {
                            while (true) {
                                emit(repository.getMessages())
                                delay(5000) // Poll every 5 seconds
                            }
                        }
                        
                        // Collecting in ViewModel:
                        observeMessages()
                            .onEach { messages -> updateState(messages) }
                            .launchIn(viewModelScope)
                        ```
                        
                        Key points:
                        - `suspend` marks a function as suspendable
                        - `Flow` is cold - it only runs when collected
                        - Use `StateFlow` for UI state
                        - `viewModelScope` auto-cancels on ViewModel clear
                    """.trimIndent(),
                    createdAt = System.currentTimeMillis() - 3600_000
                )
            )
            
            "demo-chat-2" -> listOf(
                Message(
                    id = "msg-2-1",
                    chatId = chatId,
                    role = MessageRole.USER,
                    content = "What are the best practices for Jetpack Compose state management?",
                    createdAt = System.currentTimeMillis() - 86500_000
                ),
                Message(
                    id = "msg-2-2",
                    chatId = chatId,
                    role = MessageRole.ASSISTANT,
                    content = """
                        Great question! Here are the key best practices for Compose state:
                        
                        **1. State Hoisting**
                        Move state up to make composables reusable:
                        ```kotlin
                        @Composable
                        fun Counter(
                            count: Int,
                            onIncrement: () -> Unit
                        ) {
                            Button(onClick = onIncrement) {
                                Text("Count: ${'$'}count")
                            }
                        }
                        ```
                        
                        **2. Remember for Local State**
                        ```kotlin
                        @Composable
                        fun ExpandableCard() {
                            var expanded by remember { mutableStateOf(false) }
                            // ...
                        }
                        ```
                        
                        **3. ViewModel for Screen State**
                        ```kotlin
                        @HiltViewModel
                        class ChatViewModel : ViewModel() {
                            private val _state = MutableStateFlow(ChatState())
                            val state = _state.asStateFlow()
                        }
                        
                        @Composable
                        fun ChatScreen(viewModel: ChatViewModel = hiltViewModel()) {
                            val state by viewModel.state.collectAsStateWithLifecycle()
                        }
                        ```
                        
                        **4. Avoid Side Effects in Composition**
                        Use `LaunchedEffect`, `SideEffect`, or `DisposableEffect`
                        
                        **5. Use Stable Types**
                        Mark classes with `@Stable` or `@Immutable` for better recomposition
                    """.trimIndent(),
                    createdAt = System.currentTimeMillis() - 86400_000
                )
            )
            
            else -> emptyList()
        }
    }
    
    // ===== Demo Response Generation =====
    
    /**
     * Generates intelligent demo responses based on user input.
     * Used when demo mode is active to simulate AI responses.
     */
    fun generateResponse(userMessage: String): String {
        val lowercased = userMessage.lowercase()
        
        // Kotlin/Android topics
        if (lowercased.contains("kotlin") || lowercased.contains("android")) {
            return """
                Kotlin is the preferred language for Android development!
                
                **Key Features:**
                - Null safety with `?` and `!!`
                - Extension functions
                - Coroutines for async
                - Data classes
                
                **Example:**
                ```kotlin
                data class User(
                    val id: String,
                    val name: String,
                    val email: String?
                )
                
                fun User.displayName(): String {
                    return email?.let { "${'$'}name (${'$'}it)" } ?: name
                }
                ```
                
                Is there a specific Kotlin topic you'd like to explore?
            """.trimIndent()
        }
        
        // Swift/iOS topics
        if (lowercased.contains("swift") || lowercased.contains("ios") || lowercased.contains("swiftui")) {
            return """
                Swift is Apple's powerful, modern programming language!
                
                **Key Features:**
                - Type safety with optionals
                - Protocol-oriented programming
                - SwiftUI for declarative UI
                - async/await concurrency
                
                **SwiftUI Example:**
                ```swift
                struct ContentView: View {
                    @State private var count = 0
                    
                    var body: some View {
                        VStack {
                            Text("Count: \(count)")
                            Button("Increment") {
                                count += 1
                            }
                        }
                    }
                }
                ```
                
                What aspect of Swift would you like to learn more about?
            """.trimIndent()
        }
        
        // Python topics
        if (lowercased.contains("python")) {
            return """
                Python is excellent for many applications!
                
                **Common Use Cases:**
                - Data Science & Machine Learning
                - Web Development (Django, Flask)
                - Automation & Scripting
                - API Development
                
                **Example Code:**
                ```python
                # List comprehension
                squares = [x**2 for x in range(10)]
                
                # Async function
                async def fetch_data(url: str) -> dict:
                    async with aiohttp.ClientSession() as session:
                        async with session.get(url) as response:
                            return await response.json()
                ```
                
                What aspect of Python interests you most?
            """.trimIndent()
        }
        
        // JavaScript/React topics
        if (lowercased.contains("javascript") || lowercased.contains("react") || lowercased.contains("typescript")) {
            return """
                JavaScript/TypeScript powers modern web development!
                
                **Modern Features:**
                - Arrow functions & destructuring
                - Async/await
                - ES modules
                - TypeScript for type safety
                
                **React Example:**
                ```tsx
                function Counter() {
                    const [count, setCount] = useState(0);
                    
                    return (
                        <button onClick={() => setCount(c => c + 1)}>
                            Count: {count}
                        </button>
                    );
                }
                ```
                
                Would you like to dive deeper into any JavaScript topic?
            """.trimIndent()
        }
        
        // Greetings
        if (lowercased.contains("hello") || lowercased.contains("hi") || lowercased.contains("hey")) {
            return """
                Hello! Welcome to Onera!
                
                I'm your AI assistant, ready to help with:
                - Answering questions
                - Writing and reviewing code
                - Brainstorming ideas
                - Explaining complex topics
                
                Feel free to ask me anything. What's on your mind?
            """.trimIndent()
        }
        
        // Help requests
        if (lowercased.contains("help") || lowercased.contains("can you")) {
            return """
                I'd be happy to help! I can assist you with:
                
                **Writing & Editing**
                - Code review and optimization
                - Documentation
                - Technical writing
                
                **Programming**
                - Kotlin, Swift, Python, JavaScript, and more
                - Debugging assistance
                - Architecture advice
                
                **Research & Analysis**
                - Explaining concepts
                - Comparing technologies
                - Best practices
                
                What would you like to explore today?
            """.trimIndent()
        }
        
        // Default response
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
            
            I'm here to help you dive deeper into any topic!
        """.trimIndent()
    }
}
