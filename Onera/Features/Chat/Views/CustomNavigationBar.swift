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
            // Left: Sidebar menu
            Button {
                onMenuTap()
            } label: {
                Image(systemName: "text.rectangle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .padding(.leading, 8)
            
            // Center-left: Model selector dropdown
            modelSelectorButton
            
            Spacer()
            
            // Right: New conversation button
            Button {
                onNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }
            .padding(.trailing, 16)
        }
        .padding(.top, 4)
        .frame(height: 50)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Model Selector Button
    
    private var modelSelectorButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingModelDropdown.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                if modelSelector.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 4)
                }
                
                Text(modelSelector.selectedModel?.displayName ?? "Select Model")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showingModelDropdown ? -180 : 0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
