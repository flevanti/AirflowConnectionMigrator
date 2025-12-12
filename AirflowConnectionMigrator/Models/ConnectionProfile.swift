// File: Models/ConnectionProfile.swift
// Purpose: Represents a saved database connection profile with its credentials and Fernet key
// This model stores connection details that users can save in Settings and reuse in Export/Import

import Foundation

/// Represents a saved connection profile for an Airflow PostgreSQL database
/// Includes database credentials and the associated Fernet encryption key
struct ConnectionProfile: Identifiable, Codable, Equatable {
    /// Unique identifier for this connection profile
    var id: UUID
    
    /// User-friendly name for this connection (e.g., "Local Dev", "Staging")
    var name: String
    
    /// PostgreSQL host address (e.g., "127.0.0.1" or "postgres.example.com")
    var host: String
    
    /// PostgreSQL port (typically 5432)
    var port: Int
    
    /// Database name (typically "postgres" for Airflow)
    var database: String
    
    /// PostgreSQL username
    var username: String
    
    /// PostgreSQL password - NOT stored in this struct
    /// Actual password is stored securely in Keychain
    /// This property exists only for temporary use during editing
    var password: String {
        get {
            // Retrieve password from Keychain when accessed
            KeychainHelper.shared.read(service: keychainPasswordKey) ?? ""
        }
        set {
            // Store password in Keychain when set
            if newValue.isEmpty {
                KeychainHelper.shared.delete(service: keychainPasswordKey)
            } else {
                KeychainHelper.shared.save(newValue, service: keychainPasswordKey)
            }
        }
    }
    
    /// Fernet encryption key for this Airflow instance - NOT stored in this struct
    /// Actual key is stored securely in Keychain (treated like a password)
    /// This property exists only for temporary use during editing
    /// CHANGED: Now treated as secure/sensitive data, not displayed in clear text
    var fernetKey: String {
        get {
            // Retrieve Fernet key from Keychain when accessed
            KeychainHelper.shared.read(service: keychainFernetKey) ?? ""
        }
        set {
            // Store Fernet key in Keychain when set
            if newValue.isEmpty {
                KeychainHelper.shared.delete(service: keychainFernetKey)
            } else {
                KeychainHelper.shared.save(newValue, service: keychainFernetKey)
            }
        }
    }
    
    /// Date when this profile was created
    var createdAt: Date
    
    /// Date when this profile was last modified
    var updatedAt: Date
    
    // MARK: - Keychain Keys
    // These generate unique Keychain identifiers based on the profile's UUID
    
    /// Keychain service key for storing the password
    private var keychainPasswordKey: String {
        "airflow.connection.\(id.uuidString).password"
    }
    
    /// Keychain service key for storing the Fernet key
    private var keychainFernetKey: String {
        "airflow.connection.\(id.uuidString).fernetKey"
    }
    
    // MARK: - Initialization
    
    /// Creates a new connection profile with default values
    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "127.0.0.1",
        port: Int = 5432,
        database: String = "postgres",
        username: String = "postgres",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.database = database
        self.username = username
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Codable Implementation
    // Custom Codable implementation because password and fernetKey are stored in Keychain
    
    enum CodingKeys: String, CodingKey {
        case id, name, host, port, database, username, createdAt, updatedAt
        // Note: password and fernetKey are NOT encoded/decoded
        // They're stored separately in Keychain
    }
    
    // MARK: - Validation
    
    /// Checks if this profile has all required fields filled in
    /// - Returns: true if profile is complete and ready to use
    func isValid() -> Bool {
        return !name.isEmpty &&
               !host.isEmpty &&
               port > 0 &&
               !database.isEmpty &&
               !username.isEmpty &&
               !password.isEmpty &&
               !fernetKey.isEmpty
    }
    
    /// Returns a display string showing the connection details
    /// - Returns: Formatted string like "postgres@127.0.0.1:5432/postgres"
    func connectionString() -> String {
        return "\(username)@\(host):\(port)/\(database)"
    }
    
    // MARK: - Cleanup
    
    /// Removes sensitive data from Keychain when this profile is deleted
    /// Call this before removing a profile from the saved profiles list
    func deleteKeychainData() {
        KeychainHelper.shared.delete(service: keychainPasswordKey)
        KeychainHelper.shared.delete(service: keychainFernetKey)
    }
}

// MARK: - Default Profile

extension ConnectionProfile {
    /// Returns a default profile matching the Python script's default configuration
    static var defaultProfile: ConnectionProfile {
        var profile = ConnectionProfile(
            name: "Local Development",
            host: "127.0.0.1",
            port: 5432,
            database: "postgres",
            username: "postgres"
        )
        // Set default password and empty Fernet key
        profile.password = "postgres"
        profile.fernetKey = ""
        return profile
    }
}
