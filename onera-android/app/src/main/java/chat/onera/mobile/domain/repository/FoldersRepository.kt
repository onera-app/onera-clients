package chat.onera.mobile.domain.repository

import chat.onera.mobile.domain.model.Folder
import kotlinx.coroutines.flow.Flow

interface FoldersRepository {
    fun observeFolders(): Flow<List<Folder>>
    suspend fun getFolders(): List<Folder>
    suspend fun getFolder(folderId: String): Folder?
    suspend fun createFolder(name: String, parentId: String?): String
    suspend fun updateFolder(folder: Folder)
    suspend fun deleteFolder(folderId: String)
    suspend fun refreshFolders()
}
