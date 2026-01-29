---
name: swift-mvvm
description: SwiftUI MVVM patterns with @Observable
---

# SwiftUI MVVM with @Observable

## ViewModel Template

```swift
import Foundation
import Observation

@MainActor
@Observable
final class FeatureViewModel {
    // MARK: - State (read-only from View)
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    // MARK: - Input (writable from View)
    var searchText = ""
    
    // MARK: - Computed
    var filteredItems: [Item] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var hasItems: Bool { !items.isEmpty }
    var canRefresh: Bool { !isLoading }
    
    // MARK: - Dependencies
    private let service: ServiceProtocol
    
    init(service: ServiceProtocol) {
        self.service = service
    }
    
    // MARK: - Actions
    func loadItems() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            items = try await service.fetchItems()
            error = nil
        } catch {
            self.error = error
        }
    }
    
    func deleteItem(_ item: Item) async {
        do {
            try await service.delete(item)
            items.removeAll { $0.id == item.id }
        } catch {
            self.error = error
        }
    }
    
    func clearError() {
        error = nil
    }
}
```

## View Template

```swift
struct FeatureView: View {
    @State private var viewModel: FeatureViewModel
    
    init(service: ServiceProtocol) {
        _viewModel = State(initialValue: FeatureViewModel(service: service))
    }
    
    var body: some View {
        content
            .task { await viewModel.loadItems() }
            .refreshable { await viewModel.loadItems() }
            .alert("Error", isPresented: hasError) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "Unknown error")
            }
    }
    
    private var hasError: Binding<Bool> {
        Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasItems {
            ProgressView()
        } else if viewModel.hasItems {
            itemList
        } else {
            emptyState
        }
    }
    
    private var itemList: some View {
        List(viewModel.filteredItems) { item in
            ItemRow(item: item)
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteItem(item) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
        .searchable(text: $viewModel.searchText)
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No Items",
            systemImage: "tray",
            description: Text("Add your first item to get started.")
        )
    }
}
```

## Service Protocol

```swift
protocol ServiceProtocol {
    func fetchItems() async throws -> [Item]
    func delete(_ item: Item) async throws
    func create(_ item: Item) async throws -> Item
    func update(_ item: Item) async throws -> Item
}

// Implementation
final class Service: ServiceProtocol {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func fetchItems() async throws -> [Item] {
        try await apiClient.request(.getItems)
    }
    
    func delete(_ item: Item) async throws {
        try await apiClient.request(.deleteItem(item.id))
    }
}
```

## Dependency Container

```swift
@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()
    
    private init() {}
    
    // Services
    lazy var authService: AuthServiceProtocol = AuthService()
    lazy var chatService: ChatServiceProtocol = ChatService(apiClient: apiClient)
    
    // Shared clients
    private lazy var apiClient: APIClient = APIClient(baseURL: Configuration.apiURL)
    
    // ViewModel factories
    func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(chatService: chatService)
    }
}
```

## State Patterns

### Loading State
```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
}

@Observable
final class ViewModel {
    private(set) var state: LoadingState<[Item]> = .idle
    
    var items: [Item] {
        if case .loaded(let items) = state { return items }
        return []
    }
    
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }
}
```

### Sending State (Prevent Race Conditions)
```swift
func sendMessage() async {
    guard canSend, !isSending else { return }
    
    // Set IMMEDIATELY before async work
    isSending = true
    defer { isSending = false }
    
    do {
        // async work
    } catch {
        self.error = error
    }
}
```

## Testing

```swift
@MainActor
final class FeatureViewModelTests: XCTestCase {
    var sut: FeatureViewModel!
    var mockService: MockService!
    
    override func setUp() {
        mockService = MockService()
        sut = FeatureViewModel(service: mockService)
    }
    
    func testLoadItems_Success() async {
        // Arrange
        let expectedItems = [Item.mock()]
        mockService.fetchItemsResult = .success(expectedItems)
        
        // Act
        await sut.loadItems()
        
        // Assert
        XCTAssertEqual(sut.items, expectedItems)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testLoadItems_Error() async {
        // Arrange
        mockService.fetchItemsResult = .failure(TestError.network)
        
        // Act
        await sut.loadItems()
        
        // Assert
        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertNotNil(sut.error)
    }
}
```
