package chat.onera.mobile.presentation.features.settings

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.onera.mobile.presentation.theme.EncryptionGreen
import coil.compose.AsyncImage

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = hiltViewModel(),
    onBack: () -> Unit,
    onSecuritySettings: () -> Unit,
    onAccountSettings: () -> Unit,
    onEncryptionKeys: () -> Unit,
    onAPICredentials: (() -> Unit)? = null,
    onAppearance: (() -> Unit)? = null,
    onSignOut: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var showSignOutDialog by remember { mutableStateOf(false) }
    val context = LocalContext.current
    
    // Handle one-time effects
    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is SettingsEffect.SignOutComplete -> onSignOut()
                is SettingsEffect.SessionLocked -> onSignOut() // Navigate to auth/unlock
                is SettingsEffect.ShowError -> {
                    Toast.makeText(context, effect.message, Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Profile header
            item {
                ProfileHeader(
                    name = state.user?.displayName ?: "User",
                    email = state.user?.email ?: "",
                    avatarUrl = state.user?.avatarUrl,
                    onEditProfile = onAccountSettings
                )
            }
            
            // Encryption status
            item {
                EncryptionStatusCard(
                    isActive = state.isE2EEActive,
                    modifier = Modifier.padding(16.dp)
                )
            }

            // Account section
            item {
                SettingsSection(title = "Account") {
                    SettingsItem(
                        icon = Icons.Outlined.Person,
                        title = "Account Settings",
                        subtitle = "Email, profile, linked accounts",
                        onClick = onAccountSettings
                    )
                }
            }

            // Security section
            item {
                SettingsSection(title = "Security") {
                    SettingsItem(
                        icon = Icons.Outlined.Lock,
                        title = "E2EE Security",
                        subtitle = if (state.isE2EEActive) "Active" else "Locked",
                        onClick = onSecuritySettings,
                        trailing = {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .background(
                                        color = if (state.isE2EEActive) EncryptionGreen else MaterialTheme.colorScheme.error,
                                        shape = CircleShape
                                    )
                            )
                        }
                    )
                    SettingsItem(
                        icon = Icons.Outlined.Key,
                        title = "Recovery Phrase",
                        subtitle = "View your backup phrase",
                        onClick = onEncryptionKeys
                    )
                    SettingsItem(
                        icon = Icons.Outlined.Devices,
                        title = "Manage Devices",
                        subtitle = "${state.deviceCount} device(s) registered",
                        onClick = { 
                            Toast.makeText(context, "Device management coming soon", Toast.LENGTH_SHORT).show()
                        }
                    )
                    if (onAPICredentials != null) {
                        SettingsItem(
                            icon = Icons.Outlined.VpnKey,
                            title = "API Connections",
                            subtitle = "${state.credentialCount} API key(s) configured",
                            onClick = onAPICredentials
                        )
                    }
                }
            }

            // App section
            item {
                SettingsSection(title = "App") {
                    if (onAppearance != null) {
                        SettingsItem(
                            icon = Icons.Outlined.Palette,
                            title = "Appearance",
                            subtitle = state.themeMode,
                            onClick = onAppearance
                        )
                    }
                    SettingsItem(
                        icon = Icons.Outlined.Notifications,
                        title = "Notifications",
                        subtitle = "Manage notification settings",
                        onClick = { 
                            Toast.makeText(context, "Notification settings coming soon", Toast.LENGTH_SHORT).show()
                        }
                    )
                }
            }

            // About section
            item {
                SettingsSection(title = "About") {
                    SettingsItem(
                        icon = Icons.Outlined.Info,
                        title = "About Onera",
                        subtitle = "Version ${state.appVersion}",
                        onClick = { 
                            Toast.makeText(context, "Onera - Your private AI assistant", Toast.LENGTH_SHORT).show()
                        }
                    )
                    SettingsItem(
                        icon = Icons.Outlined.Description,
                        title = "Privacy Policy",
                        onClick = { 
                            // TODO: Open privacy policy URL in browser
                            Toast.makeText(context, "Privacy policy at onera.chat/privacy", Toast.LENGTH_SHORT).show()
                        }
                    )
                    SettingsItem(
                        icon = Icons.Outlined.Gavel,
                        title = "Terms of Service",
                        onClick = { 
                            // TODO: Open terms URL in browser
                            Toast.makeText(context, "Terms at onera.chat/terms", Toast.LENGTH_SHORT).show()
                        }
                    )
                }
            }

            // Sign out
            item {
                Spacer(modifier = Modifier.height(16.dp))
                
                ListItem(
                    headlineContent = {
                        Text(
                            text = "Sign Out",
                            color = MaterialTheme.colorScheme.error
                        )
                    },
                    leadingContent = {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ExitToApp,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error
                        )
                    },
                    modifier = Modifier.clickable { showSignOutDialog = true }
                )
                
                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }

    if (showSignOutDialog) {
        AlertDialog(
            onDismissRequest = { showSignOutDialog = false },
            icon = {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.error
                )
            },
            title = { Text("Sign Out?") },
            text = {
                Text(
                    "Make sure you have backed up your recovery phrase. " +
                            "You'll need it to access your encrypted messages on a new device."
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showSignOutDialog = false
                        viewModel.sendIntent(SettingsIntent.SignOut)
                    }
                ) {
                    Text("Sign Out", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showSignOutDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun ProfileHeader(
    name: String,
    email: String,
    avatarUrl: String?,
    onEditProfile: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onEditProfile)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Avatar
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primaryContainer),
            contentAlignment = Alignment.Center
        ) {
            if (avatarUrl != null) {
                AsyncImage(
                    model = avatarUrl,
                    contentDescription = "Profile picture",
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                Text(
                    text = name.firstOrNull()?.uppercase() ?: "?",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
            }
        }
        
        Spacer(modifier = Modifier.width(16.dp))
        
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = name,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = email,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        IconButton(onClick = onEditProfile) {
            Icon(
                imageVector = Icons.Default.Edit,
                contentDescription = "Edit profile",
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun EncryptionStatusCard(
    isActive: Boolean,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(
                        if (isActive) EncryptionGreen.copy(alpha = 0.2f)
                        else MaterialTheme.colorScheme.error.copy(alpha = 0.2f)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = if (isActive) Icons.Default.Lock else Icons.Default.LockOpen,
                    contentDescription = null,
                    tint = if (isActive) EncryptionGreen else MaterialTheme.colorScheme.error,
                    modifier = Modifier.size(24.dp)
                )
            }
            
            Spacer(modifier = Modifier.width(16.dp))
            
            Column {
                Text(
                    text = if (isActive) "End-to-End Encrypted" else "Session Locked",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium
                )
                Text(
                    text = if (isActive) "Your messages are secure" else "Unlock to access your data",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Column {
        Text(
            text = title.uppercase(),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
        )
        content()
    }
}

@Composable
private fun SettingsItem(
    icon: ImageVector,
    title: String,
    subtitle: String? = null,
    onClick: () -> Unit,
    trailing: @Composable (() -> Unit)? = null
) {
    ListItem(
        headlineContent = { Text(title) },
        supportingContent = subtitle?.let { { Text(it) } },
        leadingContent = {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        },
        trailingContent = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                trailing?.invoke()
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        modifier = Modifier.clickable(onClick = onClick)
    )
}
