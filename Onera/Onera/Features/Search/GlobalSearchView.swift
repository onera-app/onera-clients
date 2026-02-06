//
//  GlobalSearchView.swift
//  Onera
//
//  Global search modal for chats, notes, and prompts (Cmd+K)
//

import SwiftUI

// MARK: - Search Result

enum SearchResultType: String, CaseIterable {
    case chat
    case note
    case prompt
    
    var iconName: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .note: return "note.text"
        case .prompt: return "text.quote"
        }
    }
    
    var displayName: String {
        switch self {
        case .chat: return "Chats"
        case .note: return "Notes"
        case .prompt: return "Prompts"
        }
    }
}

struct SearchResult: Identifiable {
    let id: String
    let type: SearchResultType
    let title: String
    let subtitle: String?
    let date: Date
    let folderId: String?
    let isPinned: Bool
    
    var dateGroup: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                  date >= weekAgo {
            return "Previous 7 Days"
        } else if let monthAgo = calendar.date(byAdding: .day, value: -30, to: now),
                  date >= monthAgo {
            return "Previous 30 Days"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Global Search View

struct GlobalSearchView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    
    @State private var searchText = ""
    @State private var results: [SearchResult] = []
    @State private var selectedResultId: String?
    @State private var selectedFilter: SearchResultType? = nil
    @State private var isLoading = false
    
    @FocusState private var isSearchFocused: Bool
    
    var onSelectChat: ((String) -> Void)?
    var onSelectNote: ((String) -> Void)?
    var onSelectPrompt: ((String) -> Void)?
    
    private var filteredResults: [SearchResult] {
        if let filter = selectedFilter {
            return results.filter { $0.type == filter }
        }
        return results
    }
    
    private var groupedResults: [(String, [SearchResult])] {
        let grouped = Dictionary(grouping: filteredResults) { $0.dateGroup }
        let order = ["Today", "Yesterday", "Previous 7 Days", "Previous 30 Days"]
        
        return grouped.sorted { lhs, rhs in
            let lhsIndex = order.firstIndex(of: lhs.key) ?? Int.max
            let rhsIndex = order.firstIndex(of: rhs.key) ?? Int.max
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
            return lhs.key < rhs.key
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
            
            Divider()
            
            // Filter chips
            filterChips
            
            Divider()
            
            // Results
            if isLoading {
                loadingView
            } else if filteredResults.isEmpty {
                emptyView
            } else {
                resultsList
            }
        }
        .frame(width: 600, height: 500)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: searchText) { _, newValue in
            Task { await performSearch(query: newValue) }
        }
        .onKeyPress(.downArrow) {
            selectNextResult()
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectPreviousResult()
            return .handled
        }
        .onKeyPress(.return) {
            if let selectedId = selectedResultId,
               let result = results.first(where: { $0.id == selectedId }) {
                handleResultSelection(result)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            TextField("Search chats, notes, and prompts...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isSearchFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("esc")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding()
    }
    
    // MARK: - Filter Chips
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selectedFilter == nil,
                    action: { selectedFilter = nil }
                )
                
                ForEach(SearchResultType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        icon: type.iconName,
                        isSelected: selectedFilter == type,
                        action: { selectedFilter = type }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Results List
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            List(selection: $selectedResultId) {
                ForEach(groupedResults, id: \.0) { group, results in
                    Section(group) {
                        ForEach(results) { result in
                            SearchResultRow(result: result)
                                .tag(result.id)
                                .id(result.id)
                                .onTapGesture(count: 2) {
                                    handleResultSelection(result)
                                }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .onChange(of: selectedResultId) { _, newValue in
                if let id = newValue {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: searchText.isEmpty ? "magnifyingglass" : "magnifyingglass.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            
            if searchText.isEmpty {
                Text("Start typing to search")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("Search across chats, notes, and prompts")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No results found")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                
                Text("Try a different search term")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Searching...")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            results = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let token = try await dependencies.authService.getToken()
            var allResults: [SearchResult] = []
            
            // Search chats
            let chats = try await dependencies.chatRepository.fetchChats(token: token)
            let chatResults = chats
                .filter { $0.title.localizedCaseInsensitiveContains(query) }
                .map { chat in
                    SearchResult(
                        id: chat.id,
                        type: .chat,
                        title: chat.title,
                        subtitle: nil,
                        date: chat.updatedAt,
                        folderId: chat.folderId,
                        isPinned: false  // ChatSummary doesn't have pinned property
                    )
                }
            allResults.append(contentsOf: chatResults)
            
            // Search notes
            let notes = try await dependencies.noteRepository.fetchNotes(
                token: token,
                folderId: nil,
                archived: false
            )
            let noteResults = notes
                .filter { $0.title.localizedCaseInsensitiveContains(query) }
                .map { note in
                    SearchResult(
                        id: note.id,
                        type: .note,
                        title: note.title,
                        subtitle: nil,
                        date: note.updatedAt,
                        folderId: note.folderId,
                        isPinned: note.pinned
                    )
                }
            allResults.append(contentsOf: noteResults)
            
            // Search prompts
            let prompts = try await dependencies.promptRepository.fetchPrompts(token: token)
            let promptResults = prompts
                .filter { 
                    $0.name.localizedCaseInsensitiveContains(query) ||
                    ($0.description?.localizedCaseInsensitiveContains(query) ?? false)
                }
                .map { prompt in
                    SearchResult(
                        id: prompt.id,
                        type: .prompt,
                        title: prompt.name,
                        subtitle: prompt.description,
                        date: prompt.updatedAt,
                        folderId: nil,
                        isPinned: false
                    )
                }
            allResults.append(contentsOf: promptResults)
            
            // Sort by date
            results = allResults.sorted { $0.date > $1.date }
            
            // Select first result
            selectedResultId = results.first?.id
            
        } catch {
            print("Search error: \(error)")
        }
    }
    
    private func handleResultSelection(_ result: SearchResult) {
        dismiss()
        
        switch result.type {
        case .chat:
            onSelectChat?(result.id)
        case .note:
            onSelectNote?(result.id)
        case .prompt:
            onSelectPrompt?(result.id)
        }
    }
    
    private func selectNextResult() {
        guard !filteredResults.isEmpty else { return }
        
        if let currentId = selectedResultId,
           let currentIndex = filteredResults.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = min(currentIndex + 1, filteredResults.count - 1)
            selectedResultId = filteredResults[nextIndex].id
        } else {
            selectedResultId = filteredResults.first?.id
        }
    }
    
    private func selectPreviousResult() {
        guard !filteredResults.isEmpty else { return }
        
        if let currentId = selectedResultId,
           let currentIndex = filteredResults.firstIndex(where: { $0.id == currentId }) {
            let previousIndex = max(currentIndex - 1, 0)
            selectedResultId = filteredResults[previousIndex].id
        } else {
            selectedResultId = filteredResults.last?.id
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: result.type.iconName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(result.title)
                        .font(.body)
                        .lineLimit(1)
                    
                    if result.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Date
            Text(result.date, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    GlobalSearchView()
        .withDependencies(MockDependencyContainer())
}
#endif
