// File: Views/SettingsView.swift
// Purpose: Main view for managing connection profiles and app settings
// Allows CRUD operations on connection profiles and configuration of default paths

import SwiftUI
import Combine

private let placeholderUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

/// View for managing settings and connection profiles
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Connection Profile Management
            GroupBox(label: Text("Connection Profiles").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    // Profile selector and action buttons
                    HStack {
                        Text("Saved Profiles:")
                            .frame(width: 120, alignment: .trailing)
                        
                        if viewModel.profiles.isEmpty {
                            Text("No profiles saved")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            Picker("", selection: Binding(
                                get: { viewModel.selectedProfile?.id ?? placeholderUUID },
                                set: { newId in
                                    if newId != placeholderUUID {
                                        viewModel.selectProfile(
                                            viewModel.profiles.first { $0.id == newId }
                                        )
                                    }
                                }
                            )) {
                                Text("Select a profile...")
                                    .tag(placeholderUUID)
                                
                                ForEach(viewModel.profiles) { profile in
                                    Text(profile.name)
                                        .tag(profile.id)
                                }
                            }
                            .labelsHidden()
                        }
                        
                        Spacer()
                        
                        // CHANGED: Test button only in Settings
                        Button("Test") {
                            Task {
                                await viewModel.testSelectedConnection()
                            }
                        }
                        .disabled(viewModel.selectedProfile == nil || viewModel.isTestingConnection)
                        
                        if viewModel.isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        Button("Edit") {
                            viewModel.editSelectedProfile()
                        }
                        .disabled(viewModel.selectedProfile == nil)
                        
                        Button("New") {
                            viewModel.createNewProfile()
                        }
                        
                        Button("Delete") {
                            if let profile = viewModel.selectedProfile {
                                viewModel.initiateDeleteProfile(profile)
                            }
                        }
                        .disabled(viewModel.selectedProfile == nil)
                    }
                    
                    Divider()
                    
                    // Show selected profile info (when not editing)
                    if let profile = viewModel.selectedProfile, !viewModel.isEditing {
                        ProfileInfoView(profile: profile, viewModel: viewModel)
                    }
                    
                    // Show profile editor (when editing)
                    if viewModel.isEditing, let editingProfile = viewModel.editingProfile {
                        ProfileEditorView(
                            profile: Binding(
                                get: { editingProfile },
                                set: { viewModel.editingProfile = $0 }
                            ),
                            viewModel: viewModel
                        )
                    }
                    
                    // Empty state when no profile selected and not editing
                    if viewModel.selectedProfile == nil && !viewModel.isEditing {
                        VStack {
                            Spacer()
                            Text("Select a profile or create a new one")
                                .foregroundColor(.secondary)
                                .italic()
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, )
                    }
                }
                .padding(8)
            }
            .frame(alignment: .topLeading)
            
            // MARK: - Default Settings
            GroupBox(label: Text("Default Export Settings").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    // Default export path
                    HStack {
                        Text("Default Path:")
                            .frame(width: 120, alignment: .trailing)
                        
                        TextField("Path", text: Binding(
                            get: { AppSettings.shared.defaultExportPath },
                            set: { viewModel.updateDefaultExportPath($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            selectDefaultPath()
                        }
                    }
                    
                    // Default filename
                    HStack {
                        Text("Default Filename:")
                            .frame(width: 120, alignment: .trailing)
                        
                        TextField("Filename", text: Binding(
                            get: { AppSettings.shared.defaultFilename },
                            set: { viewModel.updateDefaultFilename($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Text("_[timestamp]_[connection].csv")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Timestamp and connection name will be automatically added to the filename.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 130)
                }
                .padding(8)
            }
            .frame(height: 120)
            Spacer()
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK") {
                viewModel.showAlert = false
            }
        } message: {
            Text(viewModel.alertMessage)
        }
        .confirmationDialog(
            "Delete Profile",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.confirmDeleteProfile()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let profile = viewModel.profileToDelete {
                Text("Are you sure you want to delete '\(profile.name)'? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - File Selection
    
    /// Opens a panel to select default export directory
    private func selectDefaultPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select default export directory"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                viewModel.updateDefaultExportPath(url.path)
            }
        }
    }
}

// MARK: - Profile Info View

/// Displays read-only information about a connection profile
struct ProfileInfoView: View {
    let profile: ConnectionProfile
    let viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoRow(label: "Name", value: profile.name)
            InfoRow(label: "Host", value: profile.host)
            InfoRow(label: "Port", value: String(profile.port))
            InfoRow(label: "Database", value: profile.database)
            InfoRow(label: "Username", value: profile.username)
            InfoRow(label: "Password", value: String(repeating: "•", count: profile.password.count))
            
            // CHANGED: Fernet key shown as dots (secure), no copy button
            HStack {
                Text("Fernet Key:")
                    .frame(width: 120, alignment: .trailing)
                    .foregroundColor(.secondary)
                
                Text(profile.fernetKey.isEmpty ? "Not set" : String(repeating: "•", count: 44))
                    .font(.system(.body, design: .monospaced))
            }
            
            Divider()
            
            HStack {
                Text("Created:")
                    .foregroundColor(.secondary)
                Text(profile.createdAt, style: .date)
                
                Spacer()
                
                Text("Updated:")
                    .foregroundColor(.secondary)
                Text(profile.updatedAt, style: .date)
            }
            .font(.caption)
        }
        .padding(.vertical, 8)
    }
}

/// Simple info row for displaying profile details
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .frame(width: 120, alignment: .trailing)
                .foregroundColor(.secondary)
            
            Text(value)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Profile Editor View

/// Form for editing or creating a connection profile
struct ProfileEditorView: View {
    @Binding var profile: ConnectionProfile
    let viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.isCreatingNew ? "New Connection Profile" : "Edit Connection Profile")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Divider()
            
            // Name
            HStack {
                Text("Name:")
                    .frame(width: 120, alignment: .trailing)
                TextField("Profile name", text: $profile.name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Host
            HStack {
                Text("Host:")
                    .frame(width: 120, alignment: .trailing)
                TextField("127.0.0.1", text: $profile.host)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Port
            HStack {
                Text("Port:")
                    .frame(width: 120, alignment: .trailing)
                TextField("5432", value: $profile.port, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
            }
            
            // Database
            HStack {
                Text("Database:")
                    .frame(width: 120, alignment: .trailing)
                TextField("postgres", text: $profile.database)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Username
            HStack {
                Text("Username:")
                    .frame(width: 120, alignment: .trailing)
                TextField("postgres", text: $profile.username)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Password
            HStack {
                Text("Password:")
                    .frame(width: 120, alignment: .trailing)
                SecureField("Password", text: Binding(
                    get: { profile.password },
                    set: { profile.password = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            
            Divider()
            
            // CHANGED: Fernet Key as SecureField, no generate/copy buttons
            HStack {
                Text("Fernet Key:")
                    .frame(width: 120, alignment: .trailing)
                
                SecureField("Fernet encryption key", text: Binding(
                    get: { profile.fernetKey },
                    set: { profile.fernetKey = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            }
            
            Text("The Fernet key for this Airflow instance (used to decrypt connection passwords).")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 130)
            
            Divider()
            
            // Action buttons
            HStack {
                Button("Test Connection") {
                    Task {
                        await viewModel.testEditingConnection()
                    }
                }
                .disabled(viewModel.isTestingConnection)
                
                if viewModel.isTestingConnection {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Spacer()
                
                Button("Cancel") {
                    viewModel.cancelEdit()
                }
                
                Button("Save") {
                    viewModel.saveProfile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isEditingProfileValid)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .frame(width: 800, height: 700)
}
