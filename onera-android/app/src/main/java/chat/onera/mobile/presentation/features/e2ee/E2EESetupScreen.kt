package chat.onera.mobile.presentation.features.e2ee

import android.app.Activity
import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import android.content.ClipData
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.material3.LocalTextStyle
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.onera.mobile.presentation.components.LoadingButton
import chat.onera.mobile.presentation.theme.EncryptionGreen
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun E2EESetupScreen(
    viewModel: E2EESetupViewModel = hiltViewModel(),
    onSetupComplete: () -> Unit,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    
    // Get the activity for passkey registration
    val context = LocalContext.current
    val activity = context as? Activity
    
    // Set activity reference for passkey registration
    DisposableEffect(activity) {
        viewModel.setActivity(activity)
        onDispose {
            viewModel.setActivity(null)
        }
    }

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is E2EESetupEffect.SetupComplete -> onSetupComplete()
                is E2EESetupEffect.NavigateBack -> onBack()
                is E2EESetupEffect.ShowError -> { /* Show snackbar */ }
                is E2EESetupEffect.CopyToClipboard -> { /* Copy */ }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Encryption Setup") },
                navigationIcon = {
                    IconButton(onClick = { viewModel.sendIntent(E2EESetupIntent.GoBack) }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(24.dp)
        ) {
            when (state.step) {
                E2EESetupStep.INTRO -> IntroStep(
                    onContinue = { viewModel.sendIntent(E2EESetupIntent.StartSetup) }
                )
                E2EESetupStep.GENERATING_KEYS -> GeneratingKeysStep()
                E2EESetupStep.SETUP_PASSKEY -> PasskeySetupStep(
                    isLoading = state.isRegisteringPasskey,
                    error = state.error,
                    onRegisterPasskey = { viewModel.sendIntent(E2EESetupIntent.RegisterPasskey) },
                    onUsePassword = { viewModel.sendIntent(E2EESetupIntent.SkipPasskey) }
                )
                E2EESetupStep.SETUP_PASSWORD -> PasswordSetupStep(
                    password = state.password,
                    confirmPassword = state.confirmPassword,
                    showPassword = state.showPassword,
                    error = state.error,
                    isLoading = state.isSettingUpPassword,
                    onPasswordChange = { viewModel.sendIntent(E2EESetupIntent.UpdateSetupPassword(it)) },
                    onConfirmPasswordChange = { viewModel.sendIntent(E2EESetupIntent.UpdateConfirmPassword(it)) },
                    onTogglePassword = { viewModel.sendIntent(E2EESetupIntent.ToggleSetupPasswordVisibility) },
                    onSetupPassword = { viewModel.sendIntent(E2EESetupIntent.SetupPassword) }
                )
                E2EESetupStep.SHOW_RECOVERY_PHRASE -> ShowRecoveryPhraseStep(
                    phrase = state.recoveryPhrase,
                    onContinue = { viewModel.sendIntent(E2EESetupIntent.PhraseConfirmed) }
                )
                E2EESetupStep.VERIFY_RECOVERY_PHRASE -> VerifyRecoveryPhraseStep(
                    verificationWords = state.verificationWords,
                    userInputWords = state.userInputWords,
                    error = state.error,
                    onWordChanged = { index, word -> 
                        viewModel.sendIntent(E2EESetupIntent.VerifyWord(index, word))
                    },
                    onSubmit = { viewModel.sendIntent(E2EESetupIntent.SubmitVerification) }
                )
                E2EESetupStep.COMPLETE -> CompleteStep(
                    isLoading = state.isLoading,
                    passkeyRegistered = state.passkeyRegistered,
                    passwordSetUp = state.passwordSetUp,
                    onComplete = { viewModel.sendIntent(E2EESetupIntent.CompleteSetup) }
                )
            }
            
            // Error snackbar
            state.error?.let { error ->
                if (state.step == E2EESetupStep.SETUP_PASSKEY || state.step == E2EESetupStep.SETUP_PASSWORD) {
                    Snackbar(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(16.dp),
                        action = {
                            TextButton(onClick = { viewModel.sendIntent(E2EESetupIntent.ClearError) }) {
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
private fun IntroStep(onContinue: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Lock,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = EncryptionGreen
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text(
            text = "End-to-End Encryption",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Your messages will be encrypted using keys that only you control. " +
                    "We'll create a recovery phrase that you can use to restore your keys on any device.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(32.dp))
        
        Card(
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Key,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "Your keys stay on your device",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Security,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "We can never read your messages",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Restore,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "Recovery phrase for backup",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }
        
        Spacer(modifier = Modifier.height(48.dp))
        
        Button(
            onClick = onContinue,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Set Up Encryption")
        }
    }
}

@Composable
private fun GeneratingKeysStep() {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        CircularProgressIndicator(modifier = Modifier.size(64.dp))
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text(
            text = "Generating encryption keys...",
            style = MaterialTheme.typography.titleMedium
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "This may take a moment",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun PasskeySetupStep(
    isLoading: Boolean,
    error: String?,
    onRegisterPasskey: () -> Unit,
    onUsePassword: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Fingerprint,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = Color(0xFF007AFF)
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text(
            text = "Set Up Passkey",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Use Face ID or fingerprint to quickly unlock your encrypted data. " +
                    "This is the most convenient and secure way to access your messages.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        // Benefits card
        Card(
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Speed,
                        contentDescription = null,
                        tint = Color(0xFF007AFF)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "Instant unlock with biometrics",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Security,
                        contentDescription = null,
                        tint = Color(0xFF007AFF)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "Device-level security protection",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.PhonelinkLock,
                        contentDescription = null,
                        tint = Color(0xFF007AFF)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "No password to remember",
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }
        
        Spacer(modifier = Modifier.height(48.dp))
        
        LoadingButton(
            text = "Set Up Passkey",
            onClick = onRegisterPasskey,
            isLoading = isLoading,
            modifier = Modifier.fillMaxWidth()
        )
        
        Spacer(modifier = Modifier.height(12.dp))
        
        TextButton(
            onClick = onUsePassword,
            enabled = !isLoading
        ) {
            Text("Use password instead")
        }
    }
}

@Composable
private fun PasswordSetupStep(
    password: String,
    confirmPassword: String,
    showPassword: Boolean,
    error: String?,
    isLoading: Boolean,
    onPasswordChange: (String) -> Unit,
    onConfirmPasswordChange: (String) -> Unit,
    onTogglePassword: () -> Unit,
    onSetupPassword: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.Key,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = Color(0xFFFF9500)
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text(
            text = "Set Encryption Password",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "This password will unlock your encrypted data. " +
                    "Make sure to choose a strong password you'll remember.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(32.dp))
        
        OutlinedTextField(
            value = password,
            onValueChange = onPasswordChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Password") },
            placeholder = { Text("Enter a strong password") },
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
                imeAction = ImeAction.Next
            ),
            singleLine = true,
            isError = error != null && password.isNotEmpty()
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        OutlinedTextField(
            value = confirmPassword,
            onValueChange = onConfirmPasswordChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Confirm Password") },
            placeholder = { Text("Confirm your password") },
            visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Password,
                imeAction = ImeAction.Done
            ),
            keyboardActions = KeyboardActions(
                onDone = { if (password.isNotBlank() && password == confirmPassword) onSetupPassword() }
            ),
            singleLine = true,
            isError = confirmPassword.isNotEmpty() && password != confirmPassword
        )
        
        if (confirmPassword.isNotEmpty() && password != confirmPassword) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Passwords do not match",
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall
            )
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Password requirements
        Card(
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Password requirements:",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(8.dp))
                
                val hasMinLength = password.length >= 8
                PasswordRequirement(
                    text = "At least 8 characters",
                    met = hasMinLength
                )
            }
        }
        
        error?.let {
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = it,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall
            )
        }
        
        Spacer(modifier = Modifier.height(32.dp))
        
        LoadingButton(
            text = "Set Password",
            onClick = onSetupPassword,
            isLoading = isLoading,
            enabled = password.length >= 8 && password == confirmPassword,
            modifier = Modifier.fillMaxWidth()
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "This is separate from your account password.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun PasswordRequirement(
    text: String,
    met: Boolean
) {
    Row(
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = if (met) Icons.Default.Check else Icons.Default.Close,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = if (met) EncryptionGreen else MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            color = if (met) EncryptionGreen else MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun ShowRecoveryPhraseStep(
    phrase: List<String>,
    onContinue: () -> Unit
) {
    val context = LocalContext.current
    val clipboard = LocalClipboard.current
    val coroutineScope = rememberCoroutineScope()
    var showCopiedSnackbar by remember { mutableStateOf(false) }
    
    val phraseText = phrase.joinToString(" ")
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.Warning,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = MaterialTheme.colorScheme.error
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Backup Recovery Phrase",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "Save this as insurance in case you ever lose access to your passkey or password.",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Copy and Download buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedButton(
                onClick = {
                    coroutineScope.launch {
                        clipboard.setClipEntry(ClipEntry(ClipData.newPlainText("recovery_phrase", phraseText)))
                    }
                    showCopiedSnackbar = true
                },
                modifier = Modifier.weight(1f)
            ) {
                Icon(
                    imageVector = Icons.Default.ContentCopy,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Copy")
            }
            
            OutlinedButton(
                onClick = {
                    // Save to file and share
                    try {
                        val file = File(context.cacheDir, "recovery_phrase.txt")
                        file.writeText("Onera Recovery Phrase\n\n$phraseText\n\nKeep this safe and never share it with anyone!")
                        
                        val uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.provider",
                            file
                        )
                        
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        context.startActivity(Intent.createChooser(intent, "Save Recovery Phrase"))
                    } catch (e: Exception) {
                        // Fallback: just copy to clipboard
                        coroutineScope.launch {
                            clipboard.setClipEntry(ClipEntry(ClipData.newPlainText("recovery_phrase", phraseText)))
                        }
                        showCopiedSnackbar = true
                    }
                },
                modifier = Modifier.weight(1f)
            ) {
                Icon(
                    imageVector = Icons.Default.Download,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Download")
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Recovery phrase grid
        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            phrase.chunked(3).forEachIndexed { rowIndex, rowWords ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    rowWords.forEachIndexed { colIndex, word ->
                        val index = rowIndex * 3 + colIndex + 1
                        Box(modifier = Modifier.weight(1f)) {
                            RecoveryWordItem(index = index, word = word)
                        }
                    }
                    // Fill remaining space if row is incomplete
                    repeat(3 - rowWords.size) {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Card(
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.errorContainer
            )
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onErrorContainer
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "Never share your recovery phrase with anyone!",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onErrorContainer
                )
            }
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Button(
            onClick = onContinue,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("I've Saved My Recovery Phrase")
        }
    }
    
    // Snackbar for copy confirmation
    if (showCopiedSnackbar) {
        LaunchedEffect(Unit) {
            kotlinx.coroutines.delay(2000)
            showCopiedSnackbar = false
        }
    }
}

@Composable
private fun RecoveryWordItem(index: Int, word: String) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.outline,
                shape = RoundedCornerShape(8.dp)
            )
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "$index.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.width(4.dp))
        Text(
            text = word,
            style = MaterialTheme.typography.bodyMedium,
            fontFamily = FontFamily.Monospace
        )
    }
}

@Composable
private fun VerifyRecoveryPhraseStep(
    verificationWords: List<IndexedWord>,
    userInputWords: Map<Int, String>,
    error: String?,
    onWordChanged: (Int, String) -> Unit,
    onSubmit: () -> Unit
) {
    val clipboard = LocalClipboard.current
    val coroutineScope = rememberCoroutineScope()
    var showPasteOption by remember { mutableStateOf(false) }
    var pastedPhrase by remember { mutableStateOf("") }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = "Verify Your Recovery Phrase",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = if (showPasteOption) 
                "Paste your full recovery phrase to verify:" 
            else 
                "Enter the following words from your recovery phrase:",
            style = MaterialTheme.typography.bodyMedium,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Toggle between paste and manual entry
        TextButton(
            onClick = { showPasteOption = !showPasteOption }
        ) {
            Icon(
                imageVector = if (showPasteOption) Icons.Default.Edit else Icons.Default.ContentPaste,
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(if (showPasteOption) "Enter words manually" else "Paste full phrase")
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        if (showPasteOption) {
            // Paste mode
            OutlinedTextField(
                value = pastedPhrase,
                onValueChange = { newValue ->
                    pastedPhrase = newValue
                    // Parse and fill in the verification words
                    val words = newValue.trim().lowercase().split("\\s+".toRegex())
                    verificationWords.forEach { indexed ->
                        if (indexed.index < words.size) {
                            onWordChanged(indexed.index, words[indexed.index])
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp),
                label = { Text("Recovery Phrase") },
                placeholder = { Text("Paste your recovery phrase here...") },
                textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace),
                trailingIcon = {
                    IconButton(
                        onClick = {
                            coroutineScope.launch {
                                clipboard.getClipEntry()?.clipData?.getItemAt(0)?.text?.toString()?.let { text ->
                                    pastedPhrase = text
                                    // Parse and fill in the verification words
                                    val words = text.trim().lowercase().split("\\s+".toRegex())
                                    verificationWords.forEach { indexed ->
                                        if (indexed.index < words.size) {
                                            onWordChanged(indexed.index, words[indexed.index])
                                        }
                                    }
                                }
                            }
                        }
                    ) {
                        Icon(
                            imageVector = Icons.Default.ContentPaste,
                            contentDescription = "Paste from clipboard"
                        )
                    }
                }
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            // Show which words will be verified
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Verifying words:",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    verificationWords.forEach { indexed ->
                        val inputWord = userInputWords[indexed.index] ?: ""
                        val isCorrect = inputWord.equals(indexed.word, ignoreCase = true)
                        Row(
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Word #${indexed.index + 1}: ",
                                style = MaterialTheme.typography.bodySmall
                            )
                            Text(
                                text = inputWord.ifBlank { "—" },
                                style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                                color = if (inputWord.isBlank()) 
                                    MaterialTheme.colorScheme.onSurfaceVariant 
                                else if (isCorrect) 
                                    EncryptionGreen 
                                else 
                                    MaterialTheme.colorScheme.error
                            )
                            if (inputWord.isNotBlank()) {
                                Spacer(modifier = Modifier.width(4.dp))
                                Icon(
                                    imageVector = if (isCorrect) Icons.Default.Check else Icons.Default.Close,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp),
                                    tint = if (isCorrect) EncryptionGreen else MaterialTheme.colorScheme.error
                                )
                            }
                        }
                    }
                }
            }
        } else {
            // Manual entry mode
            verificationWords.forEach { indexed ->
                OutlinedTextField(
                    value = userInputWords[indexed.index] ?: "",
                    onValueChange = { onWordChanged(indexed.index, it) },
                    label = { Text("Word #${indexed.index + 1}") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    textStyle = LocalTextStyle.current.copy(fontFamily = FontFamily.Monospace),
                    trailingIcon = {
                        val inputWord = userInputWords[indexed.index] ?: ""
                        if (inputWord.isNotBlank()) {
                            val isCorrect = inputWord.equals(indexed.word, ignoreCase = true)
                            Icon(
                                imageVector = if (isCorrect) Icons.Default.Check else Icons.Default.Close,
                                contentDescription = null,
                                tint = if (isCorrect) EncryptionGreen else MaterialTheme.colorScheme.error
                            )
                        }
                    }
                )
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
        
        error?.let {
            Text(
                text = it,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall
            )
            Spacer(modifier = Modifier.height(16.dp))
        }
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Button(
            onClick = onSubmit,
            modifier = Modifier.fillMaxWidth(),
            enabled = verificationWords.all { userInputWords[it.index]?.isNotBlank() == true }
        ) {
            Text("Verify")
        }
    }
}

@Composable
private fun CompleteStep(
    isLoading: Boolean,
    passkeyRegistered: Boolean = false,
    passwordSetUp: Boolean = false,
    onComplete: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.CheckCircle,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = EncryptionGreen
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text(
            text = "Encryption Setup Complete!",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = "Your messages are now protected with end-to-end encryption. " +
                    "Only you can read your conversations.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // Show unlock method status
        if (passkeyRegistered) {
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF007AFF).copy(alpha = 0.1f)
                )
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Fingerprint,
                        contentDescription = null,
                        tint = Color(0xFF007AFF)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "Passkey enabled for quick unlock",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFF007AFF)
                    )
                }
            }
        } else if (passwordSetUp) {
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFFFF9500).copy(alpha = 0.1f)
                )
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Key,
                        contentDescription = null,
                        tint = Color(0xFFFF9500)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = "Password encryption enabled",
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color(0xFFFF9500)
                    )
                }
            }
        }
        
        Spacer(modifier = Modifier.height(48.dp))
        
        LoadingButton(
            text = "Start Chatting",
            onClick = onComplete,
            isLoading = isLoading,
            modifier = Modifier.fillMaxWidth()
        )
    }
}
