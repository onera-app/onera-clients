package chat.onera.mobile.presentation.features.e2ee

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.fragment.app.FragmentActivity
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.onera.mobile.presentation.components.LoadingButton

/**
 * Unlock method options for E2EE
 * Matches web flow: options, password, recovery, reset
 * Note: Passkey unlock triggers directly from options (no separate view)
 */
enum class UnlockMethod {
    OPTIONS,
    PASSWORD,
    RECOVERY,
    RESET
}

/**
 * E2EE Unlock screen for returning users
 * Matches iOS E2EEUnlockView functionality
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun E2EEUnlockScreen(
    viewModel: E2EEUnlockViewModel = hiltViewModel(),
    onUnlockComplete: () -> Unit,
    onResetComplete: () -> Unit = {},
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var currentMethod by remember { mutableStateOf(UnlockMethod.OPTIONS) }
    
    // Get the activity for biometric prompts
    val context = LocalContext.current
    val activity = context as? FragmentActivity
    
    // Set activity reference for biometric authentication
    DisposableEffect(activity) {
        viewModel.setActivity(activity)
        onDispose {
            viewModel.setActivity(null)
        }
    }
    
    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is E2EEUnlockEffect.UnlockComplete -> onUnlockComplete()
                is E2EEUnlockEffect.NavigateBack -> onBack()
                is E2EEUnlockEffect.ShowError -> { /* Handled by state */ }
                is E2EEUnlockEffect.ResetComplete -> onResetComplete()
            }
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        when (currentMethod) {
                            UnlockMethod.RESET -> "Reset Encryption"
                            else -> "Unlock"
                        }
                    ) 
                },
                navigationIcon = {
                    if (currentMethod != UnlockMethod.OPTIONS || state.hasMultipleOptions) {
                        IconButton(onClick = {
                            when (currentMethod) {
                                UnlockMethod.OPTIONS -> viewModel.sendIntent(E2EEUnlockIntent.GoBack)
                                UnlockMethod.RESET -> {
                                    viewModel.sendIntent(E2EEUnlockIntent.CancelResetEncryption)
                                    currentMethod = UnlockMethod.RECOVERY
                                }
                                else -> currentMethod = UnlockMethod.OPTIONS
                            }
                        }) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "Back"
                            )
                        }
                    }
                }
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                state.isCheckingMethods -> LoadingView()
                state.isUnlocking -> UnlockingView(method = currentMethod)
                state.isResetting -> ResettingView()
                else -> {
                    when (currentMethod) {
                        UnlockMethod.OPTIONS -> UnlockOptionsView(
                            state = state,
                            onSelectPassword = { currentMethod = UnlockMethod.PASSWORD },
                            onSelectRecovery = { currentMethod = UnlockMethod.RECOVERY },
                            onPasskeyUnlock = { viewModel.sendIntent(E2EEUnlockIntent.UnlockWithPasskey) }
                        )
                        UnlockMethod.PASSWORD -> PasswordUnlockView(
                            password = state.password,
                            showPassword = state.showPassword,
                            error = state.error,
                            isLoading = state.isUnlocking,
                            onPasswordChange = { viewModel.sendIntent(E2EEUnlockIntent.UpdatePassword(it)) },
                            onTogglePassword = { viewModel.sendIntent(E2EEUnlockIntent.TogglePasswordVisibility) },
                            onUnlock = { viewModel.sendIntent(E2EEUnlockIntent.UnlockWithPassword) }
                        )
                        UnlockMethod.RECOVERY -> RecoveryPhraseUnlockView(
                            words = state.recoveryWords,
                            pastedPhrase = state.pastedPhrase,
                            showPasteField = state.showPasteField,
                            error = state.error,
                            isLoading = state.isUnlocking,
                            onWordChange = { index, word -> 
                                viewModel.sendIntent(E2EEUnlockIntent.UpdateRecoveryWord(index, word)) 
                            },
                            onPastedPhraseChange = { viewModel.sendIntent(E2EEUnlockIntent.UpdatePastedPhrase(it)) },
                            onToggleInputMode = { viewModel.sendIntent(E2EEUnlockIntent.ToggleInputMode) },
                            onUnlock = { viewModel.sendIntent(E2EEUnlockIntent.UnlockWithRecoveryPhrase) },
                            onResetEncryption = { currentMethod = UnlockMethod.RESET }
                        )
                        UnlockMethod.RESET -> ResetEncryptionView(
                            confirmInput = state.resetConfirmInput,
                            error = state.resetError,
                            isResetting = state.isResetting,
                            onConfirmInputChange = { viewModel.sendIntent(E2EEUnlockIntent.UpdateResetConfirmInput(it)) },
                            onConfirmReset = { viewModel.sendIntent(E2EEUnlockIntent.ConfirmResetEncryption) },
                            onCancel = { 
                                viewModel.sendIntent(E2EEUnlockIntent.CancelResetEncryption)
                                currentMethod = UnlockMethod.RECOVERY 
                            }
                        )
                    }
                }
            }
            
            // Error snackbar
            state.error?.let { error ->
                if (currentMethod != UnlockMethod.RESET) {
                    Snackbar(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(16.dp),
                        action = {
                            TextButton(onClick = { viewModel.sendIntent(E2EEUnlockIntent.ClearError) }) {
                                Text("Dismiss")
                            }
                        }
                    ) {
                        Text(error)
                    }
                }
            }
        }
    }
}

@Composable
private fun LoadingView() {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        CircularProgressIndicator()
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Loading...",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun UnlockingView(method: UnlockMethod) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        val icon = when (method) {
            UnlockMethod.PASSWORD -> Icons.Default.Key
            UnlockMethod.OPTIONS -> Icons.Default.Fingerprint // Passkey unlock from options
            else -> Icons.Default.Lock
        }
        
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        CircularProgressIndicator()
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Unlocking...",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun ResettingView() {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.DeleteForever,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.error
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        CircularProgressIndicator(color = MaterialTheme.colorScheme.error)
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Resetting encryption...",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun UnlockOptionsView(
    state: E2EEUnlockState,
    onSelectPassword: () -> Unit,
    onSelectRecovery: () -> Unit,
    onPasskeyUnlock: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Header
        Icon(
            imageVector = Icons.Default.Lock,
            contentDescription = null,
            modifier = Modifier.size(56.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Unlock your encrypted data to continue.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(32.dp))
        
        // Unlock options
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            // Passkey option - available if user has any passkeys (local or synced from web)
            if (state.hasPasskey || state.hasLocalPasskey) {
                UnlockOptionCard(
                    icon = Icons.Default.Fingerprint,
                    iconTint = Color(0xFF007AFF),
                    title = "Passkey",
                    subtitle = if (state.hasLocalPasskey) "Use Face ID or fingerprint" else "Use synced passkey",
                    badge = if (state.hasLocalPasskey) "Recommended" else null,
                    onClick = onPasskeyUnlock
                )
            }
            
            // Password option
            if (state.hasPassword) {
                UnlockOptionCard(
                    icon = Icons.Default.Key,
                    iconTint = Color(0xFFFF9500),
                    title = "Password",
                    subtitle = "Use your encryption password",
                    onClick = onSelectPassword
                )
            }
            
            // Recovery phrase option
            UnlockOptionCard(
                icon = Icons.Default.GridView,
                iconTint = Color(0xFFAF52DE),
                title = "Recovery Phrase",
                subtitle = "Enter your 24-word phrase",
                onClick = onSelectRecovery
            )
        }
    }
}

@Composable
private fun UnlockOptionCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    iconTint: Color,
    title: String,
    subtitle: String,
    badge: String? = null,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(28.dp),
                tint = iconTint
            )
            
            Spacer(modifier = Modifier.width(16.dp))
            
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium
                    )
                    
                    badge?.let {
                        Spacer(modifier = Modifier.width(8.dp))
                        Surface(
                            shape = RoundedCornerShape(4.dp),
                            color = Color(0xFF007AFF)
                        ) {
                            Text(
                                text = it,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                style = MaterialTheme.typography.labelSmall,
                                color = Color.White
                            )
                        }
                    }
                }
                
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
            )
        }
    }
}

@Composable
private fun PasswordUnlockView(
    password: String,
    showPassword: Boolean,
    error: String?,
    isLoading: Boolean,
    onPasswordChange: (String) -> Unit,
    onTogglePassword: () -> Unit,
    onUnlock: () -> Unit
) {
    val focusRequester = remember { FocusRequester() }
    
    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.Key,
            contentDescription = null,
            modifier = Modifier.size(56.dp),
            tint = Color(0xFFFF9500)
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Enter your encryption password to unlock.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(32.dp))
        
        OutlinedTextField(
            value = password,
            onValueChange = onPasswordChange,
            modifier = Modifier
                .fillMaxWidth()
                .focusRequester(focusRequester),
            label = { Text("Password") },
            visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
            trailingIcon = {
                IconButton(onClick = onTogglePassword) {
                    Icon(
                        imageVector = if (showPassword) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                        contentDescription = if (showPassword) "Hide password" else "Show password"
                    )
                }
            },
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Password,
                imeAction = ImeAction.Done
            ),
            keyboardActions = KeyboardActions(
                onDone = { onUnlock() }
            ),
            singleLine = true,
            isError = error != null
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        LoadingButton(
            text = "Unlock",
            onClick = onUnlock,
            isLoading = isLoading,
            enabled = password.isNotBlank(),
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun RecoveryPhraseUnlockView(
    words: List<String>,
    pastedPhrase: String,
    showPasteField: Boolean,
    error: String?,
    isLoading: Boolean,
    onWordChange: (Int, String) -> Unit,
    onPastedPhraseChange: (String) -> Unit,
    onToggleInputMode: () -> Unit,
    onUnlock: () -> Unit,
    onResetEncryption: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.GridView,
            contentDescription = null,
            modifier = Modifier.size(56.dp),
            tint = Color(0xFFAF52DE)
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Enter your 24-word recovery phrase.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        // Toggle input mode button
        TextButton(onClick = onToggleInputMode) {
            Icon(
                imageVector = if (showPasteField) Icons.Default.GridView else Icons.Default.ContentPaste,
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(if (showPasteField) "Enter words individually" else "Paste full phrase")
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        if (showPasteField) {
            OutlinedTextField(
                value = pastedPhrase,
                onValueChange = onPastedPhraseChange,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(150.dp),
                label = { Text("Paste Recovery Phrase") },
                textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace)
            )
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.height(400.dp)
            ) {
                itemsIndexed(words) { index, word ->
                    RecoveryWordInput(
                        index = index,
                        word = word,
                        onWordChange = { onWordChange(index, it) }
                    )
                }
            }
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        
        LoadingButton(
            text = "Unlock",
            onClick = onUnlock,
            isLoading = isLoading,
            enabled = if (showPasteField) pastedPhrase.isNotBlank() else words.all { it.isNotBlank() },
            modifier = Modifier.fillMaxWidth()
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Reset encryption link
        TextButton(onClick = onResetEncryption) {
            Text(
                text = "Lost your recovery phrase? Reset encryption",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error.copy(alpha = 0.8f)
            )
        }
    }
}

@Composable
private fun ResetEncryptionView(
    confirmInput: String,
    error: String?,
    isResetting: Boolean,
    onConfirmInputChange: (String) -> Unit,
    onConfirmReset: () -> Unit,
    onCancel: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.DeleteForever,
            contentDescription = null,
            modifier = Modifier.size(56.dp),
            tint = MaterialTheme.colorScheme.error
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Reset Encryption",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.error
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Warning card
        Card(
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.errorContainer
            )
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.Top) {
                    Icon(
                        imageVector = Icons.Default.Warning,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onErrorContainer,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "This action cannot be undone!",
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onErrorContainer
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Resetting your encryption will permanently delete your encryption keys. " +
                                    "Any encrypted data (chats, notes, API keys) will become inaccessible forever.",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onErrorContainer
                        )
                    }
                }
            }
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text(
            text = "Type RESET MY ENCRYPTION to confirm:",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium
        )
        
        Spacer(modifier = Modifier.height(12.dp))
        
        OutlinedTextField(
            value = confirmInput,
            onValueChange = onConfirmInputChange,
            modifier = Modifier.fillMaxWidth(),
            placeholder = { Text("RESET MY ENCRYPTION") },
            singleLine = true,
            isError = error != null,
            textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace)
        )
        
        error?.let {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = it,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error
            )
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedButton(
                onClick = onCancel,
                modifier = Modifier.weight(1f),
                enabled = !isResetting
            ) {
                Text("Cancel")
            }
            
            Button(
                onClick = onConfirmReset,
                modifier = Modifier.weight(1f),
                enabled = confirmInput == "RESET MY ENCRYPTION" && !isResetting,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.error,
                    contentColor = MaterialTheme.colorScheme.onError
                )
            ) {
                if (isResetting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        color = MaterialTheme.colorScheme.onError,
                        strokeWidth = 2.dp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Icon(
                    imageVector = Icons.Default.DeleteForever,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Reset")
            }
        }
    }
}

@Composable
private fun RecoveryWordInput(
    index: Int,
    word: String,
    onWordChange: (String) -> Unit
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.outline,
                shape = RoundedCornerShape(6.dp)
            )
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(horizontal = 8.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "${index + 1}.",
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(20.dp)
        )
        
        androidx.compose.foundation.text.BasicTextField(
            value = word,
            onValueChange = onWordChange,
            modifier = Modifier.weight(1f),
            textStyle = LocalTextStyle.current.copy(
                fontFamily = FontFamily.Monospace,
                fontSize = 12.sp
            ),
            singleLine = true
        )
    }
}
