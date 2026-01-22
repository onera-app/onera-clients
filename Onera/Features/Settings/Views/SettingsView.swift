//
//  SettingsView.swift
//  Onera
//
//  App settings and account management
//

import SwiftUI

struct SettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettingsViewModel
    @AppStorage("colorScheme") private var selectedColorScheme = 0
    
    private var preferredScheme: ColorScheme? {
        switch selectedColorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                profileHeaderSection
                accountSection
                securitySection
                appSection
                aboutSection
                logOutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(OneraTypography.iconLabel)
                            .foregroundStyle(OneraColors.textPrimary)
                            .frame(width: 30, height: 30)
                            .background(OneraColors.secondaryBackground)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $viewModel.showRecoveryPhrase) {
                RecoveryPhraseDisplayView(
                    viewModel: viewModel,
                    onDismiss: { viewModel.clearRecoveryPhrase() }
                )
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $viewModel.showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await viewModel.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out? Make sure you have your recovery phrase saved.")
            }
        }
        .preferredColorScheme(preferredScheme)
        .onAppear {
            viewModel.loadSettings()
        }
    }
    
    // MARK: - Profile Header Section
    
    private var profileHeaderSection: some View {
        Section {
            VStack(spacing: OneraSpacing.lg) {
                // Large Avatar
                if let user = viewModel.user {
                    ZStack {
                        if let imageURL = user.imageURL {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                OneraColors.Gray.gray4
                            }
                        } else {
                            OneraColors.Gray.gray4
                            Text(user.initials)
                                .font(OneraTypography.displayLarge)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    
                    // Display Name
                    Text(user.displayName)
                        .font(OneraTypography.title2.bold())
                    
                    // Username/Email
                    Text(user.email)
                        .font(OneraTypography.subheadline)
                        .foregroundStyle(OneraColors.textSecondary)
                    
                    // Edit Profile Button
                    Button {
                        // Edit profile action
                    } label: {
                        Text("Edit profile")
                            .font(OneraTypography.subheadline)
                            .padding(.horizontal, OneraSpacing.xl)
                            .padding(.vertical, OneraSpacing.sm)
                            .background(OneraColors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.bubble))
                    }
                    .buttonStyle(.plain)
                } else {
                    // No user state
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(OneraColors.textSecondary)
                    
                    Text("Not signed in")
                        .font(OneraTypography.title2.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, OneraSpacing.lg)
        }
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section("Account") {
            if let user = viewModel.user {
                HStack {
                    Label("Email", systemImage: "envelope")
                    Spacer()
                    Text(user.email)
                        .foregroundStyle(OneraColors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Security Section
    
    private var securitySection: some View {
        Section("Security") {
            HStack {
                Label("End-to-End Encryption", systemImage: "lock.shield.fill")
                Spacer()
                Text(viewModel.isSessionUnlocked ? "Active" : "Locked")
                    .foregroundStyle(viewModel.isSessionUnlocked ? OneraColors.success : OneraColors.warning)
            }
            
            Button {
                viewModel.showRecoveryPhrase = true
            } label: {
                HStack {
                    Label("View Recovery Phrase", systemImage: "key.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(OneraTypography.caption)
                        .foregroundStyle(OneraColors.textSecondary)
                }
            }
            .disabled(!viewModel.isSessionUnlocked)
            .accessibilityIdentifier("recoveryPhraseButton")
            
            if viewModel.isSessionUnlocked {
                Button {
                    Task { await viewModel.lockSession() }
                } label: {
                    HStack {
                        Label("Lock Session", systemImage: "lock.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(OneraTypography.caption)
                            .foregroundStyle(OneraColors.textSecondary)
                    }
                }
            }
            
            NavigationLink {
                DeviceManagementView()
            } label: {
                Label("Manage Devices", systemImage: "laptopcomputer.and.iphone")
            }
            
            NavigationLink {
                CredentialsListView(viewModel: viewModel.credentialsViewModel)
            } label: {
                Label("API Connections", systemImage: "key.horizontal")
            }
        }
    }
    
    // MARK: - App Section
    
    private var appSection: some View {
        Section("App") {
            Picker(selection: $selectedColorScheme) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            } label: {
                Label("Appearance", systemImage: "sun.max")
            }
            .accessibilityIdentifier("themeSelector")
            
            Link(destination: URL(string: "https://onera.app/privacy")!) {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(OneraTypography.caption)
                        .foregroundStyle(OneraColors.textSecondary)
                }
            }
            
            Link(destination: URL(string: "https://onera.app/terms")!) {
                HStack {
                    Label("Terms of Service", systemImage: "doc.text")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(OneraTypography.caption)
                        .foregroundStyle(OneraColors.textSecondary)
                }
            }
        }
    }
    
    private var appearanceText: String {
        switch selectedColorScheme {
        case 1: return "Light"
        case 2: return "Dark"
        default: return "System"
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section("About") {
            Link(destination: URL(string: "https://onera.app/help")!) {
                HStack {
                    Label("Help Center", systemImage: "questionmark.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(OneraTypography.caption)
                        .foregroundStyle(OneraColors.textSecondary)
                }
            }
            
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.fullVersionString)
                    .foregroundStyle(OneraColors.textSecondary)
            }
        }
    }
    
    // MARK: - Log Out Section
    
    private var logOutSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showSignOutConfirmation = true
            } label: {
                HStack {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    Spacer()
                }
            }
            .accessibilityIdentifier("signOutButton")
        }
    }
}

// MARK: - Recovery Phrase Display

struct RecoveryPhraseDisplayView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettingsViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingRecoveryPhrase {
                    ProgressView("Decrypting...")
                } else if let phrase = viewModel.recoveryPhrase {
                    phraseView(phrase)
                } else if let error = viewModel.error {
                    errorView(error)
                } else {
                    Color.clear
                }
            }
            .navigationTitle("Recovery Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadRecoveryPhrase()
        }
    }
    
    private func phraseView(_ phrase: String) -> some View {
        ScrollView {
            VStack(spacing: OneraSpacing.xxl) {
                Text("Your Recovery Phrase")
                    .font(OneraTypography.title2.bold())
                
                RecoveryPhraseGrid(phrase: phrase)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: OneraRadius.large))
                
                Button {
                    UIPasteboard.general.string = phrase
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Text("Keep this phrase secure. Never share it with anyone.")
                    .font(OneraTypography.caption)
                    .foregroundStyle(OneraColors.textSecondary)
            }
            .padding()
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView(
            "Unable to Load",
            systemImage: "exclamationmark.triangle",
            description: Text(error.localizedDescription)
        )
    }
}

// MARK: - Device Management

struct DeviceManagementView: View {
    var body: some View {
        List {
            Section("Current Device") {
                HStack {
                    Image(systemName: "iphone")
                        .font(OneraTypography.title2)
                    
                    VStack(alignment: .leading) {
                        Text(UIDevice.current.name)
                            .font(OneraTypography.headline)
                        Text("This device")
                            .font(OneraTypography.caption)
                            .foregroundStyle(OneraColors.textSecondary)
                    }
                }
            }
            
            Section("Other Devices") {
                Text("No other devices")
                    .foregroundStyle(OneraColors.textSecondary)
            }
        }
        .navigationTitle("Devices")
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    
    @AppStorage("colorScheme") private var colorScheme = 0
    
    var body: some View {
        List {
            Picker("Theme", selection: $colorScheme) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
        }
        .navigationTitle("Appearance")
    }
}

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            authService: MockAuthService(),
            e2eeService: MockE2EEService(),
            secureSession: MockSecureSession(),
            credentialService: MockCredentialService(),
            networkService: MockNetworkService(),
            cryptoService: CryptoService(),
            onSignOut: {}
        )
    )
}
