// File: Models/CollisionStrategy.swift
// Purpose: Defines how to handle connection ID collisions during import
// Provides three strategies: stop, skip, or overwrite

import Foundation

/// Defines how to handle existing connection IDs during import
/// Matches the radio button options in the Import view
enum CollisionStrategy: String, CaseIterable, Identifiable {
    /// Stop the entire import if any connection ID already exists
    /// This is the safest option and matches the Python script behavior
    case stopCompletely = "Stop import completely"
    
    /// Skip connections that already exist and continue with the rest
    /// Useful when you want to add new connections without affecting existing ones
    case skipExisting = "Skip existing connections"
    
    /// Overwrite existing connections with the imported data
    /// Dangerous but useful when updating connection details
    case overwrite = "Overwrite existing connections"
    
    // MARK: - Identifiable Conformance
    
    /// ID for SwiftUI list/picker usage
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// User-friendly description of what this strategy does
    var description: String {
        switch self {
        case .stopCompletely:
            return "Import will fail if any connection ID already exists. This is the safest option."
        case .skipExisting:
            return "Connections with existing IDs will be skipped. New connections will be imported."
        case .overwrite:
            return "Existing connections will be replaced with imported data. Use with caution!"
        }
    }
    
    /// Icon name for visual representation
    var iconName: String {
        switch self {
        case .stopCompletely:
            return "hand.raised.fill"
        case .skipExisting:
            return "arrow.triangle.branch"
        case .overwrite:
            return "arrow.clockwise.circle.fill"
        }
    }
    
    /// Color for visual representation
    var color: String {
        switch self {
        case .stopCompletely:
            return "red"
        case .skipExisting:
            return "orange"
        case .overwrite:
            return "yellow"
        }
    }
    
    // MARK: - Logic Methods
    
    /// Determines if import should stop when finding an existing connection
    /// - Returns: true if import should be aborted
    func shouldStopOnCollision() -> Bool {
        return self == .stopCompletely
    }
    
    /// Determines if an existing connection should be skipped
    /// - Returns: true if connection should be skipped
    func shouldSkipExisting() -> Bool {
        return self == .skipExisting
    }
    
    /// Determines if an existing connection should be overwritten
    /// - Returns: true if connection should be replaced
    func shouldOverwrite() -> Bool {
        return self == .overwrite
    }
    
    /// Returns a confirmation message to show before importing
    /// - Parameter connectionCount: Number of connections to be imported
    /// - Returns: Warning message appropriate for this strategy
    func confirmationMessage(connectionCount: Int) -> String {
        switch self {
        case .stopCompletely:
            return "Import \(connectionCount) connection(s)? Import will stop if any ID already exists."
        case .skipExisting:
            return "Import \(connectionCount) connection(s)? Existing connections will be skipped."
        case .overwrite:
            return "Import \(connectionCount) connection(s)? This will OVERWRITE existing connections. Are you sure?"
        }
    }
}

// MARK: - Default Strategy

extension CollisionStrategy {
    /// The default collision strategy (safest option)
    static var `default`: CollisionStrategy {
        return .stopCompletely
    }
}
