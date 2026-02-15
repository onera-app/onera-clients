//
//  CustomNavigationBar.swift
//  Onera
//
//  Custom navigation bar with drawer and model selector
//  ChatGPT-style minimal header
//

import SwiftUI

struct CustomNavigationBar: View {
    
    @Environment(\.theme) private var theme
    @Bindable var modelSelector: ModelSelectorViewModel
    let onMenuTap: () -> Void
    let onNewConversation: () -> Void
    
    @State private var menuTapTrigger = false
    @State private var newConversationTrigger = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: Sidebar toggle - minimal icon button
            Button {
                menuTapTrigger.toggle()
                onMenuTap()
            } label: {
                Image(systemName: "sidebar.left")
                    .font(OneraTypography.iconXLarge)
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: menuTapTrigger)
            .padding(.leading, OneraSpacing.md)
            .accessibilityLabel("Toggle sidebar")
            .accessibilityHint("Shows or hides chat history")
            
            Spacer()
            
            // Center: Model selector - ChatGPT style
            modelSelector_chatGPTStyle
            
            Spacer()
            
            // Right: New chat - minimal icon button
            Button {
                newConversationTrigger.toggle()
                onNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(OneraTypography.iconXLarge)
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: AccessibilitySize.minTouchTarget, height: AccessibilitySize.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .medium), trigger: newConversationTrigger)
            .padding(.trailing, OneraSpacing.md)
            .accessibilityLabel("New conversation")
            .accessibilityHint("Starts a new chat")
        }
        .frame(height: 52)
        .background(
            theme.background
                .ignoresSafeArea(edges: .top)
        )
    }
    
    // MARK: - ChatGPT-style Model Selector
    
    private var modelSelector_chatGPTStyle: some View {
        Menu {
            if modelSelector.isLoading {
                Text("Loading models...")
            } else if modelSelector.groupedModels.isEmpty {
                Text("No models available")
                Text("Add API keys in Settings")
            } else {
                ForEach(modelSelector.groupedModels, id: \.provider) { group in
                    Section(group.provider.displayName) {
                        ForEach(group.models) { model in
                            Button {
                                modelSelector.selectedModel = model
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                    if modelSelector.selectedModel?.id == model.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if modelSelector.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .accessibilityLabel("Loading models")
                } else {
                    Text(modelSelector.selectedModel?.displayName ?? "Select Model")
                        .font(OneraTypography.navTitle)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    
                    Image(systemName: "chevron.down")
                        .font(OneraTypography.buttonSmall)
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, OneraSpacing.md)
            .padding(.vertical, OneraSpacing.sm)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Select AI model")
        .accessibilityValue(modelSelector.selectedModel?.displayName ?? "No model selected")
        .accessibilityHint("Opens menu to choose a different AI model")
    }
}

