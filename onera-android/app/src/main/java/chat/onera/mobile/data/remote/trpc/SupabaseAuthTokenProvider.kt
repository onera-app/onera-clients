package chat.onera.mobile.data.remote.trpc

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Provides auth tokens from the Supabase session.
 *
 * The Supabase SDK manages token refresh automatically, so this
 * reads directly from the current session — no manual caching needed.
 */
@Singleton
class SupabaseAuthTokenProvider @Inject constructor(
    private val supabaseClient: SupabaseClient
) : AuthTokenProvider {

    override suspend fun getToken(): String? {
        val token = supabaseClient.auth.currentSessionOrNull()?.accessToken
        if (token == null) {
            Timber.w("No Supabase session available for token")
        }
        return token
    }
}
