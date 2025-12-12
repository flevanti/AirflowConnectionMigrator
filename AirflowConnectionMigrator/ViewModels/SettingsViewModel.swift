// File: ViewModels/SettingsViewModel.swift
// Purpose: Manages the state and logic for the Settings view
// Handles connection profile CRUD operations and app settings

import Foundation
import SwiftUI
import Combine
import SwiftFernet


/// ViewModel for the Settings view
/// Manages connection profiles and application settings
@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties (trigger UI updates)
    
    /// Selected profile in the dropdown (for viewing/editing)
    @Published var selectedProfile: ConnectionProfile?
    
    /// Profile being edited (separate from selected to allow cancel)
    @Published var editingProfile: ConnectionProfile?
    
    /// Flag indicating if we're in edit mode
    @Published var isEditing = false
    
    /// Flag indicating if we're creating a new profile
    @Published var isCreatingNew = false
    
    /// Loading state flag
    @Published var isTestingConnection = false
    
    /// Alert state
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    /// Confirmation dialog state
    @Published var showDeleteConfirmation = false
    @Published var profileToDelete: ConnectionProfile?
    
    // MARK: - Dependencies
    
    /// Connection profile service (for loading/saving profiles)
    private let profileService = ConnectionProfileService.shared
    
    /// App settings
    private let appSettings = AppSettings.shared
    
    // MARK: - Computed Properties
    
    /// All saved connection profiles
    var profiles: [ConnectionProfile] {
        return profileService.profiles
    }
    
    /// Checks if the editing profile is valid
    var isEditingProfileValid: Bool {
        guard let profile = editingProfile else {
            return false
        }
        return !profile.name.isEmpty &&
               !profile.host.isEmpty &&
               profile.port > 0 &&
               !profile.database.isEmpty &&
               !profile.username.isEmpty &&
               !profile.password.isEmpty &&
               !profile.fernetKey.isEmpty &&
               SwiftFernet.isValidKey(profile.fernetKey)
    }
    
    // MARK: - Profile Selection
    
    /// Selects a profile for viewing
    /// - Parameter profile: The profile to select
    func selectProfile(_ profile: ConnectionProfile?) {
        selectedProfile = profile
        
        // Exit edit mode when selecting a different profile
        if isEditing && editingProfile?.id != profile?.id {
            cancelEdit()
        }
    }
    
    // MARK: - Create New Profile
    
    /// Initiates creation of a new profile
    func createNewProfile() {
        editingProfile = ConnectionProfile()
        isCreatingNew = true
        isEditing = true
    }
    
    // MARK: - Edit Profile
    
    /// Initiates editing of the selected profile
    func editSelectedProfile() {
        guard let profile = selectedProfile else {
            showError("No Profile Selected", "Please select a profile to edit.")
            return
        }
        
        // Create a copy for editing
        editingProfile = profile
        isCreatingNew = false
        isEditing = true
    }
    
    /// Saves the edited profile
    func saveProfile() {
        guard let profile = editingProfile else {
            return
        }
        
        // Validate
        guard isEditingProfileValid else {
            showError("Invalid Profile", "Please fill in all required fields with valid values.")
            return
        }
        
        // Check for duplicate names (excluding current profile if editing)
        if profileService.profileNameExists(profile.name, excludingId: profile.id) {
            showError("Duplicate Name", "A profile with this name already exists. Please choose a different name.")
            return
        }
        
        if isCreatingNew {
            // Add new profile
            profileService.addProfile(profile)
            selectedProfile = profile
            showSuccess("Profile Created", "Connection profile '\(profile.name)' has been created.")
        } else {
            // Update existing profile
            profileService.updateProfile(profile)
            selectedProfile = profile
            showSuccess("Profile Updated", "Connection profile '\(profile.name)' has been updated.")
        }
        
        // Exit edit mode
        isEditing = false
        isCreatingNew = false
        editingProfile = nil
    }
    
    /// Cancels editing without saving
    func cancelEdit() {
        isEditing = false
        isCreatingNew = false
        editingProfile = nil
    }
    
    // MARK: - Delete Profile
    
    /// Initiates deletion of a profile (shows confirmation)
    /// - Parameter profile: The profile to delete
    func initiateDeleteProfile(_ profile: ConnectionProfile) {
        profileToDelete = profile
        showDeleteConfirmation = true
    }
    
    /// Confirms and executes profile deletion
    func confirmDeleteProfile() {
        guard let profile = profileToDelete else {
            return
        }
        
        // If deleting the selected profile, clear selection
        if selectedProfile?.id == profile.id {
            selectedProfile = nil
        }
        
        // If deleting the profile being edited, cancel edit
        if editingProfile?.id == profile.id {
            cancelEdit()
        }
        
        // Delete the profile
        profileService.deleteProfile(profile)
        
        showSuccess("Profile Deleted", "Connection profile '\(profile.name)' has been deleted.")
        
        profileToDelete = nil
    }
    
    // MARK: - Test Connection
    
    /// Tests the connection for the profile being edited
    func testEditingConnection() async {
        guard let profile = editingProfile else {
            showError("No Profile", "No profile is being edited.")
            return
        }
        
        // Basic validation
        guard !profile.host.isEmpty &&
              !profile.database.isEmpty &&
              !profile.username.isEmpty &&
              !profile.password.isEmpty else {
            showError("Incomplete Profile", "Please fill in host, database, username, and password.")
            return
        }
        
        isTestingConnection = true
        
        let result = await DatabaseService.testConnection(profile)
        
        isTestingConnection = false
        
        switch result {
        case .success(let message):
            showSuccess("Connection Successful", message)
        case .failure(let error):
            showError("Connection Failed", error.localizedDescription)
        }
    }
    
    /// Tests the connection for the selected profile
    func testSelectedConnection() async {
        guard let profile = selectedProfile else {
            showError("No Profile Selected", "Please select a profile to test.")
            return
        }
        
        isTestingConnection = true
        
        let result = await DatabaseService.testConnection(profile)
        
        isTestingConnection = false
        
        switch result {
        case .success(let message):
            showSuccess("Connection Successful", message)
        case .failure(let error):
            showError("Connection Failed", error.localizedDescription)
        }
    }
    
    // MARK: - Fernet Key Operations
    
    /// Generates a new Fernet key for the editing profile
    func generateFernetKey() {
        guard editingProfile != nil else {
            return
        }
        
        editingProfile?.fernetKey = SwiftFernet.generateKey()
    }
    
    /// Copies the Fernet key to clipboard
    /// - Parameter profile: The profile whose key to copy
    func copyFernetKeyToClipboard(for profile: ConnectionProfile) {
        let key = profile.fernetKey
        guard !key.isEmpty else {
            showError("No Key", "This profile doesn't have a Fernet key.")
            return
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key, forType: .string)
        showSuccess("Copied", "Fernet key copied to clipboard")
    }
    
    // MARK: - App Settings
    
    /// Updates the default export path
    /// - Parameter path: The new default export path
    func updateDefaultExportPath(_ path: String) {
        appSettings.defaultExportPath = path
    }
    
    /// Updates the default filename
    /// - Parameter filename: The new default filename
    func updateDefaultFilename(_ filename: String) {
        appSettings.defaultFilename = filename
    }
    
    /// Resets app settings to defaults
    func resetAppSettings() {
        appSettings.resetToDefaults()
        showSuccess("Settings Reset", "Application settings have been reset to defaults.")
    }
    
    // MARK: - Initialization
    
    init() {
        // Create default profile if needed on first launch
        profileService.createDefaultProfileIfNeeded()
        
        // Select first profile if available
// commented out, we don't want a pre-selected profile...
//        if let firstProfile = profiles.first {
//            selectedProfile = firstProfile
//        }
    }
    
    // MARK: - Alert Helpers
    
    /// Shows an error alert
    private func showError(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    /// Shows a success alert
    private func showSuccess(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
