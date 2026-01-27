package chat.onera.mobile.data.repository

import android.app.Activity
import android.content.Context
import android.util.Log
import chat.onera.mobile.BuildConfig
import chat.onera.mobile.data.remote.trpc.ClerkAuthTokenProvider
import chat.onera.mobile.domain.model.User
import chat.onera.mobile.domain.repository.AuthRepository
import com.clerk.api.Clerk
import com.clerk.api.network.model.token.TokenResource
import com.clerk.api.network.serialization.ClerkResult
import com.clerk.api.session.GetTokenOptions
import com.clerk.api.session.fetchToken
import com.clerk.api.signin.*
import com.clerk.api.sso.OAuthProvider
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Auth Repository implementation using Clerk Android SDK (v0.1.20).
 * 
 * All authentication is handled through the Clerk SDK:
 * - OAuth flows via SignIn.authenticateWithRedirect()
 * - Session management via Clerk.session
 * - Token retrieval via Session.fetchToken()
 * - User data via Clerk.user
 * 
 * Prerequisites:
 * 1. Enable Native API in Clerk Dashboard
 * 2. Configure Google/Apple OAuth in Clerk Dashboard  
 * 3. Set up Google Developer credentials (Android + Web clients)
 */
@Singleton
class AuthRepositoryImpl @Inject constructor(
    @param:ApplicationContext private val context: Context,
    private val clerkAuthTokenProvider: ClerkAuthTokenProvider
) : AuthRepository {

    companion object {
        private const val TAG = "AuthRepository"
    }

    private val _authState = MutableStateFlow(false)
    private var _currentUser: User? = null
    
    // Tracks if user has completed E2EE setup
    private var _hasCompletedE2EESetup = false
    
    // Tracks if user has explicitly signed out (prevents auto re-login from stale Clerk cache)
    private var _hasExplicitlySignedOut = false
    
    // Activity reference for OAuth flows
    private var currentActivity: Activity? = null
    
    private val scope = CoroutineScope(Dispatchers.Main)
    
    fun setActivity(activity: Activity?) {
        currentActivity = activity
    }

    override suspend fun isAuthenticated(): Boolean {
        // If user explicitly signed out, don't check Clerk cache - they're logged out
        if (_hasExplicitlySignedOut) {
            Log.d(TAG, "User has explicitly signed out, returning false")
            return false
        }
        
        // Check if Clerk has an active session
        // Retry a few times since SDK might not be fully synced yet
        for (attempt in 0..4) {
            try {
                val session = Clerk.session
                if (session != null) {
                    Log.d(TAG, "Clerk session found: ${session.id}")
                    _authState.value = true
                    updateCurrentUserFromClerk()
                    fetchAndCacheToken()
                    return true
                }
                
                // Also check if client has sessions (SDK might not have synced session property yet)
                try {
                    val clientSessions = Clerk.client?.sessions
                    if (!clientSessions.isNullOrEmpty()) {
                        val activeSession = clientSessions.find { it.status.name == "ACTIVE" }
                        if (activeSession != null) {
                            Log.d(TAG, "Found active session in client: ${activeSession.id}")
                            _authState.value = true
                            updateCurrentUserFromClerk()
                            // Try to fetch token using this session
                            try {
                                fetchAndCacheToken()
                            } catch (e: Exception) {
                                Log.w(TAG, "Could not fetch token: ${e.message}")
                            }
                            return true
                        }
                    }
                } catch (e: UninitializedPropertyAccessException) {
                    Log.d(TAG, "Clerk client not initialized yet")
                }
            } catch (e: Exception) {
                Log.d(TAG, "Error checking session: ${e.message}")
            }
            
            if (attempt < 4) {
                Log.d(TAG, "No Clerk session found (attempt ${attempt + 1}), waiting 500ms...")
                kotlinx.coroutines.delay(500)
            }
        }
        Log.d(TAG, "No Clerk session found after retries")
        return _authState.value
    }

    override suspend fun getCurrentUser(): User? {
        if (_currentUser == null) {
            updateCurrentUserFromClerk()
        }
        return _currentUser
    }

    override fun observeAuthState(): Flow<Boolean> {
        return _authState.asStateFlow()
    }

    override suspend fun signInWithGoogle() {
        Log.d(TAG, "Starting Google Sign-In via Clerk SDK...")
        
        // Clear the explicit sign-out flag since user is trying to sign in
        _hasExplicitlySignedOut = false
        
        // Check if already authenticated
        val existingSession = Clerk.session
        if (existingSession != null) {
            Log.d(TAG, "Session already exists: ${existingSession.id}, using existing session")
            _authState.value = true
            updateCurrentUserFromClerk()
            fetchAndCacheToken()
            return
        }
        
        // Create OAuth params for Google
        val oauthParams = SignIn.AuthenticateWithRedirectParams.OAuth(
            provider = OAuthProvider.GOOGLE
        )
        
        // Start OAuth flow - opens browser for authentication
        when (val result = SignIn.authenticateWithRedirect(oauthParams)) {
            is ClerkResult.Success<*> -> {
                Log.d(TAG, "Google OAuth successful")
                _authState.value = true
                updateCurrentUserFromClerk()
                fetchAndCacheToken()
            }
            is ClerkResult.Failure<*> -> {
                val errorMsg = result.error.toString()
                // Handle "session already exists" as a success - SDK state wasn't synced yet
                if (errorMsg.contains("session_exists", ignoreCase = true) || 
                    errorMsg.contains("already signed in", ignoreCase = true)) {
                    Log.d(TAG, "Session already exists on server, treating as success")
                    // Force sync state from server
                    kotlinx.coroutines.delay(500) // Give SDK time to sync
                    _authState.value = true
                    updateCurrentUserFromClerk()
                    fetchAndCacheToken()
                    return
                }
                Log.e(TAG, "Google OAuth failed: ${result.error}")
                throw Exception("Google sign in failed: ${result.error}")
            }
        }
    }

    override suspend fun signInWithApple() {
        Log.d(TAG, "Starting Apple Sign-In via Clerk SDK...")
        
        // Clear the explicit sign-out flag since user is trying to sign in
        _hasExplicitlySignedOut = false
        
        // Check if already authenticated
        val existingSession = Clerk.session
        if (existingSession != null) {
            Log.d(TAG, "Session already exists: ${existingSession.id}, using existing session")
            _authState.value = true
            updateCurrentUserFromClerk()
            fetchAndCacheToken()
            return
        }
        
        // Create OAuth params for Apple
        val oauthParams = SignIn.AuthenticateWithRedirectParams.OAuth(
            provider = OAuthProvider.APPLE
        )
        
        // Start OAuth flow
        when (val result = SignIn.authenticateWithRedirect(oauthParams)) {
            is ClerkResult.Success<*> -> {
                Log.d(TAG, "Apple OAuth successful")
                _authState.value = true
                updateCurrentUserFromClerk()
                fetchAndCacheToken()
            }
            is ClerkResult.Failure<*> -> {
                val errorMsg = result.error.toString()
                // Handle "session already exists" as a success - SDK state wasn't synced yet
                if (errorMsg.contains("session_exists", ignoreCase = true) || 
                    errorMsg.contains("already signed in", ignoreCase = true)) {
                    Log.d(TAG, "Session already exists on server, treating as success")
                    // Force sync state from server
                    kotlinx.coroutines.delay(500) // Give SDK time to sync
                    _authState.value = true
                    updateCurrentUserFromClerk()
                    fetchAndCacheToken()
                    return
                }
                Log.e(TAG, "Apple OAuth failed: ${result.error}")
                throw Exception("Apple sign in failed: ${result.error}")
            }
        }
    }

    override suspend fun signInWithEmail(email: String) {
        Log.d(TAG, "Email sign-in not yet implemented in Clerk SDK")
        throw UnsupportedOperationException("Email sign in not yet implemented")
    }

    override suspend fun signOut() {
        Log.d(TAG, "Signing out via Clerk SDK...")
        // Mark as explicitly signed out BEFORE calling Clerk.signOut()
        // This prevents isAuthenticated() from returning true due to stale cache
        _hasExplicitlySignedOut = true
        _authState.value = false
        _currentUser = null
        clerkAuthTokenProvider.setToken(null)
        
        try {
            Clerk.signOut()
            Log.d(TAG, "Sign out successful")
        } catch (e: Exception) {
            Log.e(TAG, "Error signing out: ${e.message}")
        }
    }

    override suspend fun deleteAccount() {
        // Note: Full account deletion requires Clerk SDK support.
        // Currently, we sign out the user. The account can be deleted 
        // via the web dashboard or when Clerk SDK adds deletion support.
        // See: https://clerk.com/docs for latest SDK capabilities
        signOut()
    }
    
    /**
     * Call this after OAuth completes to sync state
     */
    suspend fun syncAuthState(): Boolean {
        return isAuthenticated()
    }
    
    /**
     * Called when E2EE setup is complete
     */
    fun markE2EESetupComplete() {
        _hasCompletedE2EESetup = true
        _currentUser = _currentUser?.copy(hasE2EEKeys = true)
    }
    
    /**
     * Update current user from Clerk SDK
     */
    private fun updateCurrentUserFromClerk() {
        val user = Clerk.user
        if (user != null) {
            val primaryEmail = user.emailAddresses.firstOrNull()?.emailAddress ?: ""
            
            _currentUser = User(
                id = user.id,
                email = primaryEmail,
                displayName = "${user.firstName ?: ""} ${user.lastName ?: ""}".trim().ifEmpty { "User" },
                avatarUrl = user.imageUrl,
                hasE2EEKeys = _hasCompletedE2EESetup
            )
            Log.d(TAG, "Updated current user from Clerk: ${_currentUser?.email}")
        } else {
            Log.d(TAG, "No Clerk user found")
        }
    }
    
    /**
     * Fetch token from Clerk session and cache it
     */
    private suspend fun fetchAndCacheToken() {
        try {
            val session = Clerk.session
            if (session == null) {
                Log.d(TAG, "No session available for token fetch")
                return
            }
            
            Log.d(TAG, "Fetching token from Clerk session: ${session.id}")
            val options = GetTokenOptions()
            
            when (val result = session.fetchToken(options)) {
                is ClerkResult.Success<*> -> {
                    val tokenResource = result.value as? TokenResource
                    val jwt = tokenResource?.jwt
                    if (jwt != null) {
                        clerkAuthTokenProvider.setToken(jwt)
                        Log.d(TAG, "Token cached successfully (${jwt.length} chars)")
                    } else {
                        Log.w(TAG, "Token resource returned null JWT")
                    }
                }
                is ClerkResult.Failure<*> -> {
                    Log.e(TAG, "Failed to fetch token: ${result.error}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching token: ${e.message}")
        }
    }
    
    /**
     * Get a fresh session token for API calls
     */
    suspend fun getSessionToken(): String? {
        return try {
            val session = Clerk.session
            if (session == null) {
                Log.d(TAG, "No session available")
                return null
            }
            
            Log.d(TAG, "Getting fresh token for session: ${session.id}")
            val options = GetTokenOptions()
            
            when (val result = session.fetchToken(options)) {
                is ClerkResult.Success<*> -> {
                    val tokenResource = result.value as? TokenResource
                    val jwt = tokenResource?.jwt
                    if (jwt != null) {
                        clerkAuthTokenProvider.setToken(jwt)
                        Log.d(TAG, "Fresh token retrieved (${jwt.length} chars)")
                    }
                    jwt
                }
                is ClerkResult.Failure<*> -> {
                    Log.e(TAG, "Failed to get token: ${result.error}")
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting session token: ${e.message}")
            null
        }
    }
}
