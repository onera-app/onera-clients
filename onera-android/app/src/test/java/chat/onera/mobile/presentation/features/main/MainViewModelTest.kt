package chat.onera.mobile.presentation.features.main

import chat.onera.mobile.data.remote.ChatTasksService
import chat.onera.mobile.data.remote.trpc.AuthTokenProvider
import chat.onera.mobile.data.remote.websocket.WebSocketService
import chat.onera.mobile.data.speech.SpeechRecognitionManager
import chat.onera.mobile.data.speech.TextToSpeechManager
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.domain.model.MessageRole
import chat.onera.mobile.domain.model.User
import chat.onera.mobile.domain.repository.AuthRepository
import chat.onera.mobile.domain.repository.ChatRepository
import chat.onera.mobile.domain.repository.CredentialRepository
import chat.onera.mobile.domain.repository.FoldersRepository
import chat.onera.mobile.domain.repository.LLMRepository
import chat.onera.mobile.domain.repository.PromptRepository
import chat.onera.mobile.data.remote.private_inference.EnclaveService
import chat.onera.mobile.presentation.features.main.handlers.AttachmentProcessor
import chat.onera.mobile.presentation.features.main.handlers.TTSHandler
import chat.onera.mobile.presentation.features.main.handlers.VoiceInputHandler
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class MainViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    
    private lateinit var authRepository: AuthRepository
    private lateinit var chatRepository: ChatRepository
    private lateinit var credentialRepository: CredentialRepository
    private lateinit var foldersRepository: FoldersRepository
    private lateinit var llmRepository: LLMRepository
    private lateinit var enclaveService: EnclaveService
    private lateinit var voiceInputHandler: VoiceInputHandler
    private lateinit var ttsHandler: TTSHandler
    private lateinit var attachmentProcessor: AttachmentProcessor
    private lateinit var chatTasksService: ChatTasksService
    private lateinit var promptRepository: PromptRepository
    private lateinit var webSocketService: WebSocketService
    private lateinit var authTokenProvider: AuthTokenProvider
    private lateinit var speechRecognitionManager: SpeechRecognitionManager
    private lateinit var textToSpeechManager: TextToSpeechManager
    private lateinit var viewModel: MainViewModel

    // StateFlows for mocking
    private val isListeningFlow = MutableStateFlow(false)
    private val transcribedTextFlow = MutableStateFlow("")
    private val isSpeakingFlow = MutableStateFlow(false)
    private val speakingMessageIdFlow = MutableStateFlow<String?>(null)
    private val speakingStartTimeFlow = MutableStateFlow<Long?>(null)

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        
        authRepository = mockk(relaxed = true)
        chatRepository = mockk(relaxed = true)
        credentialRepository = mockk(relaxed = true)
        foldersRepository = mockk(relaxed = true)
        llmRepository = mockk(relaxed = true)
        enclaveService = mockk(relaxed = true)
        voiceInputHandler = mockk(relaxed = true)
        ttsHandler = mockk(relaxed = true)
        attachmentProcessor = mockk(relaxed = true)
        chatTasksService = mockk(relaxed = true)
        promptRepository = mockk(relaxed = true)
        webSocketService = mockk(relaxed = true)
        authTokenProvider = mockk(relaxed = true)
        speechRecognitionManager = mockk(relaxed = true)
        textToSpeechManager = mockk(relaxed = true)
        
        // Setup LLM repository
        coEvery { llmRepository.getCredentials() } returns emptyList()
        
        // Setup mock user
        coEvery { authRepository.getCurrentUser() } returns User(
            id = "user-1",
            email = "test@example.com",
            displayName = "Test User",
            avatarUrl = null
        )
        
        // Setup chat repository
        coEvery { chatRepository.observeChats() } returns flowOf(emptyList())
        
        // Setup folders repository
        coEvery { foldersRepository.observeFolders() } returns flowOf(emptyList())
        
        // Setup prompt repository
        coEvery { promptRepository.observePrompts() } returns flowOf(emptyList())
        
        // Setup WebSocket service
        every { webSocketService.messages } returns MutableStateFlow(
            chat.onera.mobile.data.remote.websocket.WebSocketMessage(type = "init")
        )
        every { webSocketService.connectionState } returns MutableStateFlow(
            chat.onera.mobile.data.remote.websocket.ConnectionState.Disconnected
        )
        
        // Setup auth token provider
        coEvery { authTokenProvider.getToken() } returns "mock-token"
        
        // Setup voice input handler events
        every { voiceInputHandler.events } returns flowOf()
        
        // Setup credential repository
        coEvery { credentialRepository.getCredentials() } returns emptyList()
        coEvery { credentialRepository.observeCredentials() } returns flowOf(emptyList())
        
        // Setup enclave service
        coEvery { enclaveService.listModels() } returns emptyList()
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun createViewModel(): MainViewModel {
        return MainViewModel(
            authRepository = authRepository,
            chatRepository = chatRepository,
            credentialRepository = credentialRepository,
            foldersRepository = foldersRepository,
            llmRepository = llmRepository,
            enclaveService = enclaveService,
            voiceInputHandler = voiceInputHandler,
            ttsHandler = ttsHandler,
            attachmentProcessor = attachmentProcessor,
            chatTasksService = chatTasksService,
            promptRepository = promptRepository,
            webSocketService = webSocketService,
            authTokenProvider = authTokenProvider
        )
    }

    // ========== Voice Input Tests ==========

    @Test
    fun `start recording should call voiceInputHandler`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(MainIntent.StartRecording)
        testDispatcher.scheduler.advanceUntilIdle()
        
        verify { voiceInputHandler.startRecording(any()) }
    }

    @Test
    fun `stop recording should call voiceInputHandler`() = runTest {
        every { voiceInputHandler.stopRecording() } returns ""
        
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(MainIntent.StopRecording)
        testDispatcher.scheduler.advanceUntilIdle()
        
        verify { voiceInputHandler.stopRecording() }
    }

    @Test
    fun `transcribed text should update input text`() = runTest {
        every { voiceInputHandler.stopRecording() } returns "Hello world"
        
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(MainIntent.StopRecording)
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertTrue(viewModel.state.value.chatState.inputText.contains("Hello world"))
    }

    // ========== Text-to-Speech Tests ==========

    @Test
    fun `speak message should call ttsHandler`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(MainIntent.SpeakMessage("Hello", "message-1"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        verify { ttsHandler.speak("Hello", "message-1") }
    }

    @Test
    fun `stop speaking should call ttsHandler stop`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(MainIntent.StopSpeaking)
        testDispatcher.scheduler.advanceUntilIdle()
        
        verify { ttsHandler.stop() }
    }

    // ========== Message Editing Tests ==========

    @Test
    fun `edit message should update message content`() = runTest {
        // Setup initial messages
        val userMessage = Message(
            id = "user-1",
            chatId = "chat-1",
            role = MessageRole.USER,
            content = "Original",
            createdAt = System.currentTimeMillis()
        )
        
        coEvery { chatRepository.observeChats() } returns flowOf(emptyList())
        coEvery { chatRepository.getChatMessages(any()) } returns listOf(userMessage)
        coEvery { chatRepository.getChat(any()) } returns mockk {
            every { id } returns "chat-1"
            every { title } returns "Test Chat"
        }
        
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        // Select chat to load messages
        viewModel.sendIntent(MainIntent.SelectChat("chat-1"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        // Edit the message
        viewModel.sendIntent(MainIntent.EditMessage("user-1", "Edited", false))
        testDispatcher.scheduler.advanceUntilIdle()
        
        val editedMessage = viewModel.state.value.chatState.messages.find { it.id == "user-1" }
        assertEquals("Edited", editedMessage?.content)
        assertTrue(editedMessage?.edited ?: false)
    }

    // ========== Chat Input Tests ==========

    @Test
    fun `update chat input should change input text`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(MainIntent.UpdateChatInput("Test input"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals("Test input", viewModel.state.value.chatState.inputText)
    }

    @Test
    fun `create new chat should reset chat state`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        // Add some input
        viewModel.sendIntent(MainIntent.UpdateChatInput("Some text"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        // Create new chat
        viewModel.sendIntent(MainIntent.CreateNewChat)
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertNull(viewModel.state.value.selectedChatId)
        assertEquals("New chat", viewModel.state.value.chatState.chatTitle)
        assertTrue(viewModel.state.value.chatState.messages.isEmpty())
    }

    // ========== Search Tests ==========

    @Test
    fun `update search query should change search state`() = runTest {
        viewModel = createViewModel()
        testDispatcher.scheduler.advanceUntilIdle()
        
        viewModel.sendIntent(MainIntent.UpdateSearchQuery("test"))
        testDispatcher.scheduler.advanceUntilIdle()
        
        assertEquals("test", viewModel.state.value.searchQuery)
    }
}
