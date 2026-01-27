package chat.onera.mobile.domain.repository

import chat.onera.mobile.domain.model.User
import kotlinx.coroutines.flow.Flow

interface AuthRepository {
    suspend fun isAuthenticated(): Boolean
    suspend fun getCurrentUser(): User?
    fun observeAuthState(): Flow<Boolean>
    
    suspend fun signInWithGoogle()
    suspend fun signInWithApple()
    suspend fun signInWithEmail(email: String)
    
    suspend fun signOut()
    suspend fun deleteAccount()
}
