//
//  iPadSceneDelegate.swift
//  Onera
//
//  Scene delegate for iPad Stage Manager multi-window support
//

#if os(iOS)
import UIKit
import SwiftUI

// MARK: - Scene Configuration

/// Activity types for Handoff and State Restoration
enum OneraActivityType: String {
    case chat = "com.onera.chat"
    case note = "com.onera.note"
    case newChat = "com.onera.newChat"
    
    var userActivityType: String { rawValue }
}

// MARK: - Scene Delegate

final class iPadSceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        // Handle incoming user activity (Handoff, Spotlight, etc.)
        if let userActivity = connectionOptions.userActivities.first {
            handleUserActivity(userActivity, in: windowScene)
            return
        }
        
        // Handle URL contexts (deep links)
        if let urlContext = connectionOptions.urlContexts.first {
            handleURLContext(urlContext, in: windowScene)
            return
        }
        
        // Default: Create main window
        setupMainWindow(in: windowScene)
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let windowScene = scene as? UIWindowScene else { return }
        handleUserActivity(userActivity, in: windowScene)
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let windowScene = scene as? UIWindowScene,
              let urlContext = URLContexts.first else { return }
        handleURLContext(urlContext, in: windowScene)
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Clean up any resources associated with this scene
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Resume any paused tasks
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Pause ongoing tasks
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Undo changes made on entering background
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save state, release resources
    }
    
    // MARK: - State Restoration
    
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        scene.userActivity
    }
    
    // MARK: - Private Methods
    
    private func setupMainWindow(in windowScene: UIWindowScene) {
        let window = UIWindow(windowScene: windowScene)
        
        let rootView = RootView(coordinator: AppCoordinator())
            .withDependencies(DependencyContainer.shared)
            .themed()
        
        window.rootViewController = UIHostingController(rootView: rootView)
        self.window = window
        window.makeKeyAndVisible()
    }
    
    private func handleUserActivity(_ activity: NSUserActivity, in windowScene: UIWindowScene) {
        let activityType = activity.activityType
        
        switch activityType {
        case OneraActivityType.chat.userActivityType:
            if let chatId = activity.userInfo?["chatId"] as? String {
                openChatWindow(chatId: chatId, in: windowScene)
            } else {
                setupMainWindow(in: windowScene)
            }
            
        case OneraActivityType.note.userActivityType:
            if let noteId = activity.userInfo?["noteId"] as? String {
                openNoteWindow(noteId: noteId, in: windowScene)
            } else {
                setupMainWindow(in: windowScene)
            }
            
        case OneraActivityType.newChat.userActivityType:
            openNewChatWindow(in: windowScene)
            
        default:
            setupMainWindow(in: windowScene)
        }
    }
    
    private func handleURLContext(_ urlContext: UIOpenURLContext, in windowScene: UIWindowScene) {
        let url = urlContext.url
        
        // Handle onera:// deep links
        guard url.scheme == "onera" else {
            setupMainWindow(in: windowScene)
            return
        }
        
        switch url.host {
        case "chat":
            if let chatId = url.pathComponents.dropFirst().first {
                openChatWindow(chatId: chatId, in: windowScene)
            } else {
                openNewChatWindow(in: windowScene)
            }
            
        case "note":
            if let noteId = url.pathComponents.dropFirst().first {
                openNoteWindow(noteId: noteId, in: windowScene)
            } else {
                setupMainWindow(in: windowScene)
            }
            
        default:
            setupMainWindow(in: windowScene)
        }
    }
    
    private func openChatWindow(chatId: String, in windowScene: UIWindowScene) {
        let window = UIWindow(windowScene: windowScene)
        
        let chatView = DetachedChatWindowView(chatId: chatId)
            .withDependencies(DependencyContainer.shared)
            .themed()
        
        window.rootViewController = UIHostingController(rootView: chatView)
        self.window = window
        window.makeKeyAndVisible()
        
        // Set user activity for state restoration
        let activity = NSUserActivity(activityType: OneraActivityType.chat.userActivityType)
        activity.userInfo = ["chatId": chatId]
        activity.isEligibleForHandoff = true
        windowScene.userActivity = activity
    }
    
    private func openNoteWindow(noteId: String, in windowScene: UIWindowScene) {
        let window = UIWindow(windowScene: windowScene)
        
        let noteView = DetachedNoteWindowView(noteId: noteId)
            .withDependencies(DependencyContainer.shared)
            .themed()
        
        window.rootViewController = UIHostingController(rootView: noteView)
        self.window = window
        window.makeKeyAndVisible()
        
        // Set user activity for state restoration
        let activity = NSUserActivity(activityType: OneraActivityType.note.userActivityType)
        activity.userInfo = ["noteId": noteId]
        activity.isEligibleForHandoff = true
        windowScene.userActivity = activity
    }
    
    private func openNewChatWindow(in windowScene: UIWindowScene) {
        let window = UIWindow(windowScene: windowScene)
        
        let chatView = DetachedChatWindowView(chatId: nil)
            .withDependencies(DependencyContainer.shared)
            .themed()
        
        window.rootViewController = UIHostingController(rootView: chatView)
        self.window = window
        window.makeKeyAndVisible()
    }
}

// MARK: - Detached Chat Window View

struct DetachedChatWindowView: View {
    let chatId: String?
    
    @Environment(\.dependencies) private var dependencies
    @State private var chatViewModel: ChatViewModel?
    
    var body: some View {
        Group {
            if let viewModel = chatViewModel {
                NavigationStack {
                    ChatView(
                        viewModel: viewModel
                    )
                    .navigationTitle(viewModel.chat?.title ?? "Chat")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                Task {
                                    await viewModel.createNewChat()
                                }
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                        }
                    }
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            setupViewModel()
            if let id = chatId {
                await chatViewModel?.loadChat(id: id)
            } else {
                await chatViewModel?.createNewChat()
            }
        }
    }
    
    private func setupViewModel() {
        chatViewModel = ChatViewModel(
            authService: dependencies.authService,
            chatRepository: dependencies.chatRepository,
            credentialService: dependencies.credentialService,
            llmService: dependencies.llmService,
            networkService: dependencies.networkService,
            speechService: dependencies.speechService,
            speechRecognitionService: dependencies.speechRecognitionService,
            onChatUpdated: { _ in }
        )
    }
}

// MARK: - Detached Note Window View

struct DetachedNoteWindowView: View {
    let noteId: String
    
    @Environment(\.dependencies) private var dependencies
    @State private var notesViewModel: NotesViewModel?
    @State private var note: Note?
    
    var body: some View {
        Group {
            if let viewModel = notesViewModel {
                NavigationStack {
                    NoteEditorView(
                        viewModel: viewModel,
                        folderViewModel: nil
                    )
                    .navigationTitle(viewModel.editingNote?.title ?? "Note")
                    .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            setupViewModel()
            await loadNote()
        }
    }
    
    private func setupViewModel() {
        notesViewModel = NotesViewModel(
            noteRepository: dependencies.noteRepository,
            authService: dependencies.authService
        )
    }
    
    private func loadNote() async {
        // Note loading would happen here
    }
}

// MARK: - Scene Request Helpers

extension UIApplication {
    /// Request a new window for a specific chat
    @MainActor
    static func openChatInNewWindow(chatId: String) {
        let activity = NSUserActivity(activityType: OneraActivityType.chat.userActivityType)
        activity.userInfo = ["chatId": chatId]
        
        let options = UIScene.ActivationRequestOptions()
        options.requestingScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        
        UIApplication.shared.requestSceneSessionActivation(
            nil,
            userActivity: activity,
            options: options,
            errorHandler: { error in
                print("[iPadSceneDelegate] Failed to open new window: \(error)")
            }
        )
    }
    
    /// Request a new window for a new chat
    @MainActor
    static func openNewChatWindow() {
        let activity = NSUserActivity(activityType: OneraActivityType.newChat.userActivityType)
        
        let options = UIScene.ActivationRequestOptions()
        options.requestingScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        
        UIApplication.shared.requestSceneSessionActivation(
            nil,
            userActivity: activity,
            options: options,
            errorHandler: { error in
                print("[iPadSceneDelegate] Failed to open new window: \(error)")
            }
        )
    }
    
    /// Request a new window for a note
    @MainActor
    static func openNoteInNewWindow(noteId: String) {
        let activity = NSUserActivity(activityType: OneraActivityType.note.userActivityType)
        activity.userInfo = ["noteId": noteId]
        
        let options = UIScene.ActivationRequestOptions()
        options.requestingScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        
        UIApplication.shared.requestSceneSessionActivation(
            nil,
            userActivity: activity,
            options: options,
            errorHandler: { error in
                print("[iPadSceneDelegate] Failed to open new window: \(error)")
            }
        )
    }
}

#endif // os(iOS)
