---
name: kotlin-mvi
description: MVI pattern implementation for Android with Kotlin
---

# MVI Pattern for Android

## Core Contracts

```kotlin
// Base interfaces
interface UiState
interface UiIntent
interface UiEffect
```

## State

Represents the complete UI state at any point in time.

```kotlin
data class ChatState(
    val isLoading: Boolean = false,
    val messages: List<Message> = emptyList(),
    val inputText: String = "",
    val isSending: Boolean = false,
    val isStreaming: Boolean = false,
    val streamingMessage: String = "",
    val selectedItem: Item? = null,
    val error: String? = null
) : UiState
```

### State Guidelines
- Immutable data class
- All UI-relevant data in one place
- No business logic in state
- Provide sensible defaults

## Intent

User actions and events that trigger state changes.

```kotlin
sealed interface ChatIntent : UiIntent {
    data object LoadData : ChatIntent
    data object Refresh : ChatIntent
    data class UpdateInput(val text: String) : ChatIntent
    data object SendMessage : ChatIntent
    data object StopStreaming : ChatIntent
    data class SelectItem(val item: Item) : ChatIntent
    data class DeleteItem(val id: String) : ChatIntent
    data object ClearError : ChatIntent
}
```

### Intent Guidelines
- Sealed interface for exhaustive when
- Data classes for intents with parameters
- Data objects for parameterless intents
- Name describes user action

## Effect

One-time events that don't affect state.

```kotlin
sealed interface ChatEffect : UiEffect {
    data class NavigateTo(val route: String) : ChatEffect
    data class ShowSnackbar(val message: String) : ChatEffect
    data object ScrollToBottom : ChatEffect
    data class CopyToClipboard(val text: String) : ChatEffect
    data object HideKeyboard : ChatEffect
}
```

### Effect Guidelines
- For navigation, toasts, snackbars
- Not persisted in state
- Consumed once by UI

## BaseViewModel

```kotlin
abstract class BaseViewModel<S : UiState, I : UiIntent, E : UiEffect>(
    initialState: S
) : ViewModel() {

    private val _state = MutableStateFlow(initialState)
    val state: StateFlow<S> = _state.asStateFlow()

    private val _effect = Channel<E>(Channel.BUFFERED)
    val effect: Flow<E> = _effect.receiveAsFlow()

    protected val currentState: S get() = _state.value

    fun sendIntent(intent: I) {
        handleIntent(intent)
    }

    protected abstract fun handleIntent(intent: I)

    protected fun updateState(reducer: S.() -> S) {
        _state.update { it.reducer() }
    }

    protected fun sendEffect(effect: E) {
        viewModelScope.launch {
            _effect.send(effect)
        }
    }
}
```

## ViewModel Implementation

```kotlin
@HiltViewModel
class ChatViewModel @Inject constructor(
    private val chatRepository: ChatRepository,
    private val sendMessageUseCase: SendMessageUseCase
) : BaseViewModel<ChatState, ChatIntent, ChatEffect>(ChatState()) {

    init {
        sendIntent(ChatIntent.LoadData)
    }

    override fun handleIntent(intent: ChatIntent) {
        when (intent) {
            is ChatIntent.LoadData -> loadData()
            is ChatIntent.Refresh -> refresh()
            is ChatIntent.UpdateInput -> updateState { copy(inputText = intent.text) }
            is ChatIntent.SendMessage -> sendMessage()
            is ChatIntent.StopStreaming -> stopStreaming()
            is ChatIntent.SelectItem -> selectItem(intent.item)
            is ChatIntent.DeleteItem -> deleteItem(intent.id)
            is ChatIntent.ClearError -> updateState { copy(error = null) }
        }
    }

    private fun loadData() {
        viewModelScope.launch {
            updateState { copy(isLoading = true) }
            
            chatRepository.getMessages()
                .onSuccess { messages ->
                    updateState { 
                        copy(messages = messages, isLoading = false, error = null) 
                    }
                }
                .onFailure { error ->
                    updateState { 
                        copy(isLoading = false, error = error.message) 
                    }
                    sendEffect(ChatEffect.ShowSnackbar(error.message ?: "Error"))
                }
        }
    }

    private fun sendMessage() {
        val text = currentState.inputText.trim()
        if (text.isBlank() || currentState.isSending || currentState.isStreaming) return

        // Set immediately BEFORE launching coroutine (prevents race condition)
        updateState { copy(isSending = true) }

        viewModelScope.launch {
            try {
                updateState { copy(inputText = "") }
                sendMessageUseCase(text)
                    .onSuccess {
                        updateState { copy(isSending = false) }
                        sendEffect(ChatEffect.ScrollToBottom)
                    }
                    .onFailure { error ->
                        updateState { copy(isSending = false, error = error.message) }
                    }
            } catch (e: Exception) {
                updateState { copy(isSending = false, error = e.message) }
            }
        }
    }
}
```

## Screen Composable

```kotlin
@Composable
fun ChatScreen(
    viewModel: ChatViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    // Handle effects
    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is ChatEffect.ShowSnackbar -> {
                    snackbarHostState.showSnackbar(effect.message)
                }
                is ChatEffect.NavigateTo -> {
                    // Handle navigation
                }
                is ChatEffect.ScrollToBottom -> {
                    // Scroll to bottom
                }
                is ChatEffect.CopyToClipboard -> {
                    // Copy to clipboard
                }
                is ChatEffect.HideKeyboard -> {
                    // Hide keyboard
                }
            }
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        ChatContent(
            state = state,
            onSendMessage = { viewModel.sendIntent(ChatIntent.SendMessage) },
            onInputChange = { viewModel.sendIntent(ChatIntent.UpdateInput(it)) },
            onRefresh = { viewModel.sendIntent(ChatIntent.Refresh) },
            modifier = Modifier.padding(padding)
        )
    }
}
```

## Content Composable (Stateless)

```kotlin
@Composable
fun ChatContent(
    state: ChatState,
    onSendMessage: () -> Unit,
    onInputChange: (String) -> Unit,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier.fillMaxSize()) {
        when {
            state.isLoading && state.messages.isEmpty() -> {
                LoadingIndicator()
            }
            state.messages.isEmpty() -> {
                EmptyState(onRefresh = onRefresh)
            }
            else -> {
                MessageList(
                    messages = state.messages,
                    modifier = Modifier.weight(1f)
                )
            }
        }
        
        ChatInputBar(
            text = state.inputText,
            onTextChange = onInputChange,
            onSend = onSendMessage,
            isSending = state.isSending,
            enabled = !state.isSending && !state.isStreaming
        )
    }
}
```

## Testing

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class ChatViewModelTest {
    
    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()
    
    private lateinit var viewModel: ChatViewModel
    private lateinit var mockRepository: MockChatRepository
    
    @Before
    fun setup() {
        mockRepository = MockChatRepository()
        viewModel = ChatViewModel(mockRepository)
    }
    
    @Test
    fun `sendMessage updates state correctly`() = runTest {
        // Arrange
        viewModel.sendIntent(ChatIntent.UpdateInput("Hello"))
        
        // Act
        viewModel.sendIntent(ChatIntent.SendMessage)
        
        // Assert
        assertTrue(viewModel.state.value.isSending)
        advanceUntilIdle()
        assertFalse(viewModel.state.value.isSending)
        assertEquals("", viewModel.state.value.inputText)
    }
    
    @Test
    fun `sendMessage prevents double send`() = runTest {
        // Arrange
        viewModel.sendIntent(ChatIntent.UpdateInput("Hello"))
        
        // Act - send twice rapidly
        viewModel.sendIntent(ChatIntent.SendMessage)
        viewModel.sendIntent(ChatIntent.SendMessage)
        
        // Assert - only one message sent
        advanceUntilIdle()
        assertEquals(1, mockRepository.sendCount)
    }
}
```

## Common Patterns

### Debounced Input
```kotlin
private var searchJob: Job? = null

private fun search(query: String) {
    searchJob?.cancel()
    searchJob = viewModelScope.launch {
        delay(300) // Debounce
        // Perform search
    }
}
```

### Pagination
```kotlin
data class PaginatedState(
    val items: List<Item> = emptyList(),
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = true,
    val page: Int = 0
) : UiState

sealed interface PaginatedIntent : UiIntent {
    data object LoadMore : PaginatedIntent
}
```
