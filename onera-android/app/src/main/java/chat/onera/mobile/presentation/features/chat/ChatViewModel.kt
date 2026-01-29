package chat.onera.mobile.presentation.features.chat

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import chat.onera.mobile.domain.model.Message
import chat.onera.mobile.domain.model.MessageRole
import chat.onera.mobile.domain.usecase.chat.CreateChatUseCase
import chat.onera.mobile.domain.usecase.chat.GetMessagesUseCase
import chat.onera.mobile.domain.usecase.chat.SendMessageUseCase
import chat.onera.mobile.presentation.base.BaseViewModel
import chat.onera.mobile.presentation.navigation.NavArgs
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

@HiltViewModel
class ChatViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val getMessagesUseCase: GetMessagesUseCase,
    private val sendMessageUseCase: SendMessageUseCase,
    private val createChatUseCase: CreateChatUseCase
) : BaseViewModel<ChatState, ChatIntent, ChatEffect>(ChatState()) {

    private var streamingJob: Job? = null
    
    private val initialChatId: String? = savedStateHandle[NavArgs.CHAT_ID]

    init {
        sendIntent(ChatIntent.LoadChat(initialChatId))
    }

    override fun handleIntent(intent: ChatIntent) {
        when (intent) {
            is ChatIntent.LoadChat -> loadChat(intent.chatId)
            is ChatIntent.UpdateInput -> updateState { copy(inputText = intent.text) }
            is ChatIntent.SendMessage -> sendMessage()
            is ChatIntent.StopStreaming -> stopStreaming()
            is ChatIntent.RegenerateResponse -> regenerateResponse(intent.messageId)
            is ChatIntent.DeleteMessage -> deleteMessage(intent.messageId)
            is ChatIntent.EditMessage -> editMessage(intent.messageId, intent.newContent, intent.regenerate)
            is ChatIntent.ClearError -> updateState { copy(error = null) }
        }
    }

    private fun loadChat(chatId: String?) {
        if (chatId == null) {
            updateState { copy(isLoading = false, chatId = null) }
            return
        }
        
        viewModelScope.launch {
            updateState { copy(isLoading = true, chatId = chatId) }
            getMessagesUseCase(chatId)
                .catch { e ->
                    updateState { copy(isLoading = false, error = e.message) }
                }
                .collect { messages ->
                    updateState { copy(isLoading = false, messages = messages) }
                }
        }
    }

    private fun sendMessage() {
        val text = currentState.inputText.trim()
        if (text.isBlank() || currentState.isStreaming || currentState.isSending) return

        // Set isSending synchronously BEFORE launching coroutine to prevent race condition
        updateState { copy(isSending = true) }

        viewModelScope.launch {
            // Create new chat if needed
            val chatId = currentState.chatId ?: run {
                try {
                    val newChatId = createChatUseCase(text.take(50))
                    updateState { copy(chatId = newChatId) }
                    sendEffect(ChatEffect.ChatCreated(newChatId))
                    newChatId
                } catch (e: Exception) {
                    updateState { copy(isSending = false, error = "Failed to create chat: ${e.message}") }
                    return@launch
                }
            }

            // Add user message to UI immediately
            val userMessage = Message(
                id = UUID.randomUUID().toString(),
                chatId = chatId,
                role = MessageRole.USER,
                content = text,
                createdAt = System.currentTimeMillis()
            )
            
            updateState { 
                copy(
                    inputText = "",
                    messages = messages + userMessage,
                    isSending = false,
                    isStreaming = true,
                    streamingMessage = ""
                ) 
            }
            sendEffect(ChatEffect.ScrollToBottom)

            // Send message and stream response
            streamingJob = viewModelScope.launch {
                try {
                    sendMessageUseCase(chatId, text)
                        .catch { e ->
                            updateState { 
                                copy(
                                    isStreaming = false, 
                                    error = e.message ?: "Failed to send message"
                                ) 
                            }
                        }
                        .collect { chunk ->
                            updateState { 
                                copy(streamingMessage = streamingMessage + chunk) 
                            }
                        }
                    
                    // Streaming complete - add assistant message
                    val assistantMessage = Message(
                        id = UUID.randomUUID().toString(),
                        chatId = chatId,
                        role = MessageRole.ASSISTANT,
                        content = currentState.streamingMessage,
                        createdAt = System.currentTimeMillis()
                    )
                    
                    updateState { 
                        copy(
                            messages = messages + assistantMessage,
                            isStreaming = false,
                            streamingMessage = ""
                        ) 
                    }
                    sendEffect(ChatEffect.ScrollToBottom)
                } catch (e: Exception) {
                    updateState { 
                        copy(
                            isStreaming = false, 
                            error = e.message ?: "Failed to get response"
                        ) 
                    }
                }
            }
        }
    }

    private fun stopStreaming() {
        streamingJob?.cancel()
        streamingJob = null
        
        // Save partial response if any
        if (currentState.streamingMessage.isNotBlank()) {
            val assistantMessage = Message(
                id = UUID.randomUUID().toString(),
                chatId = currentState.chatId ?: return,
                role = MessageRole.ASSISTANT,
                content = currentState.streamingMessage + " [stopped]",
                createdAt = System.currentTimeMillis()
            )
            updateState { 
                copy(
                    messages = messages + assistantMessage,
                    isStreaming = false,
                    streamingMessage = ""
                ) 
            }
        } else {
            updateState { copy(isStreaming = false) }
        }
    }

    private fun regenerateResponse(messageId: String) {
        // Find the user message before this assistant message
        val messageIndex = currentState.messages.indexOfFirst { it.id == messageId }
        if (messageIndex <= 0) return
        
        val userMessage = currentState.messages.getOrNull(messageIndex - 1) ?: return
        if (userMessage.role != MessageRole.USER) return
        
        // Remove the assistant message and resend
        updateState { 
            copy(
                messages = messages.filterIndexed { index, _ -> index < messageIndex },
                inputText = userMessage.content
            ) 
        }
        sendMessage()
    }

    private fun deleteMessage(messageId: String) {
        updateState { 
            copy(messages = messages.filter { it.id != messageId }) 
        }
    }

    private fun editMessage(messageId: String, newContent: String, regenerate: Boolean) {
        val trimmedContent = newContent.trim()
        if (trimmedContent.isBlank()) return
        
        val messageIndex = currentState.messages.indexOfFirst { it.id == messageId }
        if (messageIndex < 0) return
        
        val message = currentState.messages[messageIndex]
        if (message.role != MessageRole.USER) return
        
        // Update the message with edited content
        val editedMessage = message.copy(
            content = trimmedContent,
            edited = true,
            editedAt = System.currentTimeMillis()
        )
        
        if (regenerate) {
            // Remove all messages after the edited one and regenerate
            val messagesUpToEdited = currentState.messages
                .take(messageIndex)
                .plus(editedMessage)
            
            updateState { 
                copy(
                    messages = messagesUpToEdited,
                    inputText = trimmedContent,
                    editingMessageId = null
                ) 
            }
            
            // Trigger new response by sending the edited message
            sendMessageAfterEdit()
        } else {
            // Just update the message in place without regenerating
            val updatedMessages = currentState.messages.toMutableList()
            updatedMessages[messageIndex] = editedMessage
            
            updateState { 
                copy(
                    messages = updatedMessages,
                    editingMessageId = null
                ) 
            }
        }
    }

    private fun sendMessageAfterEdit() {
        val text = currentState.inputText.trim()
        if (text.isBlank() || currentState.isStreaming) return

        viewModelScope.launch {
            val chatId = currentState.chatId ?: return@launch
            
            // Clear input and start streaming
            updateState { 
                copy(
                    inputText = "",
                    isStreaming = true,
                    streamingMessage = ""
                ) 
            }
            sendEffect(ChatEffect.ScrollToBottom)

            // Send message and stream response
            streamingJob = viewModelScope.launch {
                try {
                    sendMessageUseCase(chatId, text)
                        .catch { e ->
                            updateState { 
                                copy(
                                    isStreaming = false, 
                                    error = e.message ?: "Failed to send message"
                                ) 
                            }
                        }
                        .collect { chunk ->
                            updateState { 
                                copy(streamingMessage = streamingMessage + chunk) 
                            }
                        }
                    
                    // Streaming complete - add assistant message
                    val assistantMessage = Message(
                        id = UUID.randomUUID().toString(),
                        chatId = chatId,
                        role = MessageRole.ASSISTANT,
                        content = currentState.streamingMessage,
                        createdAt = System.currentTimeMillis()
                    )
                    
                    updateState { 
                        copy(
                            messages = messages + assistantMessage,
                            isStreaming = false,
                            streamingMessage = ""
                        ) 
                    }
                    sendEffect(ChatEffect.ScrollToBottom)
                } catch (e: Exception) {
                    updateState { 
                        copy(
                            isStreaming = false, 
                            error = e.message ?: "Failed to get response"
                        ) 
                    }
                }
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        streamingJob?.cancel()
    }
}
