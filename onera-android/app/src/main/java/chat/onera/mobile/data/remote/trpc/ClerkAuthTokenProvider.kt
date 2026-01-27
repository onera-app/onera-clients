package chat.onera.mobile.data.remote.trpc

import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ClerkAuthTokenProvider @Inject constructor() : AuthTokenProvider {
    
    private var cachedToken: String? = null
    
    fun setToken(token: String?) {
        cachedToken = token
    }
    
    override suspend fun getToken(): String? {
        // In a real implementation, this would get the token from Clerk SDK
        return cachedToken
    }
}
