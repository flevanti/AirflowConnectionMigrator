// File: Models/AppSettings.swift
// Purpose: Manages application-wide settings and preferences
// Stores non-sensitive settings in UserDefaults

import Foundation
import Combine

/// Manages application settings that persist between app launches
/// Uses UserDefaults for storage (non-sensitive data only)
@MainActor
class AppSettings: ObservableObject {
    /// Shared singleton instance
    static let shared = AppSettings()

    // MARK: - Published Properties
    // These trigger UI updates when changed

    /// Default directory path for saving exported files
    @Published var defaultExportPath: String {
        didSet {
            UserDefaults.standard.set(defaultExportPath, forKey: Keys.defaultExportPath)
        }
    }

    /// Default filename template for exports
    /// Will be combined with timestamp and connection name
    @Published var defaultFilename: String {
        didSet {
            UserDefaults.standard.set(defaultFilename, forKey: Keys.defaultFilename)
        }
    }

    /// ID of the last used connection profile (for convenience)
    @Published var lastUsedConnectionId: String? {
        didSet {
            if let id = lastUsedConnectionId {
                UserDefaults.standard.set(id, forKey: Keys.lastUsedConnectionId)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastUsedConnectionId)
            }
        }
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let defaultExportPath = "defaultExportPath"
        static let defaultFilename = "defaultFilename"
        static let lastUsedConnectionId = "lastUsedConnectionId"
    }

    // MARK: - Initialization

    private init() {
        // Load settings from UserDefaults or use defaults
        self.defaultExportPath = UserDefaults.standard.string(forKey: Keys.defaultExportPath) ?? Self.getDefaultDownloadsPath()
        self.defaultFilename = UserDefaults.standard.string(forKey: Keys.defaultFilename) ?? "airflow_connections"
        self.lastUsedConnectionId = UserDefaults.standard.string(forKey: Keys.lastUsedConnectionId)
    }

    // MARK: - Helper Methods

    /// Generates a full export filename with timestamp and connection name
    /// Format: airflow_connections_[timestamp]_[connection_name].csv
    /// - Parameter connectionName: Name of the source connection profile
    /// - Returns: Complete filename with timestamp
    func generateExportFilename(connectionName: String) -> String {
        let timestamp = Self.currentTimestamp()
        let sanitizedName = connectionName.replacingOccurrences(of: " ", with: "_")
        return "\(defaultFilename)_\(timestamp)_\(sanitizedName).csv"
    }

    /// Returns the current timestamp in format: yyyyMMdd_HHmmss
    /// - Returns: Formatted timestamp string
    private static func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    /// Returns the user's Downloads folder path
    /// - Returns: Path to Downloads folder or home directory as fallback
    private static func getDefaultDownloadsPath() -> String {
        let fileManager = FileManager.default

        // Try to get Downloads folder
        if let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            return downloadsURL.path
        }

        // Fallback to home directory
        return NSHomeDirectory()
    }

    /// Combines default path with a filename to create full file URL
    /// - Parameter filename: The filename to append to the default path
    /// - Returns: Complete file URL
    func getFullExportURL(filename: String) -> URL {
        let pathURL = URL(fileURLWithPath: defaultExportPath)
        return pathURL.appendingPathComponent(filename)
    }

    // MARK: - Reset

    /// Resets all settings to default values
    func resetToDefaults() {
        defaultExportPath = Self.getDefaultDownloadsPath()
        defaultFilename = "airflow_connections"
        lastUsedConnectionId = nil
    }

    /// Validates that the default export path exists and is writable
    /// - Returns: true if path is valid and writable
    func isExportPathValid() -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        // Check if path exists and is a directory
        guard fileManager.fileExists(atPath: defaultExportPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        // Check if path is writable
        return fileManager.isWritableFile(atPath: defaultExportPath)
    }
}
