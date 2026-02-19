package chat.onera.mobile.data.repository

import android.content.Context
import chat.onera.mobile.domain.model.User
import chat.onera.mobile.domain.repository.AuthRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Apple
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.status.SessionStatus
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Auth Repository implementation using Supabase Auth (Kotlin SDK).
 *
 * Replaces the previous Clerk-based implementation. Key differences:
 * - Supabase SDK handles session persistence and token refresh automatically
 * - OAuth uses PKCE flow with deep link callback (onera://auth/callback)
 * - No manual token caching needed — the SDK manages the session lifecycle
 * - Session status is observable via [SessionStatus] flow
 *
 * Prerequisites:
 * 1. Configure Google/Apple OAuth in Supabase Dashboard (Authentication > Providers)
 * 2. Add "onera://auth/callback" to Supabase Redirect URLs
 * 3. Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in local.properties
 */
@Singleton
class AuthRepositoryImpl @Inject constructor(
    @param:ApplicationContext private val context: Context,
    private val supabaseClient: SupabaseClient
) : AuthRepository {

    companion object {
        private const val TAG = "AuthRepository"
    }

    private val _authState = MutableStateFlow(false)
    private var _currentUser: User? = null

    // Tracks if user has completed E2EE setup
    private var _hasCompletedE2EESetup = false

    override suspend fun isAuthenticated(): Boolean {
        return try {
            val session = supabaseClient.auth.currentSessionOrNull()
            val isAuth = session != null
            _authState.value = isAuth
            if (isAuth) {
                updateCurrentUserFromSupabase()
            }
            Timber.d("isAuthenticated: $isAuth")
            isAuth
        } catch (e: Exception) {
            Timber.e(e, "Error checking auth status")
            _authState.value = false
            false
        }
    }

    override suspend fun getCurrentUser(): User? {
        if (_currentUser == null) {
            updateCurrentUserFromSupabase()
        }
        return _currentUser
    }

    override fun observeAuthState(): Flow<Boolean> {
        return _authState.asStateFlow()
    }

    /**
     * Observe the Supabase session status as a typed flow.
     * Consumers can use this for more granular session events
     * (e.g., distinguishing LoadingFromStorage vs NotAuthenticated).
     */
    fun observeSessionStatus(): Flow<SessionStatus> {
        return supabaseClient.auth.sessionStatus
    }

    override suspend fun signInWithGoogle() {
        Timber.d("Starting Google Sign-In via Supabase...")
        try {
            supabaseClient.auth.signInWith(Google)
            // After OAuth redirect + callback, the session is established automatically.
            // The session status flow will emit Authenticated, which we handle in the ViewModel.
            _authState.value = true
            updateCurrentUserFromSupabase()
            Timber.d("Google sign-in initiated (awaiting OAuth callback)")
        } catch (e: Exception) {
            Timber.e(e, "Google sign-in failed")
            throw Exception("Google sign in failed: ${e.message}", e)
        }
    }

    override suspend fun signInWithApple() {
        Timber.d("Starting Apple Sign-In via Supabase...")
        try {
            supabaseClient.auth.signInWith(Apple)
            _authState.value = true
            updateCurrentUserFromSupabase()
            Timber.d("Apple sign-in initiated (awaiting OAuth callback)")
        } catch (e: Exception) {
            Timber.e(e, "Apple sign-in failed")
            throw Exception("Apple sign in failed: ${e.message}", e)
        }
    }

    override suspend fun signInWithEmail(email: String) {
        Timber.d("Email sign-in not yet implemented")
        throw UnsupportedOperationException("Email sign in not yet implemented")
    }

    override suspend fun signOut() {
        Timber.d("Signing out via Supabase...")
        _authState.value = false
        _currentUser = null

        try {
            supabaseClient.auth.signOut()
            Timber.d("Sign out successful")
        } catch (e: Exception) {
            Timber.e(e, "Error signing out")
        }
    }

    override suspend fun deleteAccount() {
        // Account deletion requires the server-side admin API.
        // Sign out locally; the account can be deleted via web dashboard
        // or a dedicated server endpoint.
        signOut()
    }

    /**
     * Call this after OAuth callback completes to sync state.
     */
    suspend fun syncAuthState(): Boolean {
        return isAuthenticated()
    }

    /**
     * Called when E2EE setup is complete.
     */
    fun markE2EESetupComplete() {
        _hasCompletedE2EESetup = true
        _currentUser = _currentUser?.copy(hasE2EEKeys = true)
    }

    /**
     * Get a fresh session token for API calls.
     * The Supabase SDK handles refresh automatically, so this
     * returns the current access token from the active session.
     */
    suspend fun getSessionToken(): String? {
        return try {
            supabaseClient.auth.currentSessionOrNull()?.accessToken
        } catch (e: Exception) {
            Timber.e(e, "Error getting session token")
            null
        }
    }



    /**
     * Update current user from Supabase Auth session.
     * User metadata follows the web convention:
     * - first_name, last_name, name in user_metadata
     * - avatar_url or picture for profile image
     */
    private fun updateCurrentUserFromSupabase() {
        val user = supabaseClient.auth.currentUserOrNull()
        if (user != null) {
            val metadata = user.userMetadata
            val firstName = metadata?.get("first_name")?.toString()?.trim('"') ?: ""
            val lastName = metadata?.get("last_name")?.toString()?.trim('"') ?: ""
            val name = metadata?.get("name")?.toString()?.trim('"') ?: ""
            val avatarUrl = metadata?.get("avatar_url")?.toString()?.trim('"')
                ?: metadata?.get("picture")?.toString()?.trim('"')

            val displayName = name.ifEmpty {
                "$firstName $lastName".trim().ifEmpty { "User" }
            }

            _currentUser = User(
                id = user.id,
                email = user.email ?: "",
                displayName = displayName,
                avatarUrl = avatarUrl,
                hasE2EEKeys = _hasCompletedE2EESetup
            )
            Timber.d("Updated current user from Supabase: ${_currentUser?.email}")
        } else {
            Timber.d("No Supabase user found")
        }
    }
}
