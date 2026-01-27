package chat.onera.mobile.presentation.features.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.onera.mobile.R
import kotlinx.coroutines.delay

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
    var titleText by remember { mutableStateOf("") }
    var showCircle by remember { mutableStateOf(false) }
    var showDrawer by remember { mutableStateOf(false) }
    
    val fullTitle = "Let's collaborate"
    
    // Circle scale animation
    val circleScale by animateFloatAsState(
        targetValue = if (showCircle) 1f else 0f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        label = "circleScale"
    )

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
                    // Google Sign In is handled by Clerk SDK internally
                }
            }
        }
    }
    
    // Typewriter animation
    LaunchedEffect(Unit) {
        delay(300)
        for (char in fullTitle) {
            titleText += char
            delay(50)
        }
        delay(200)
        showCircle = true
        delay(400)
        showDrawer = true
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Centered header - positioned slightly above center
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.Center)
                .offset(y = if (showDrawer) (-60).dp else 0.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Text(
                    text = titleText,
                    fontSize = 32.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onBackground
                )
                
                Spacer(modifier = Modifier.width(8.dp))
                
                // Animated circle icon
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .scale(circleScale)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.onBackground)
                )
            }
        }
        
        // Bottom drawer
        AnimatedVisibility(
            visible = showDrawer,
            enter = slideInVertically(
                initialOffsetY = { it },
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioMediumBouncy,
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
                    .padding(bottom = if (showDrawer) 200.dp else 16.dp),
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
        shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 2.dp
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(top = 24.dp, bottom = 34.dp),
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
                        isDarkTheme = isDarkTheme
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
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Terms text
            Text(
                text = "By continuing, you agree to our Terms of Use and Privacy Policy",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
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
    val backgroundColor = if (isDarkTheme) Color.White else Color.Black
    val contentColor = if (isDarkTheme) Color.Black else Color.White
    
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp),
        enabled = enabled && !isLoading,
        shape = RoundedCornerShape(28.dp),
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
            fontWeight = FontWeight.Medium
        )
    }
}

@Composable
private fun GoogleSignInButton(
    onClick: () -> Unit,
    enabled: Boolean,
    isLoading: Boolean
) {
    OutlinedButton(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp),
        enabled = enabled && !isLoading,
        shape = RoundedCornerShape(28.dp),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = MaterialTheme.colorScheme.surface,
            contentColor = MaterialTheme.colorScheme.onSurface
        ),
        border = ButtonDefaults.outlinedButtonBorder.copy(
            brush = androidx.compose.ui.graphics.SolidColor(
                MaterialTheme.colorScheme.onSurface.copy(alpha = 0.15f)
            )
        )
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.dp,
                color = MaterialTheme.colorScheme.onSurface
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
            fontWeight = FontWeight.Medium
        )
    }
}
