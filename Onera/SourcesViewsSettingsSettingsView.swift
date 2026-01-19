//
//  SettingsView.swift
//  Onera
//
//  App settings and account management
//

import SwiftUI

struct SettingsView: View {
    @State private var authManager = AuthenticationManager.shared
    @State private var secureSession = SecureSession.shared
    @State private var showRecoveryPhrase = false
    @State private var showSignOutConfirmation = false
    @State private var recoveryPhrase: String?
    
    var body: some View {
        NavigationStack {
            List {
                // Account section
                Section("Account") {
                    if let user = authManager.currentUser {
                        HStack {
                            Circle()
                                .fill(.tint.opacity(0.1))
                                .frame(width: 48, height: 48)
                                .overlay {
                                    Text(user.displayName.prefix(1).uppercased())
                                        .font(.title2.bold())
                                        .foregroundStyle(.tint)
                                }
                            
                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Security section
                Section("Security") {
                    // Encryption status
                    HStack {
                        Label("End-to-End Encryption", systemImage: "lock.shield.fill")
                        Spacer()
                        if secureSession.isUnlocked {
                            Text("Active")
                                .foregroundStyle(.green)
                        } else {
                            Text("Locked")
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    // View recovery phrase
                    Button {
                        showRecoveryPhrase = true
                    } label: {
                        Label("View Recovery Phrase", systemImage: "key.fill")
                    }
                    .disabled(!secureSession.isUnlocked)
                    
                    // Lock session
                    if secureSession.isUnlocked {
                        Button {
                            Task {
                                await secureSession.lock()
                            }
                        } label: {
                            Label("Lock Session", systemImage: "lock.fill")
                        }
                    }
                }
                
                // Devices section
                Section("Devices") {
                    NavigationLink {
                        DeviceManagementView()
                    } label: {
                        Label("Manage Devices", systemImage: "laptopcomputer.and.iphone")
                    }
                }
                
                // App section
                Section("App") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }
                    
                    Link(destination: URL(string: "https://onera.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://onera.app/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
                
                // Sign out
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                
                // Version info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showRecoveryPhrase) {
                RecoveryPhraseDisplayView()
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out? Make sure you have your recovery phrase saved.")
            }
        }
    }
}

// MARK: - Recovery Phrase Display

struct RecoveryPhraseDisplayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var recoveryPhrase: String?
    @State private var error: Error?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Decrypting...")
                } else if let phrase = recoveryPhrase {
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("Your Recovery Phrase")
                                .font(.title2.bold())
                            
                            RecoveryPhraseGrid(phrase: phrase)
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            Button {
                                UIPasteboard.general.string = phrase
                            } label: {
                                Label("Copy to Clipboard", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            
                            Text("Keep this phrase secure. Never share it with anyone.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                } else if let error = error {
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.localizedDescription)
                    )
                }
            }
            .navigationTitle("Recovery Phrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadRecoveryPhrase()
        }
    }
    
    private func loadRecoveryPhrase() async {
        do {
            let phrase = try await E2EEManager.shared.getRecoveryPhrase()
            recoveryPhrase = phrase
        } catch {
            self.error = error
        }
        isLoading = false
    }
}

// MARK: - Placeholder Views

struct DeviceManagementView: View {
    var body: some View {
        List {
            Section("Current Device") {
                HStack {
                    Image(systemName: "iphone")
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text(UIDevice.current.name)
                            .font(.headline)
                        Text("This device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Other Devices") {
                Text("No other devices")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Devices")
    }
}

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

struct NotificationSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    var body: some View {
        List {
            Toggle("Push Notifications", isOn: $notificationsEnabled)
        }
        .navigationTitle("Notifications")
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
