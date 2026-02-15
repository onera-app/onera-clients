package chat.onera.mobile.presentation.features.settings.security

import android.app.Activity
import android.widget.Toast
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SecuritySettingsScreen(
    viewModel: SecuritySettingsViewModel = hiltViewModel(),
    onBack: () -> Unit,
    onNavigateToUnlock: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is SecuritySettingsEffect.ShowToast ->
                    Toast.makeText(context, effect.message, Toast.LENGTH_SHORT).show()
                is SecuritySettingsEffect.NavigateToUnlock ->
                    onNavigateToUnlock()
                is SecuritySettingsEffect.PasswordChanged -> { /* handled by toast */ }
            }
        }
    }

    // Delete passkey confirmation dialog
    state.deletePasskeyTarget?.let { passkey ->
        AlertDialog(
            onDismissRequest = { viewModel.sendIntent(SecuritySettingsIntent.DismissDeletePasskey) },
            title = { Text("Delete Passkey") },
            text = { Text("Are you sure you want to delete \"${passkey.name ?: "Unnamed passkey"}\"? This cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = { viewModel.sendIntent(SecuritySettingsIntent.DeletePasskey) },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) { Text("Delete") }
            },
            dismissButton = {
                TextButton(
                    onClick = { viewModel.sendIntent(SecuritySettingsIntent.DismissDeletePasskey) }
                ) { Text("Cancel") }
            }
        )
    }

    // Revoke device confirmation dialog
    state.revokeDeviceTarget?.let { device ->
        AlertDialog(
            onDismissRequest = { viewModel.sendIntent(SecuritySettingsIntent.DismissRevokeDevice) },
            title = { Text("Revoke Device") },
            text = { Text("Are you sure you want to revoke \"${device.name ?: device.userAgent ?: "Unknown device"}\"? It will need to re-authenticate.") },
            confirmButton = {
                TextButton(
                    onClick = { viewModel.sendIntent(SecuritySettingsIntent.RevokeDevice) },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) { Text("Revoke") }
            },
            dismissButton = {
                TextButton(
                    onClick = { viewModel.sendIntent(SecuritySettingsIntent.DismissRevokeDevice) }
                ) { Text("Cancel") }
            }
        )
    }

    // Lock session confirmation dialog
    if (state.showLockConfirmation) {
        AlertDialog(
            onDismissRequest = { viewModel.sendIntent(SecuritySettingsIntent.DismissLockConfirmation) },
            title = { Text("Lock Session") },
            text = { Text("This will clear the master key from memory. You'll need to re-authenticate to access encrypted data.") },
            confirmButton = {
                TextButton(
                    onClick = { viewModel.sendIntent(SecuritySettingsIntent.LockSession) }
                ) { Text("Lock") }
            },
            dismissButton = {
                TextButton(
                    onClick = { viewModel.sendIntent(SecuritySettingsIntent.DismissLockConfirmation) }
                ) { Text("Cancel") }
            }
        )
    }

    // Error dialog
    state.error?.let { error ->
        AlertDialog(
            onDismissRequest = { viewModel.sendIntent(SecuritySettingsIntent.DismissError) },
            title = { Text("Error") },
            text = { Text(error) },
            confirmButton = {
                TextButton(
                    onClick = { viewModel.sendIntent(SecuritySettingsIntent.DismissError) }
                ) { Text("OK") }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("E2EE Security") },
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
    ) { padding ->
        if (state.isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // ── E2EE Status ─────────────────────────────────────
                item { E2EEStatusCard(state) }

                // ── Change Password ─────────────────────────────────
                item {
                    SectionHeader(
                        "Change Password",
                        modifier = Modifier.padding(top = 16.dp)
                    )
                }
                item {
                    ChangePasswordSection(
                        state = state,
                        onCurrentPasswordChange = {
                            viewModel.sendIntent(SecuritySettingsIntent.UpdateCurrentPassword(it))
                        },
                        onNewPasswordChange = {
                            viewModel.sendIntent(SecuritySettingsIntent.UpdateNewPassword(it))
                        },
                        onConfirmPasswordChange = {
                            viewModel.sendIntent(SecuritySettingsIntent.UpdateConfirmPassword(it))
                        },
                        onSubmit = {
                            viewModel.sendIntent(SecuritySettingsIntent.SubmitPasswordChange)
                        }
                    )
                }

                // ── Passkey Management ──────────────────────────────
                item {
                    SectionHeader(
                        "Passkeys",
                        modifier = Modifier.padding(top = 16.dp)
                    )
                }
                item {
                    PasskeysSection(
                        passkeys = state.passkeys,
                        isLoading = state.isLoadingPasskeys,
                        isAdding = state.isAddingPasskey,
                        onAddPasskey = {
                            (context as? Activity)?.let { activity ->
                                viewModel.sendIntent(SecuritySettingsIntent.AddPasskey(activity))
                            }
                        },
                        onDeletePasskey = { passkey ->
                            viewModel.sendIntent(SecuritySettingsIntent.ConfirmDeletePasskey(passkey))
                        }
                    )
                }

                // ── Device Management ───────────────────────────────
                item {
                    SectionHeader(
                        "Devices",
                        modifier = Modifier.padding(top = 16.dp)
                    )
                }
                item {
                    DevicesSection(
                        devices = state.devices,
                        isLoading = state.isLoadingDevices,
                        onRevokeDevice = { device ->
                            viewModel.sendIntent(SecuritySettingsIntent.ConfirmRevokeDevice(device))
                        }
                    )
                }

                // ── Session Lock ────────────────────────────────────
                item {
                    SectionHeader(
                        "Session",
                        modifier = Modifier.padding(top = 16.dp)
                    )
                }
                item { SessionLockSection(onLock = { viewModel.sendIntent(SecuritySettingsIntent.ShowLockConfirmation) }) }

                item { Spacer(modifier = Modifier.height(32.dp)) }
            }
        }
    }
}

// ── E2EE Status Card ────────────────────────────────────────────────────

@Composable
private fun E2EEStatusCard(state: SecuritySettingsState) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = if (state.isEncryptionActive)
                MaterialTheme.colorScheme.primaryContainer
            else
                MaterialTheme.colorScheme.errorContainer
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Icon(
                imageVector = if (state.isEncryptionActive) Icons.Filled.Shield else Icons.Outlined.Warning,
                contentDescription = null,
                modifier = Modifier.size(40.dp),
                tint = if (state.isEncryptionActive)
                    MaterialTheme.colorScheme.onPrimaryContainer
                else
                    MaterialTheme.colorScheme.onErrorContainer
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = if (state.isEncryptionActive) "End-to-End Encryption Active" else "Encryption Not Configured",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = if (state.isEncryptionActive)
                        MaterialTheme.colorScheme.onPrimaryContainer
                    else
                        MaterialTheme.colorScheme.onErrorContainer
                )
                Text(
                    text = if (state.isSessionUnlocked)
                        "Session unlocked — your data is protected"
                    else
                        "Session locked — unlock to access encrypted data",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (state.isEncryptionActive)
                        MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                    else
                        MaterialTheme.colorScheme.onErrorContainer.copy(alpha = 0.8f)
                )
            }
            Icon(
                imageVector = if (state.isSessionUnlocked) Icons.Outlined.CheckCircle else Icons.Filled.Lock,
                contentDescription = null,
                tint = if (state.isEncryptionActive)
                    MaterialTheme.colorScheme.onPrimaryContainer
                else
                    MaterialTheme.colorScheme.onErrorContainer
            )
        }
    }
}

// ── Change Password Section ─────────────────────────────────────────────

@Composable
private fun ChangePasswordSection(
    state: SecuritySettingsState,
    onCurrentPasswordChange: (String) -> Unit,
    onNewPasswordChange: (String) -> Unit,
    onConfirmPasswordChange: (String) -> Unit,
    onSubmit: () -> Unit
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedTextField(
                value = state.currentPassword,
                onValueChange = onCurrentPasswordChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Current Password") },
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                singleLine = true,
                shape = RoundedCornerShape(12.dp)
            )
            OutlinedTextField(
                value = state.newPassword,
                onValueChange = onNewPasswordChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("New Password") },
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                singleLine = true,
                shape = RoundedCornerShape(12.dp)
            )
            OutlinedTextField(
                value = state.confirmPassword,
                onValueChange = onConfirmPasswordChange,
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Confirm Password") },
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                isError = state.confirmPassword.isNotEmpty() && state.newPassword != state.confirmPassword
            )
            Button(
                onClick = onSubmit,
                modifier = Modifier.fillMaxWidth(),
                enabled = !state.isChangingPassword &&
                    state.newPassword.isNotBlank() &&
                    state.newPassword == state.confirmPassword,
                shape = RoundedCornerShape(12.dp)
            ) {
                if (state.isChangingPassword) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text("Save Password")
            }
        }
    }
}

// ── Passkeys Section ────────────────────────────────────────────────────

@Composable
private fun PasskeysSection(
    passkeys: List<PasskeyItem>,
    isLoading: Boolean,
    isAdding: Boolean,
    onAddPasskey: () -> Unit,
    onDeletePasskey: (PasskeyItem) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            if (isLoading) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                }
            } else if (passkeys.isEmpty()) {
                Text(
                    text = "No passkeys registered",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            } else {
                passkeys.forEachIndexed { index, passkey ->
                    if (index > 0) HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                    PasskeyRow(passkey = passkey, onDelete = { onDeletePasskey(passkey) })
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedButton(
                onClick = onAddPasskey,
                modifier = Modifier.fillMaxWidth(),
                enabled = !isAdding,
                shape = RoundedCornerShape(12.dp)
            ) {
                if (isAdding) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                } else {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text("Add Passkey")
            }
        }
    }
}

@Composable
private fun PasskeyRow(
    passkey: PasskeyItem,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.Key,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = passkey.name ?: "Unnamed Passkey",
                style = MaterialTheme.typography.bodyLarge
            )
            Text(
                text = "Created ${formatTimestamp(passkey.createdAt)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        IconButton(onClick = onDelete) {
            Icon(
                imageVector = Icons.Default.Delete,
                contentDescription = "Delete passkey",
                tint = MaterialTheme.colorScheme.error
            )
        }
    }
}

// ── Devices Section ─────────────────────────────────────────────────────

@Composable
private fun DevicesSection(
    devices: List<DeviceItem>,
    isLoading: Boolean,
    onRevokeDevice: (DeviceItem) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            if (isLoading) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                }
            } else if (devices.isEmpty()) {
                Text(
                    text = "No devices registered",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            } else {
                devices.forEachIndexed { index, device ->
                    if (index > 0) HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                    DeviceRow(device = device, onRevoke = { onRevokeDevice(device) })
                }
            }
        }
    }
}

@Composable
private fun DeviceRow(
    device: DeviceItem,
    onRevoke: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.PhoneAndroid,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = if (device.isCurrent) MaterialTheme.colorScheme.primary
                   else MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = device.name ?: device.userAgent ?: "Unknown Device",
                    style = MaterialTheme.typography.bodyLarge
                )
                if (device.isCurrent) {
                    Spacer(modifier = Modifier.width(8.dp))
                    Surface(
                        shape = RoundedCornerShape(4.dp),
                        color = MaterialTheme.colorScheme.primaryContainer
                    ) {
                        Text(
                            text = "Current",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }
            }
            Text(
                text = "Last seen ${formatTimestamp(device.lastSeen)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (!device.isCurrent) {
            IconButton(onClick = onRevoke) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "Revoke device",
                    tint = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}

// ── Session Lock Section ────────────────────────────────────────────────

@Composable
private fun SessionLockSection(onLock: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = "Locking your session clears the master encryption key from memory. " +
                    "You'll need to re-authenticate with your passkey, password, or biometrics to continue using encrypted features.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Button(
                onClick = onLock,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.error,
                    contentColor = MaterialTheme.colorScheme.onError
                )
            ) {
                Icon(
                    imageVector = Icons.Filled.Lock,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Lock Session")
            }
        }
    }
}

// ── Helpers ─────────────────────────────────────────────────────────────

@Composable
private fun SectionHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        text = title.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier.padding(vertical = 4.dp)
    )
}

private fun formatTimestamp(epochMillis: Long): String {
    return try {
        val sdf = SimpleDateFormat("MMM d, yyyy", Locale.getDefault())
        sdf.format(Date(epochMillis))
    } catch (e: Exception) {
        "Unknown"
    }
}
