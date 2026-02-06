//
//  SettingsView.swift
//  Onera
//
//  App settings and account management
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Bindable var viewModel: SettingsViewModel
    @AppStorage("colorScheme") private var selectedColorScheme = 0
    
    /// Theme manager for switching themes
    private var themeManager: ThemeManager { ThemeManager.shared }
    
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
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                #endif
            }
            .sheet(isPresented: $viewModel.showRecoveryPhrase) {
                RecoveryPhraseDisplayView(
                    viewModel: viewModel,
                    onDismiss: { viewModel.clearRecoveryPhrase() }
                )
            }
            .onAppear {
                viewModel.loadSettings()
            }
        }
        .preferredColorScheme(preferredScheme)
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
                                theme.secondaryBackground
                            }
                        } else {
                            theme.secondaryBackground
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
                        .foregroundStyle(theme.textSecondary)
                    
                    // Edit Profile Button
                    Button {
                        // Edit profile action
                    } label: {
                        Text("Edit profile")
                            .font(OneraTypography.subheadline)
                            .padding(.horizontal, OneraSpacing.xl)
                            .padding(.vertical, OneraSpacing.sm)
                            .background(theme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: OneraRadius.bubble))
                    }
                    .buttonStyle(.plain)
                } else {
                    // No user state
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(theme.textSecondary)
                    
                    Text("Not signed in")
                        .font(OneraTypography.title2.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, OneraSpacing.lg)
        }
        .listRowBackground(Color.clear as Color)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section("Account") {
            if let user = viewModel.user {
                HStack {
                    Label("Email", systemImage: "envelope")
                    Spacer()
                    Text(user.email)
                        .foregroundStyle(theme.textSecondary)
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
                    .foregroundStyle(viewModel.isSessionUnlocked ? theme.success : theme.warning)
            }
            
            Button {
                viewModel.showRecoveryPhrase = true
            } label: {
                HStack {
                    Label("View Recovery Phrase", systemImage: "key.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(OneraTypography.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .disabled(!viewModel.isSessionUnlocked)
            .accessibilityIdentifier("recoveryPhraseButton")
            
            if viewModel.isSessionUnlocked {
                Button {
                    viewModel.lockSession()
                } label: {
                    HStack {
                        Label("Lock Session", systemImage: "lock.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(OneraTypography.caption)
                            .foregroundStyle(theme.textSecondary)
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
            NavigationLink {
                GeneralSettingsView()
            } label: {
                Label("General", systemImage: "slider.horizontal.3")
            }
            
            NavigationLink {
                DataSettingsView()
            } label: {
                Label("Data", systemImage: "externaldrive")
            }
            
            NavigationLink {
                ToolsSettingsView()
            } label: {
                Label("Tools", systemImage: "wrench.and.screwdriver")
            }
            
            #if os(iOS)
            if DemoModeManager.shared.isActive {
                WatchSyncButton()
            }
            #endif
            
            // Theme selection
            Picker(selection: Binding(
                get: { themeManager.currentTheme },
                set: { themeManager.currentTheme = $0 }
            )) {
                ForEach(AppTheme.allCases) { appTheme in
                    HStack {
                        Text(appTheme.displayName)
                        if appTheme == .claude {
                            Text("New")
                                .font(OneraTypography.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.851, green: 0.467, blue: 0.341)) // Claude Coral #D97757
                                .clipShape(Capsule())
                        }
                    }
                    .tag(appTheme)
                }
            } label: {
                Label("Theme", systemImage: "paintbrush")
            }
            .accessibilityIdentifier("themePicker")
            
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
                        .foregroundStyle(theme.textSecondary)
                }
            }
            
            Link(destination: URL(string: "https://onera.app/terms")!) {
                HStack {
                    Label("Terms of Service", systemImage: "doc.text")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(OneraTypography.caption)
                        .foregroundStyle(theme.textSecondary)
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
                        .foregroundStyle(theme.textSecondary)
                }
            }
            
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.fullVersionString)
                    .foregroundStyle(theme.textSecondary)
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
        } footer: {
            Text("You'll need your recovery phrase to access your encrypted data on this device again.")
                .font(OneraTypography.caption)
        }
    }
}

// MARK: - Recovery Phrase Display

struct RecoveryPhraseDisplayView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                    #if os(iOS)
                    UIPasteboard.general.string = phrase
                    #elseif os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(phrase, forType: .string)
                    #endif
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Text("Keep this phrase secure. Never share it with anyone.")
                    .font(OneraTypography.caption)
                    .foregroundStyle(theme.textSecondary)
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
    @Environment(\.theme) private var theme
    @Environment(\.dependencies) private var dependencies
    
    @State private var devices: [DecryptedDevice] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var deviceToRevoke: DecryptedDevice?
    @State private var showRevokeConfirmation = false
    
    private var currentDeviceId: String? {
        try? KeychainService().getOrCreateDeviceId()
    }
    
    private var currentDevice: DecryptedDevice? {
        devices.first { $0.deviceId == currentDeviceId }
    }
    
    private var otherDevices: [DecryptedDevice] {
        devices.filter { $0.deviceId != currentDeviceId }
    }
    
    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }
            } else if let error = error {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text("Failed to load devices")
                            .font(OneraTypography.headline)
                        Text(error.localizedDescription)
                            .font(OneraTypography.caption)
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadDevices() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                // Current Device Section
                if let current = currentDevice {
                    Section("Current Device") {
                        DeviceRow(device: current, isCurrentDevice: true)
                    }
                }
                
                // Other Devices Section
                Section("Other Devices") {
                    if otherDevices.isEmpty {
                        Text("No other devices")
                            .foregroundStyle(theme.textSecondary)
                    } else {
                        ForEach(otherDevices) { device in
                            DeviceRow(device: device, isCurrentDevice: false)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deviceToRevoke = device
                                        showRevokeConfirmation = true
                                    } label: {
                                        Label("Revoke", systemImage: "xmark.circle")
                                    }
                                }
                        }
                    }
                }
                
                // Info Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("End-to-End Encrypted")
                                .font(OneraTypography.subheadline)
                            Text("Device names are encrypted and only visible to you")
                                .font(OneraTypography.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                } footer: {
                    Text("Revoking a device will sign it out and require re-authentication to access your encrypted data.")
                        .font(OneraTypography.caption)
                }
            }
        }
        .navigationTitle("Devices")
        .refreshable {
            await loadDevices()
        }
        .task {
            await loadDevices()
        }
        .confirmationDialog(
            "Revoke Device",
            isPresented: $showRevokeConfirmation,
            titleVisibility: .visible,
            presenting: deviceToRevoke
        ) { device in
            Button("Revoke \(device.deviceName ?? "Device")", role: .destructive) {
                Task { await revokeDevice(device) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { device in
            Text("This will sign out \"\(device.deviceName ?? "this device")\" and require re-authentication to access your encrypted data.")
        }
    }
    
    private func loadDevices() async {
        isLoading = true
        error = nil
        
        do {
            let token = try await dependencies.authService.getToken()
            let response: [DeviceResponse] = try await dependencies.networkService.call(
                procedure: APIEndpoint.Devices.list,
                token: token
            )
            
            // Decrypt device names
            devices = response.compactMap { deviceResponse in
                var deviceName: String? = nil
                
                if let _ = deviceResponse.encryptedDeviceName,
                   let _ = deviceResponse.deviceNameNonce {
                    // TODO: Decrypt using E2EE service when master key is available
                    // For now, use a placeholder or attempt decryption
                    deviceName = "Encrypted Device" // Placeholder until decryption is wired up
                }
                
                return DecryptedDevice(
                    id: deviceResponse.id,
                    deviceId: deviceResponse.deviceId,
                    deviceName: deviceName ?? parseDeviceNameFromUserAgent(deviceResponse.userAgent),
                    userAgent: deviceResponse.userAgent,
                    trusted: deviceResponse.trusted,
                    lastSeenAt: deviceResponse.lastSeenAt,
                    createdAt: deviceResponse.createdAt
                )
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func revokeDevice(_ device: DecryptedDevice) async {
        do {
            let token = try await dependencies.authService.getToken()
            let _: EmptyResponse = try await dependencies.networkService.call(
                procedure: APIEndpoint.Devices.revoke,
                input: RevokeDeviceRequest(deviceId: device.deviceId),
                token: token
            )
            
            // Remove from local list
            devices.removeAll { $0.id == device.id }
        } catch {
            print("Failed to revoke device: \(error)")
        }
    }
    
    private func parseDeviceNameFromUserAgent(_ userAgent: String?) -> String {
        guard let ua = userAgent else { return "Unknown Device" }
        
        if ua.contains("iOS") {
            return "iPhone"
        } else if ua.contains("macOS") {
            return "Mac"
        } else if ua.contains("Android") {
            return "Android Device"
        } else if ua.contains("Windows") {
            return "Windows PC"
        }
        return "Unknown Device"
    }
}

// MARK: - Device Models

private struct DeviceResponse: Codable {
    let id: String
    let userId: String
    let deviceId: String
    let encryptedDeviceName: String?
    let deviceNameNonce: String?
    let userAgent: String?
    let trusted: Bool
    let lastSeenAt: Date
    let createdAt: Date
}

private struct DecryptedDevice: Identifiable {
    let id: String
    let deviceId: String
    let deviceName: String?
    let userAgent: String?
    let trusted: Bool
    let lastSeenAt: Date
    let createdAt: Date
}

private struct RevokeDeviceRequest: Codable {
    let deviceId: String
}

private struct EmptyResponse: Codable {}

// MARK: - Device Row

private struct DeviceRow: View {
    let device: DecryptedDevice
    let isCurrentDevice: Bool
    
    @Environment(\.theme) private var theme
    
    private var deviceIcon: String {
        guard let ua = device.userAgent else { return "desktopcomputer" }
        
        if ua.contains("iOS") || ua.contains("iPhone") {
            return "iphone"
        } else if ua.contains("iPad") {
            return "ipad"
        } else if ua.contains("macOS") || ua.contains("Mac") {
            return "laptopcomputer"
        } else if ua.contains("Android") {
            return "candybarphone"
        } else if ua.contains("Windows") {
            return "pc"
        }
        return "desktopcomputer"
    }
    
    private var platformName: String {
        guard let ua = device.userAgent else { return "" }
        
        if ua.contains("iOS") {
            // Extract version: "Onera iOS/1.0 (iPhone; iOS 17.0)"
            if let range = ua.range(of: "iOS \\d+\\.\\d+", options: .regularExpression) {
                return String(ua[range])
            }
            return "iOS"
        } else if ua.contains("macOS") {
            if let range = ua.range(of: "macOS \\d+\\.\\d+", options: .regularExpression) {
                return String(ua[range])
            }
            return "macOS"
        }
        return ""
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Device icon
            Image(systemName: deviceIcon)
                .font(.title2)
                .foregroundStyle(isCurrentDevice ? .green : .primary)
                .frame(width: 32)
            
            // Device info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(device.deviceName ?? "Unknown Device")
                        .font(OneraTypography.headline)
                    
                    if isCurrentDevice {
                        Text("This device")
                            .font(OneraTypography.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    
                    if device.trusted {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                HStack(spacing: 4) {
                    if !platformName.isEmpty {
                        Text(platformName)
                    }
                    Text("•")
                    Text("Last seen \(device.lastSeenAt, style: .relative)")
                }
                .font(OneraTypography.caption)
                .foregroundStyle(theme.textSecondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Watch Sync Button (Demo Mode)

#if os(iOS)
struct WatchSyncButton: View {
    @Environment(\.theme) private var theme
    @State private var isSyncing = false
    @State private var syncSuccess = false
    
    var body: some View {
        Button {
            syncToWatch()
        } label: {
            HStack {
                Label("Sync to Apple Watch", systemImage: "applewatch")
                Spacer()
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else if syncSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .disabled(isSyncing)
    }
    
    private func syncToWatch() {
        isSyncing = true
        syncSuccess = false
        
        Task { @MainActor in
            // Reconfigure with demo services
            let demoDeps = DemoDependencyContainer.shared
            iOSWatchConnectivityManager.shared.configure(
                authService: demoDeps.authService,
                chatRepository: demoDeps.chatRepository,
                cryptoService: demoDeps.cryptoService,
                secureSession: demoDeps.secureSession
            )
            
            // Force sync
            await iOSWatchConnectivityManager.shared.syncToWatch()
            
            isSyncing = false
            syncSuccess = true
            
            // Reset checkmark after a delay
            try? await Task.sleep(for: .seconds(3))
            syncSuccess = false
        }
    }
}
#endif

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

#if DEBUG
#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            authService: MockAuthService(),
            e2eeService: MockE2EEService(),
            secureSession: MockSecureSession(),
            credentialService: MockCredentialService(),
            networkService: MockNetworkService(),
            cryptoService: CryptoService(),
            extendedCryptoService: CryptoService(),
            onSignOut: {}
        )
    )
}
#endif