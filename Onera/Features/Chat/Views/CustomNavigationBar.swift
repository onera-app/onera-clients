//
//  CustomNavigationBar.swift
//  Onera
//
//  Custom navigation bar with drawer and model selector
//

import SwiftUI

struct CustomNavigationBar: View {
    
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            
            Spacer()
            
            // Center: Native model selector menu
            nativeModelSelector
            
            Spacer()
            
            // Right: New conversation button with liquid glass effect
            Button {
                onNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(height: 56)
        .background(Color.clear)
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
            HStack(spacing: 6) {
                if modelSelector.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Text(modelSelector.selectedModel?.displayName ?? "Select Model")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .menuStyle(.borderlessButton)
        .background(.clear)
    }
}
