// File: Services/ConnectionProfileService.swift
// Purpose: Manages saved connection profiles in local storage
// Handles persistence, loading, and CRUD operations for connection profiles

import Foundation
import Combine

/// Service for managing connection profiles
/// Stores profiles in UserDefaults (non-sensitive data) and Keychain (sensitive data)
@MainActor
class ConnectionProfileService: ObservableObject {
    /// Shared singleton instance
    static let shared = ConnectionProfileService()
    
    /// Array of saved connection profiles
    @Published private(set) var profiles: [ConnectionProfile] = []
    
    /// UserDefaults key for storing profiles
    private let profilesKey = "savedConnectionProfiles"
    
    // MARK: - Initialization
    
    private init() {
        loadProfiles()
    }
    
    // MARK: - Load Profiles
    
    /// Loads all saved profiles from UserDefaults
    private func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: profilesKey) else {
            // No profiles saved yet
            profiles = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            profiles = try decoder.decode([ConnectionProfile].self, from: data)
        } catch {
            print("⚠️ Failed to load connection profiles: \(error)")
            profiles = []
        }
    }
    
    // MARK: - Save Profiles
    
    /// Saves all profiles to UserDefaults
    /// Note: Sensitive data (passwords, Fernet keys) are stored in Keychain via ConnectionProfile
    private func saveProfiles() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(profiles)
            UserDefaults.standard.set(data, forKey: profilesKey)
        } catch {
            print("⚠️ Failed to save connection profiles: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Adds a new connection profile
    /// - Parameter profile: The profile to add
    func addProfile(_ profile: ConnectionProfile) {
        var newProfile = profile
        newProfile.createdAt = Date()
        newProfile.updatedAt = Date()
        
        profiles.append(newProfile)
        saveProfiles()
    }
    
    /// Updates an existing connection profile
    /// - Parameter profile: The updated profile (must have matching ID)
    func updateProfile(_ profile: ConnectionProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            print("⚠️ Profile not found for update: \(profile.id)")
            return
        }
        
        var updatedProfile = profile
        updatedProfile.updatedAt = Date()
        
        profiles[index] = updatedProfile
        saveProfiles()
    }
    
    /// Deletes a connection profile
    /// Also removes sensitive data from Keychain
    /// - Parameter profile: The profile to delete
    func deleteProfile(_ profile: ConnectionProfile) {
        // Remove from profiles array
        profiles.removeAll { $0.id == profile.id }
        
        // Clean up Keychain data
        profile.deleteKeychainData()
        
        saveProfiles()
    }
    
    /// Deletes multiple connection profiles
    /// - Parameter profiles: Array of profiles to delete
    func deleteProfiles(_ profilesToDelete: [ConnectionProfile]) {
        for profile in profilesToDelete {
            deleteProfile(profile)
        }
    }
    
    // MARK: - Query Operations
    
    /// Finds a profile by its ID
    /// - Parameter id: The UUID of the profile to find
    /// - Returns: The profile if found, nil otherwise
    func getProfile(by id: UUID) -> ConnectionProfile? {
        return profiles.first { $0.id == id }
    }
    
    /// Finds a profile by its name
    /// - Parameter name: The name of the profile to find
    /// - Returns: The profile if found, nil otherwise
    func getProfile(byName name: String) -> ConnectionProfile? {
        return profiles.first { $0.name.lowercased() == name.lowercased() }
    }
    
    /// Checks if a profile name already exists
    /// - Parameters:
    ///   - name: The name to check
    ///   - excludingId: Optional ID to exclude from check (for updates)
    /// - Returns: true if name is already used
    func profileNameExists(_ name: String, excludingId: UUID? = nil) -> Bool {
        return profiles.contains { profile in
            profile.name.lowercased() == name.lowercased() &&
            profile.id != excludingId
        }
    }
    
    /// Returns all valid profiles (have all required fields)
    /// - Returns: Array of valid profiles ready for use
    func getValidProfiles() -> [ConnectionProfile] {
        return profiles.filter { $0.isValid() }
    }
    
    // MARK: - Utility Methods
    
    /// Creates a default profile if no profiles exist
    /// Useful for first-time app launch
    func createDefaultProfileIfNeeded() {
        guard profiles.isEmpty else {
            return
        }
        
        addProfile(ConnectionProfile.defaultProfile)
    }
    
    /// Exports all profiles to a JSON file (for backup)
    /// Note: Sensitive data is NOT included in export
    /// - Returns: Result with URL of exported file or error
    func exportProfilesToFile() -> Result<URL, Error> {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(profiles)
            
            // Create temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("connection_profiles_\(Date().timeIntervalSince1970).json")
            
            try data.write(to: fileURL)
            
            return .success(fileURL)
        } catch {
            return .failure(error)
        }
    }
    
    /// Imports profiles from a JSON file
    /// Note: Sensitive data (passwords, keys) must be re-entered by user
    /// - Parameter fileURL: URL of the JSON file to import
    /// - Returns: Result with count of imported profiles or error
    func importProfilesFromFile(_ fileURL: URL) -> Result<Int, Error> {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let importedProfiles = try decoder.decode([ConnectionProfile].self, from: data)
            
            var importCount = 0
            
            // Add profiles that don't have duplicate names
            for profile in importedProfiles {
                if !profileNameExists(profile.name) {
                    addProfile(profile)
                    importCount += 1
                } else {
                    print("⚠️ Skipping profile '\(profile.name)' - name already exists")
                }
            }
            
            return .success(importCount)
        } catch {
            return .failure(error)
        }
    }
    
    /// Resets all profiles (WARNING: This deletes everything)
    func resetAllProfiles() {
        // Clean up Keychain for all profiles
        for profile in profiles {
            profile.deleteKeychainData()
        }
        
        // Clear profiles array
        profiles.removeAll()
        
        // Save empty state
        saveProfiles()
    }
}
