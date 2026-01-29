package chat.onera.mobile.domain.repository

import chat.onera.mobile.data.remote.llm.ImageData
import chat.onera.mobile.domain.model.Chat
import chat.onera.mobile.domain.model.Message
import kotlinx.coroutines.flow.Flow

interface ChatRepository {
    // Chat methods
    fun observeChats(): Flow<List<Chat>>
    suspend fun getChats(): List<Chat>
    suspend fun getChat(chatId: String): Chat?
    suspend fun createChat(title: String): String
    suspend fun updateChat(chat: Chat)
    suspend fun updateChatFolder(chatId: String, folderId: String?)
    suspend fun deleteChat(chatId: String)
    
    /**
     * Refresh chats from server. Fetches encrypted chat list and decrypts titles.
     */
    suspend fun refreshChats()
    
    /**
     * Fetch a specific chat from server with full content (including messages).
     * Decrypts the chat key, title, and messages client-side.
     * Stores decrypted messages in local database.
     * 
     * @param chatId The ID of the chat to fetch
     * @return The decrypted Chat with messages, or null if not found
     */
    suspend fun fetchChat(chatId: String): Chat?
    
    /**
     * Sync a specific chat to the server.
     * Encrypts the chat content before uploading.
     */
    suspend fun syncChat(chatId: String)
    
    // Message methods
    suspend fun getChatMessages(chatId: String): List<Message>
    fun observeMessages(chatId: String): Flow<List<Message>>
    fun sendMessageStream(chatId: String?, message: String, model: String, images: List<ImageData> = emptyList()): Flow<String>
    suspend fun saveMessage(message: Message)
    suspend fun deleteMessage(messageId: String)
    
    // Cache management
    
    /**
     * Clear the chat key cache.
     * Call this on session lock or sign out.
     */
    fun clearKeyCache()
}
