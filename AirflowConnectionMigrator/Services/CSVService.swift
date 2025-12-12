// File: Services/CSVService.swift
// Purpose: Handles reading and writing of CSV files for connection export/import
// Creates encrypted CSV files matching the Python script's format

import Foundation
import Combine
import SwiftFernet

/// Service for reading and writing Airflow connection CSV files
/// Format: conn_id, encrypted_connection_json
class CSVService {
    
    // MARK: - CSV Headers
    
    /// CSV column headers matching Python script format
    private static let headers = ["conn_id", "encrypted_connection"]
    
    // MARK: - Export (Write CSV)
    
    /// Exports connections to a CSV file with encrypted JSON
    /// - Parameters:
    ///   - connections: Array of connections to export
    ///   - fileURL: Destination file URL
    ///   - fernetKey: Fernet key to encrypt the connection JSON
    /// - Returns: Result with file URL or error
    static func exportConnections(
        _ connections: [AirflowConnection],
        to fileURL: URL,
        fernetKey: String
    ) async -> Result<URL, Error> {
        do {
            // Build CSV content
            var csvLines: [String] = []
            
            // Add header row
            csvLines.append(headers.joined(separator: ","))
            
            // Add data rows
            for connection in connections {
                // Convert connection to JSON string
                guard let jsonString = connection.toJSONString() else {
                    throw CSVError.jsonEncodingFailed(connId: connection.conn_id)
                }
                
                // Encrypt the JSON string
                guard let encryptedJson = SwiftFernet.encrypt(jsonString, withKey: fernetKey) else {
                    throw CSVError.encryptionFailed(connId: connection.conn_id)
                }
                
                // Escape values for CSV (wrap in quotes if contains comma or newline)
                let escapedConnId = escapeCSVValue(connection.conn_id)
                let escapedEncrypted = escapeCSVValue(encryptedJson)
                
                // Add row
                csvLines.append("\(escapedConnId),\(escapedEncrypted)")
            }
            
            // Join all lines
            let csvContent = csvLines.joined(separator: "\n")
            
            // Write to file
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            
            return .success(fileURL)
            
        } catch {
            return .failure(error)
        }
    }
    
    // MARK: - Import (Read CSV)
    
    /// Imports connections from a CSV file with encrypted JSON
    /// - Parameters:
    ///   - fileURL: Source file URL
    ///   - fernetKey: Fernet key to decrypt the connection JSON
    /// - Returns: Result with array of connections or error
    static func importConnections(
        from fileURL: URL,
        fernetKey: String
    ) async -> Result<[AirflowConnection], Error> {
        do {
            // Read file content
            let csvContent = try String(contentsOf: fileURL, encoding: .utf8)
            
            // Split into lines
            let lines = csvContent.components(separatedBy: .newlines)
            
            // Validate we have at least header + 1 data row
            guard lines.count >= 2 else {
                throw CSVError.emptyFile
            }
            
            // Validate header
            let headerLine = lines[0].trimmingCharacters(in: .whitespaces)
            guard headerLine.lowercased() == headers.joined(separator: ",").lowercased() else {
                throw CSVError.invalidHeader(found: headerLine)
            }
            
            var connections: [AirflowConnection] = []
            
            // Process each data row (skip header at index 0)
            for (index, line) in lines.enumerated() where index > 0 {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                
                // Skip empty lines
                guard !trimmedLine.isEmpty else {
                    continue
                }
                
                // Parse CSV row
                let fields = parseCSVLine(trimmedLine)
                
                // Validate we have exactly 2 fields
                guard fields.count == 2 else {
                    throw CSVError.invalidRowFormat(lineNumber: index + 1, fieldCount: fields.count)
                }
                
                let connId = fields[0]
                let encryptedJson = fields[1]
                
                // Decrypt the JSON string
                guard let decryptedJson = SwiftFernet.decrypt(encryptedJson, withKey: fernetKey) else {
                    throw CSVError.decryptionFailed(connId: connId, lineNumber: index + 1)
                }
                
                // Parse JSON into AirflowConnection
                guard let connection = AirflowConnection.fromJSONString(decryptedJson) else {
                    throw CSVError.jsonDecodingFailed(connId: connId, lineNumber: index + 1)
                }
                
                connections.append(connection)
            }
            
            // Validate we got at least one connection
            guard !connections.isEmpty else {
                throw CSVError.noConnectionsFound
            }
            
            return .success(connections)
            
        } catch let error as CSVError {
            return .failure(error)
        } catch {
            return .failure(CSVError.fileReadError(error))
        }
    }
    
    // MARK: - CSV Parsing Helpers
    
    /// Escapes a CSV value (wraps in quotes if needed)
    /// - Parameter value: The value to escape
    /// - Returns: Escaped value safe for CSV
    private static func escapeCSVValue(_ value: String) -> String {
        // Check if value needs escaping (contains comma, quote, or newline)
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            // Escape quotes by doubling them
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            // Wrap in quotes
            return "\"\(escaped)\""
        }
        return value
    }
    
    /// Parses a single CSV line into fields
    /// Handles quoted fields with commas
    /// - Parameter line: CSV line to parse
    /// - Returns: Array of field values
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var previousChar: Character?
        
        for char in line {
            if char == "\"" {
                // Check if this is an escaped quote (preceded by another quote)
                if insideQuotes && previousChar == "\"" {
                    currentField.append(char)
                    previousChar = nil  // Reset to avoid triple-quote issues
                    continue
                }
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                // Field separator (only when not inside quotes)
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
            
            previousChar = char
        }
        
        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        
        return fields
    }
}

// MARK: - CSV Errors

/// Custom errors for CSV operations
enum CSVError: LocalizedError {
    case emptyFile
    case invalidHeader(found: String)
    case invalidRowFormat(lineNumber: Int, fieldCount: Int)
    case jsonEncodingFailed(connId: String)
    case jsonDecodingFailed(connId: String, lineNumber: Int)
    case encryptionFailed(connId: String)
    case decryptionFailed(connId: String, lineNumber: Int)
    case noConnectionsFound
    case fileReadError(Error)
    
    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "CSV file is empty or contains no data rows"
        case .invalidHeader(let found):
            return "Invalid CSV header. Expected 'conn_id,encrypted_connection' but found '\(found)'"
        case .invalidRowFormat(let line, let count):
            return "Invalid CSV row format at line \(line). Expected 2 fields but found \(count)"
        case .jsonEncodingFailed(let connId):
            return "Failed to encode connection '\(connId)' to JSON"
        case .jsonDecodingFailed(let connId, let line):
            return "Failed to decode JSON for connection '\(connId)' at line \(line)"
        case .encryptionFailed(let connId):
            return "Failed to encrypt connection '\(connId)'"
        case .decryptionFailed(let connId, let line):
            return "Failed to decrypt connection '\(connId)' at line \(line). Check Fernet key."
        case .noConnectionsFound:
            return "No valid connections found in CSV file"
        case .fileReadError(let error):
            return "Failed to read CSV file: \(error.localizedDescription)"
        }
    }
}
