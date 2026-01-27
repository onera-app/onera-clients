//
//  ModelSelectorView.swift
//  Onera
//
//  Model selection components
//

import SwiftUI

// MARK: - Model Selector Dropdown Content

public struct ModelSelectorDropdownContent: View {
    @Bindable var viewModel: ModelSelectorViewModel
    let onSelect: (ModelOption) -> Void
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading models...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if viewModel.models.isEmpty {
                // Empty state when no models configured
                VStack(spacing: 12) {
                    Image(systemName: "key.horizontal")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    
                    Text("No API Keys Configured")
                        .font(.headline)
                    
                    Text("Add your API keys in Settings → API Connections to start chatting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            } else {
                // Group models by provider
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.groupedModels, id: \.provider) { group in
                            // Provider header
                            HStack {
                                Text(group.provider.displayName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                            
                            ForEach(group.models) { model in
                                DropdownModelRow(
                                    model: model,
                                    isSelected: viewModel.selectedModel?.id == model.id,
                                    onSelect: { onSelect(model) }
                                )
                                
                                if model.id != group.models.last?.id {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Dropdown Model Row

private struct DropdownModelRow: View {
    let model: ModelOption
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text(model.provider.displayName)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy / Helper Views (Keep for compatibility if needed)

struct ModelSelectorButton: View {
    @Bindable var viewModel: ModelSelectorViewModel
    var body: some View {
        EmptyView() // Replaced by CustomNavigationBar implementation
    }
}

struct ModelSelectorView: View {
     @Bindable var viewModel: ModelSelectorViewModel
     var body: some View {
         Text("Use dropdown")
     }
}
