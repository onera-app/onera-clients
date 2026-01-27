package chat.onera.mobile

import android.app.Application
import android.util.Log
import com.clerk.api.Clerk
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class OneraApplication : Application() {
    
    companion object {
        private const val TAG = "OneraApplication"
    }
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize Clerk SDK
        Log.d(TAG, "Initializing Clerk with key: ${BuildConfig.CLERK_PUBLISHABLE_KEY.take(20)}...")
        Clerk.initialize(this, BuildConfig.CLERK_PUBLISHABLE_KEY)
    }
}
