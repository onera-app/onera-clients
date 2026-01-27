---
name: Fix Data Loading Bugs
overview: Fix race condition causing model selection to show empty on app start, and ensure chats/notes are properly synced to the server after E2EE unlock.
todos:
  - id: fix-race-condition
    content: Fix refreshCredentials() to await completion before loadModels()
    status: completed
  - id: chat-pending-sync
    content: Add pending sync queue for chats created before E2EE unlock
    status: completed
  - id: notes-pending-sync
    content: Add pending sync queue for notes created before E2EE unlock
    status: completed
  - id: trigger-pending-sync
    content: Call syncPendingChats/Notes in onE2EEUnlocked handler
    status: completed
---

# Fix Data Loading and Server Sync Bugs

## Issues Identified

### Issue 1: Model Selection Shows Empty on App Start (Race Condition)

**Root Cause**: In [MainViewModel.kt](app/src/main/java/chat/onera/mobile/presentation/features/main/MainViewModel.kt), the `loadInitialData()` function calls `refreshCredentials()` and then `loadModels()`. However, `refreshCredentials()` launches a separate coroutine and returns immediately:

```kotlin
private fun refreshCredentials() {
    viewModelScope.launch {  // <-- New coroutine, returns immediately
        credentialRepository.refreshCredentials()
    }
}
```

This means `loadModels()` runs before credentials are fetched, so `credentialRepository.getCredentials()` returns an empty list.

**Why it works after visiting Settings**: Going to SettingsViewModel triggers another `credentialRepository.refreshCredentials()`, and when you return, the credentials are already populated in the StateFlow.

### Issue 2: Chats Not Saving to Server

**Root Cause**: The `syncNewChatToServer()` function checks E2EE status and exits silently if not unlocked:

```kotlin
if (!e2eeRepository.isSessionUnlocked()) {
    Log.d(TAG, "E2EE session locked, skipping server sync")
    return  // <-- Chat never synced!
}
```

When a new chat is created before E2EE is fully initialized, it's saved locally but never synced to the server. There's no retry mechanism.

### Issue 3: Notes Not Saving/Retrieving

**Same Root Cause**: Notes operations also depend on E2EE being unlocked. If E2EE isn't ready, operations fail silently or are skipped.

## Solution

### Fix 1: Make Credential Refresh Await Completion

Change `refreshCredentials()` to properly await before loading models:

```kotlin
private fun loadInitialData() {
    viewModelScope.launch {
        try {
            val user = authRepository.getCurrentUser()
            updateState { copy(currentUser = user) }
            refreshChats()
            // Wait for credentials to be fetched before loading models
            credentialRepository.refreshCredentials()  // <-- Direct call, await
            loadModels()  // <-- Now has credentials
        } catch (e: Exception) {
            sendEffect(MainEffect.ShowError(e.message ?: "Failed to load data"))
        }
    }
}

// Remove the separate coroutine launch
private suspend fun refreshCredentials() {
    try {
        credentialRepository.refreshCredentials()
    } catch (e: Exception) {
        android.util.Log.w("MainViewModel", "Failed to refresh credentials", e)
    }
}
```

### Fix 2: Add Pending Sync Queue for Chats/Notes

Add a mechanism to track items that need syncing and retry when E2EE becomes available.

**In [ChatRepositoryImpl.kt](app/src/main/java/chat/onera/mobile/data/repository/ChatRepositoryImpl.kt)**:

- Add `pendingSyncChats` set to track chats that failed to sync
- In `onE2EEUnlocked`, sync all pending chats
- Modify `createChat()` to add to pending sync if E2EE locked

**In [NotesRepositoryImpl.kt](app/src/main/java/chat/onera/mobile/data/repository/NotesRepositoryImpl.kt)**:

- Same pattern for pending notes

### Fix 3: Trigger Data Refresh After E2EE Unlock

The `onE2EEUnlocked()` handler already refreshes data, but we need to also sync any pending local data:

```kotlin
private fun onE2EEUnlocked() {
    viewModelScope.launch {
        try {
            refreshChats()
            chatRepository.syncPendingChats()  // <-- NEW: Sync local-only chats
            refreshCredentials()
            loadModels()
            notesRepository.syncPendingNotes()  // <-- NEW: Sync local-only notes
        } catch (e: Exception) {
            Log.e("MainViewModel", "Failed to refresh after E2EE unlock", e)
        }
    }
}
```

## Files to Modify

1. **[MainViewModel.kt](app/src/main/java/chat/onera/mobile/presentation/features/main/MainViewModel.kt)**

   - Change `refreshCredentials()` from fire-and-forget to suspend function
   - Ensure `loadModels()` waits for credentials

2. **[ChatRepositoryImpl.kt](app/src/main/java/chat/onera/mobile/data/repository/ChatRepositoryImpl.kt)**

   - Add pending sync tracking
   - Add `syncPendingChats()` function

3. **[ChatRepository.kt](app/src/main/java/chat/onera/mobile/domain/repository/ChatRepository.kt)**

   - Add `syncPendingChats()` to interface

4. **[NotesRepositoryImpl.kt](app/src/main/java/chat/onera/mobile/data/repository/NotesRepositoryImpl.kt)**

   - Add pending sync tracking
   - Add `syncPendingNotes()` function

5. **[NotesRepository.kt](app/src/main/java/chat/onera/mobile/domain/repository/NotesRepository.kt)**

   - Add `syncPendingNotes()` to interface