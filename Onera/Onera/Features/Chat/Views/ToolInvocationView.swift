//
//  ToolInvocationView.swift
//  Onera
//
//  Displays tool/function calls and their results from AI responses
//

import SwiftUI

// MARK: - Tool State

enum ToolState: String, Codable, Sendable {
    case inputStreaming = "input-streaming"
    case inputAvailable = "input-available"
    case approvalRequested = "approval-requested"
    case approvalResponded = "approval-responded"
    case outputAvailable = "output-available"
    case outputError = "output-error"
    case outputDenied = "output-denied"
    
    var label: String {
        switch self {
        case .inputStreaming: return "Preparing..."
        case .inputAvailable: return "Running..."
        case .approvalRequested: return "Awaiting Approval"
        case .approvalResponded: return "Approved"
        case .outputAvailable: return "Completed"
        case .outputError: return "Failed"
        case .outputDenied: return "Denied"
        }
    }
    
    var iconName: String {
        switch self {
        case .inputStreaming, .inputAvailable: return "arrow.triangle.2.circlepath"
        case .approvalRequested: return "exclamationmark.circle"
        case .approvalResponded: return "checkmark.circle"
        case .outputAvailable: return "checkmark.circle.fill"
        case .outputError: return "xmark.circle.fill"
        case .outputDenied: return "xmark.circle"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .inputStreaming, .inputAvailable: return .blue
        case .approvalRequested: return .yellow
        case .approvalResponded: return .blue
        case .outputAvailable: return .green
        case .outputError: return .red
        case .outputDenied: return .orange
        }
    }
    
    func themedIconColor(_ theme: ThemeColors) -> Color {
        switch self {
        case .inputStreaming, .inputAvailable: return theme.info
        case .approvalRequested: return theme.warning
        case .approvalResponded: return theme.info
        case .outputAvailable: return theme.success
        case .outputError: return theme.error
        case .outputDenied: return theme.warning
        }
    }
    
    var isLoading: Bool {
        self == .inputStreaming || self == .inputAvailable
    }
}

// MARK: - Tool Invocation Data

struct ToolInvocationData: Identifiable, Codable, Sendable {
    let id: String
    let toolName: String
    var arguments: String?
    var result: String?
    var state: ToolState
    var errorText: String?
    
    init(
        id: String = UUID().uuidString,
        toolName: String,
        arguments: String? = nil,
        result: String? = nil,
        state: ToolState = .inputStreaming,
        errorText: String? = nil
    ) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
        self.result = result
        self.state = state
        self.errorText = errorText
    }
    
    var displayName: String {
        // Convert camelCase/snake_case to readable name
        let name = toolName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        return name.split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

// MARK: - Tool Invocation View

struct ToolInvocationView: View {
    
    let tool: ToolInvocationData
    var onApprove: ((String) -> Void)?
    var onDeny: ((String) -> Void)?
    
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    
    private var needsApproval: Bool { tool.state == .approvalRequested }
    private var hasError: Bool { tool.state == .outputError }
    private var wasDenied: Bool { tool.state == .outputDenied }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: OneraSpacing.xs) {
                    (isExpanded ? OneraIcon.chevronDown.image : OneraIcon.chevronRight.image)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    
                    OneraIcon.tool.image
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    
                    Text(tool.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                    
                    Spacer()
                    
                    // State indicator
                    HStack(spacing: OneraSpacing.xxs) {
                        if tool.state.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: tool.state.iconName)
                                .foregroundStyle(tool.state.themedIconColor(theme))
                        }
                        
                        Text(tool.state.label)
                            .font(.caption)
                            .foregroundStyle(hasError ? theme.error : theme.textSecondary)
                    }
                }
                .padding(.horizontal, OneraSpacing.md)
                .padding(.vertical, OneraSpacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, OneraSpacing.md)
                
                VStack(alignment: .leading, spacing: OneraSpacing.sm) {
                    // Arguments
                    if let args = tool.arguments, !args.isEmpty {
                        VStack(alignment: .leading, spacing: OneraSpacing.xxs) {
                            Text("Input")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(theme.textSecondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(formatJSON(args))
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(OneraSpacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .background(theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.md))
                        }
                    }
                    
                    // Result
                    if tool.state == .outputAvailable, let result = tool.result, !result.isEmpty {
                        VStack(alignment: .leading, spacing: OneraSpacing.xxs) {
                            Text("Output")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(theme.textSecondary)
                            
                            ScrollView {
                                Text(formatJSON(result))
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(OneraSpacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 150)
                            .background(theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.md))
                        }
                    }
                    
                    // Error
                    if tool.state == .outputError, let errorText = tool.errorText {
                        VStack(alignment: .leading, spacing: OneraSpacing.xxs) {
                            Text("Error")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(theme.error)
                            
                            Text(errorText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(theme.error)
                                .padding(OneraSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.error.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: OneraRadius.md))
                        }
                    }
                    
                    // Loading state
                    if tool.state.isLoading {
                        HStack(spacing: OneraSpacing.xs) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Executing tool...")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    
                    // Denied message
                    if wasDenied {
                        Text("Tool execution was denied by the user.")
                            .font(.caption)
                            .foregroundStyle(theme.warning)
                    }
                    
                    // Approval buttons
                    if needsApproval {
                        HStack {
                            Spacer()
                            
                            Button("Deny") {
                                onDeny?(tool.id)
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Allow") {
                                onApprove?(tool.id)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, OneraSpacing.sm)
                    }
                }
                .padding(OneraSpacing.md)
            }
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: OneraRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: OneraRadius.md)
                .stroke(borderColor, lineWidth: 1)
        )
        .onAppear {
            // Auto-expand if needs approval
            if needsApproval {
                isExpanded = true
            }
        }
    }
    
    private var backgroundColor: Color {
        if hasError {
            return theme.error.opacity(0.05)
        } else if wasDenied {
            return theme.warning.opacity(0.05)
        } else if needsApproval {
            return theme.warning.opacity(0.05)
        } else {
            return theme.secondaryBackground
        }
    }
    
    private var borderColor: Color {
        if hasError {
            return theme.error.opacity(0.3)
        } else if wasDenied {
            return theme.warning.opacity(0.3)
        } else if needsApproval {
            return theme.warning.opacity(0.3)
        } else {
            return theme.border
        }
    }
    
    private func formatJSON(_ string: String) -> String {
        // Try to pretty-print JSON
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let pretty = String(data: prettyData, encoding: .utf8) else {
            return string
        }
        return pretty
    }
}

// MARK: - Tool Invocations List View

struct ToolInvocationsView: View {
    
    let tools: [ToolInvocationData]
    var onApprove: ((String) -> Void)?
    var onDeny: ((String) -> Void)?
    
    var body: some View {
        if !tools.isEmpty {
            VStack(spacing: OneraSpacing.xs) {
                ForEach(tools) { tool in
                    ToolInvocationView(
                        tool: tool,
                        onApprove: onApprove,
                        onDeny: onDeny
                    )
                }
            }
            .padding(.bottom, OneraSpacing.sm)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Tool States") {
    ScrollView {
        VStack(spacing: 16) {
            ToolInvocationView(
                tool: ToolInvocationData(
                    toolName: "web_search",
                    arguments: "{\"query\": \"SwiftUI best practices\"}",
                    state: .inputStreaming
                )
            )
            
            ToolInvocationView(
                tool: ToolInvocationData(
                    toolName: "get_weather",
                    arguments: "{\"location\": \"San Francisco\"}",
                    result: "{\"temperature\": 72, \"condition\": \"sunny\"}",
                    state: .outputAvailable
                )
            )
            
            ToolInvocationView(
                tool: ToolInvocationData(
                    toolName: "execute_code",
                    arguments: "print('Hello, World!')",
                    state: .approvalRequested
                ),
                onApprove: { _ in },
                onDeny: { _ in }
            )
            
            ToolInvocationView(
                tool: ToolInvocationData(
                    toolName: "file_read",
                    arguments: "{\"path\": \"/etc/passwd\"}",
                    state: .outputError,
                    errorText: "Permission denied: Cannot access system files"
                )
            )
            
            ToolInvocationView(
                tool: ToolInvocationData(
                    toolName: "dangerous_operation",
                    arguments: "{}",
                    state: .outputDenied
                )
            )
        }
        .padding()
    }
}
#endif
