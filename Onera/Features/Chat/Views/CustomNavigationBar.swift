//
//  CustomNavigationBar.swift
//  Onera
//
//  Custom navigation bar with drawer and model selector
//

import SwiftUI

struct CustomNavigationBar: View {
    
    @Environment(\.theme) private var theme
    @Bindable var modelSelector: ModelSelectorViewModel
    let onMenuTap: () -> Void
    let onNewConversation: () -> Void
    
    @Binding var showingModelDropdown: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: Sidebar menu with liquid glass effect
            Button {
                onMenuTap()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(OneraTypography.iconLabel)
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .glassCircle()
            }
            .buttonStyle(.plain)
            .padding(.leading, OneraSpacing.lg)
            
            Spacer()
            
            // Center: Native model selector menu
            nativeModelSelector
            
            Spacer()
            
            // Right: New conversation button with liquid glass effect
            Button {
                onNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(OneraTypography.iconLabel)
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .glassCircle()
            }
            .buttonStyle(.plain)
            .padding(.trailing, OneraSpacing.lg)
        }
        .padding(.top, OneraSpacing.sm)
        .padding(.bottom, OneraSpacing.xxs)
        .frame(height: 56)
        .background(theme.background)
    }
    
    // MARK: - Native Model Selector
    
    private var nativeModelSelector: some View {
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
            HStack(spacing: OneraSpacing.xs) {
                if modelSelector.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Text(modelSelector.selectedModel?.displayName ?? "Select Model")
                    .font(OneraTypography.navTitle)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, OneraSpacing.comfortable)
            .padding(.vertical, OneraSpacing.sm)
        }
        .menuStyle(.borderlessButton)
        .background(.clear)
    }
}
