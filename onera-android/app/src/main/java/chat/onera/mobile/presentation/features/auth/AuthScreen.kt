package chat.onera.mobile.presentation.features.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.onera.mobile.R
import chat.onera.mobile.demo.DemoModeActivationWrapper
import kotlinx.coroutines.delay

// Gradient colors matching iOS onboarding style
private val authGradientColors = listOf(
    Color(0xFF8CD9F5),  // Sky blue
    Color(0xFFC2E8F8),  // Pale cyan
    Color(0xFFF2E0D6),  // Blush / peach
)

@Composable
fun AuthScreen(
    viewModel: AuthViewModel = hiltViewModel(),
    onAuthSuccess: () -> Unit,
    onNeedsE2EESetup: () -> Unit,
    onNeedsE2EEUnlock: () -> Unit = {}
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val isDarkTheme = isSystemInDarkTheme()
    
    // Animation states
    var showBranding by remember { mutableStateOf(false) }
    var showCard by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is AuthEffect.NavigateToMain -> onAuthSuccess()
                is AuthEffect.NavigateToE2EESetup -> onNeedsE2EESetup()
                is AuthEffect.NavigateToE2EEUnlock -> onNeedsE2EEUnlock()
                is AuthEffect.ShowError -> {
                    // Error is displayed via state.error and Snackbar below
                }
                is AuthEffect.LaunchGoogleSignIn -> {
                    // Google Sign In is handled by Supabase OAuth flow
                }
            }
        }
    }
    
    // Simple fade-in animation
    LaunchedEffect(Unit) {
        delay(200)
        showBranding = true
        delay(400)
        showCard = true
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(authGradientColors)
            )
    ) {
        // Centered Onera branding
        AnimatedVisibility(
            visible = showBranding,
            enter = fadeIn(),
            modifier = Modifier.align(Alignment.Center)
        ) {
            // Wrapped with DemoModeActivationWrapper for Play Store review
            // Tap 10 times rapidly to activate demo mode
            DemoModeActivationWrapper(
                onDemoModeActivated = {
                    viewModel.sendIntent(AuthIntent.ActivateDemoMode)
                }
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(horizontal = 48.dp)
                ) {
                    Text(
                        text = "onera",
                        fontSize = 52.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF1A1A1A)
                    )
                    
                    Spacer(modifier = Modifier.height(12.dp))
                    
                    Text(
                        text = "Private AI chat, built differently.",
                        fontSize = 18.sp,
                        color = Color(0xFF4A4A4A),
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
        
        // Bottom dark card with sign-in buttons
        AnimatedVisibility(
            visible = showCard,
            enter = slideInVertically(
                initialOffsetY = { it },
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioNoBouncy,
                    stiffness = Spring.StiffnessMediumLow
                )
            ) + fadeIn(),
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            BottomAuthDrawer(
                state = state,
                isDarkTheme = isDarkTheme,
                onGoogleSignIn = { viewModel.sendIntent(AuthIntent.SignInWithGoogle) },
                onAppleSignIn = { viewModel.sendIntent(AuthIntent.SignInWithApple) }
            )
        }
        
        // Error snackbar
        state.error?.let { error ->
            Snackbar(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(16.dp)
                    .padding(bottom = if (showCard) 200.dp else 16.dp),
                action = {
                    TextButton(onClick = { viewModel.sendIntent(AuthIntent.ClearError) }) {
                        Text("Dismiss")
                    }
                }
            ) {
                Text(error)
            }
        }
    }
}

@Composable
private fun BottomAuthDrawer(
    state: AuthState,
    isDarkTheme: Boolean,
    onGoogleSignIn: () -> Unit,
    onAppleSignIn: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp),
        color = Color(0xFF171717) // Dark card matching iOS onboardingSheetBackground
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(top = 32.dp, bottom = 34.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Loading overlay
            Box(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .alpha(if (state.isLoading) 0.5f else 1f),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Apple Sign In Button
                    AppleSignInButton(
                        onClick = onAppleSignIn,
                        enabled = !state.isLoading,
                        isLoading = state.isLoading && state.authMethod == AuthMethod.APPLE,
                        isDarkTheme = true // Always light-on-dark in the dark card
                    )
                    
                    // Google Sign In Button
                    GoogleSignInButton(
                        onClick = onGoogleSignIn,
                        enabled = !state.isLoading,
                        isLoading = state.isLoading && state.authMethod == AuthMethod.GOOGLE
                    )
                }
                
                // Loading indicator overlay
                if (state.isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.align(Alignment.Center),
                        color = Color.White
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Terms text
            Text(
                text = "By continuing, you agree to our Terms of Use and Privacy Policy",
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.5f),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 8.dp)
            )
        }
    }
}

@Composable
private fun AppleSignInButton(
    onClick: () -> Unit,
    enabled: Boolean,
    isLoading: Boolean,
    isDarkTheme: Boolean
) {
    // Always white button on dark card (matching iOS CaptionsPrimaryButtonStyle)
    val backgroundColor = Color.White
    val contentColor = Color.Black
    
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp),
        enabled = enabled && !isLoading,
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = backgroundColor,
            contentColor = contentColor,
            disabledContainerColor = backgroundColor.copy(alpha = 0.6f),
            disabledContentColor = contentColor.copy(alpha = 0.6f)
        )
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.dp,
                color = contentColor
            )
            Spacer(modifier = Modifier.width(12.dp))
        } else {
            Icon(
                painter = painterResource(id = R.drawable.ic_apple),
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = contentColor
            )
            Spacer(modifier = Modifier.width(12.dp))
        }
        Text(
            text = "Continue with Apple",
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun GoogleSignInButton(
    onClick: () -> Unit,
    enabled: Boolean,
    isLoading: Boolean
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp),
        enabled = enabled && !isLoading,
        shape = RoundedCornerShape(14.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color(0xFF2E2E2E), // Dark pill matching iOS CaptionsDarkButtonStyle
            contentColor = Color.White,
            disabledContainerColor = Color(0xFF2E2E2E).copy(alpha = 0.6f),
            disabledContentColor = Color.White.copy(alpha = 0.6f)
        )
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.dp,
                color = Color.White
            )
            Spacer(modifier = Modifier.width(12.dp))
        } else {
            Icon(
                painter = painterResource(id = R.drawable.ic_google),
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = Color.Unspecified // Keep Google logo colors
            )
            Spacer(modifier = Modifier.width(12.dp))
        }
        Text(
            text = "Continue with Google",
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}
