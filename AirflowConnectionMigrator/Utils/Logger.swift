// File: Utils/Logger.swift
// Purpose: Thread-safe logging system for displaying operation progress in UI
// Provides real-time log messages that appear in the scrollable text views

import Foundation
import Combine

/// Log message type for visual differentiation
enum LogType {
    case info       // General information (blue/default)
    case success    // Successful operations (green)
    case warning    // Warnings that don't stop execution (orange)
    case error      // Errors that stop or fail operations (red)
    
    /// Symbol/emoji prefix for console output
    var prefix: String {
        switch self {
        case .info: return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error: return "🔴"
        }
    }
}

/// Represents a single log entry
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: LogType
    let message: String
    
    /// Returns formatted timestamp (HH:mm:ss)
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    /// Returns formatted log line for display
    /// Format: [HH:mm:ss] [TYPE] Message
    var formattedMessage: String {
        return "[\(timestampString)] \(type.prefix) \(message)"
    }
}

/// Thread-safe logger that collects log entries for display in UI
/// Use @MainActor to ensure UI updates happen on main thread
@MainActor
class Logger: ObservableObject {
    /// Published array of log entries - triggers UI updates when modified
    @Published private(set) var entries: [LogEntry] = []
    
    /// Maximum number of log entries to keep in memory
    /// Prevents memory issues with very long operations
    private let maxEntries = 1000
    
    // MARK: - Logging Methods
    
    /// Logs an informational message
    /// - Parameter message: The message to log
    func info(_ message: String) {
        log(message, type: .info)
    }
    
    /// Logs a success message
    /// - Parameter message: The message to log
    func success(_ message: String) {
        log(message, type: .success)
    }
    
    /// Logs a warning message
    /// - Parameter message: The message to log
    func warning(_ message: String) {
        log(message, type: .warning)
    }
    
    /// Logs an error message
    /// - Parameter message: The message to log
    func error(_ message: String) {
        log(message, type: .error)
    }
    
    /// Core logging method that creates and stores log entries
    /// - Parameters:
    ///   - message: The message to log
    ///   - type: The type of log entry
    private func log(_ message: String, type: LogType) {
        let entry = LogEntry(timestamp: Date(), type: type, message: message)
        
        // Add to entries array
        entries.append(entry)
        
        // Also print to console for debugging
        print(entry.formattedMessage)
        
        // Trim old entries if we exceed max
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clears all log entries
    func clear() {
        entries.removeAll()
        info("Log cleared")
    }
    
    /// Returns all log entries as a single formatted string
    /// Useful for exporting logs or copying to clipboard
    /// - Returns: Multi-line string with all log entries
    func getAllLogsAsString() -> String {
        return entries.map { $0.formattedMessage }.joined(separator: "\n")
    }
    
    /// Logs a separator line for visual organization
    func separator() {
        log("─────────────────────────────────────────", type: .info)
    }
    
    /// Logs a section header
    /// - Parameter title: The section title
    func section(_ title: String) {
        separator()
        info(title)
        separator()
    }
}
