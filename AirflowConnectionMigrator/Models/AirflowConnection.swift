// File: Models/AirflowConnection.swift
// Purpose: Represents an Airflow connection record from the database
// Matches the structure of Airflow's public.connection table

import Foundation

/// Represents a single connection record from Airflow's connection table
/// This mirrors the Python script's handling of connection data
struct AirflowConnection: Identifiable, Codable {
    /// Unique identifier - uses conn_id as the ID for SwiftUI list management
    var id: String { conn_id }

    /// Connection ID - the unique identifier in Airflow (e.g., "aws_default", "postgres_prod")
    var conn_id: String

    /// Connection type (e.g., "postgres", "aws", "google_cloud_platform")
    var conn_type: String?

    /// Optional description of what this connection is used for
    var description: String?

    /// Host address for the connection
    var host: String?

    /// Database schema name
    var schema: String?

    /// Login/username for the connection
    var login: String?

    /// Password for the connection (will be encrypted)
    var password: String?

    /// Port number for the connection
    var port: Int?

    /// Flag indicating if the password field is encrypted in the database
    /// When true, password needs to be decrypted when reading and encrypted when writing
    var is_encrypted: Bool

    /// Flag indicating if the extra field is encrypted in the database
    /// When true, extra needs to be decrypted when reading and encrypted when writing
    var is_extra_encrypted: Bool

    /// Extra configuration as JSON string (can contain additional connection parameters)
    var extra: String?

    /// UI state property - not stored in database
    /// Used in checkbox lists to track if this connection is selected for export/import
    var isSelected: Bool = false

    // MARK: - Initialization

    /// Creates a new Airflow connection with required fields
    init(
        conn_id: String,
        conn_type: String? = nil,
        description: String? = nil,
        host: String? = nil,
        schema: String? = nil,
        login: String? = nil,
        password: String? = nil,
        port: Int? = nil,
        is_encrypted: Bool = true,
        is_extra_encrypted: Bool = true,
        extra: String? = nil,
        isSelected: Bool = false
    ) {
        self.conn_id = conn_id
        self.conn_type = conn_type
        self.description = description
        self.host = host
        self.schema = schema
        self.login = login
        self.password = password
        self.port = port
        self.is_encrypted = is_encrypted
        self.is_extra_encrypted = is_extra_encrypted
        self.extra = extra
        self.isSelected = isSelected
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case conn_id, conn_type, description, host, schema, login, password, port
        case is_encrypted, is_extra_encrypted, extra
        // Note: isSelected is NOT encoded/decoded - it's UI state only
    }

    // MARK: - Helper Methods

    /// Returns a display string with the connection's basic info
    /// - Returns: Formatted string like "aws_default (aws) - AWS Production Account"
    func displayName() -> String {
        var parts: [String] = [conn_id]

        if let type = conn_type {
            parts.append("(\(type))")
        }

        if let desc = description, !desc.isEmpty {
            parts.append("- \(desc)")
        }

        return parts.joined(separator: " ")
    }

    /// Checks if this connection has any sensitive data that needs encryption
    /// - Returns: true if password or extra fields contain data
    func hasSensitiveData() -> Bool {
        return (password != nil && !password!.isEmpty) ||
               (extra != nil && !extra!.isEmpty)
    }

    /// Creates a copy of this connection with a new conn_id (useful for prefixing)
    /// - Parameter newConnId: The new connection ID to use
    /// - Returns: A new AirflowConnection with the updated conn_id
    func withNewConnId(_ newConnId: String) -> AirflowConnection {
        return AirflowConnection(
            conn_id: newConnId,
            conn_type: conn_type,
            description: description,
            host: host,
            schema: schema,
            login: login,
            password: password,
            port: port,
            is_encrypted: is_encrypted,
            is_extra_encrypted: is_extra_encrypted,
            extra: extra,
            isSelected: isSelected
        )
    }

    // MARK: - JSON Conversion

    /// Converts this connection to a JSON string for file encryption
    /// Used when exporting connections to CSV
    /// - Returns: JSON string representation or nil if encoding fails
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys // Consistent output

        guard let data = try? encoder.encode(self),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }

    /// Creates an AirflowConnection from a JSON string
    /// Used when importing connections from CSV
    /// - Parameter jsonString: JSON string to decode
    /// - Returns: Decoded AirflowConnection or nil if decoding fails
    static func fromJSONString(_ jsonString: String) -> AirflowConnection? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(AirflowConnection.self, from: data)
    }
}

// MARK: - Sample Data (for testing/preview)

extension AirflowConnection {
    /// Returns sample connections for testing and SwiftUI previews
    static var sampleConnections: [AirflowConnection] {
        return [
            AirflowConnection(
                conn_id: "postgres_default",
                conn_type: "postgres",
                description: "Default PostgreSQL connection",
                host: "localhost",
                schema: "public",
                login: "airflow",
                password: "airflow",
                port: 5432,
                is_encrypted: true,
                is_extra_encrypted: false,
                extra: nil
            ),
            AirflowConnection(
                conn_id: "aws_default",
                conn_type: "aws",
                description: "AWS Production Account",
                host: nil,
                schema: nil,
                login: nil,
                password: nil,
                port: nil,
                is_encrypted: true,
                is_extra_encrypted: true,
                extra: "{\"region_name\": \"us-east-1\"}"
            ),
            AirflowConnection(
                conn_id: "http_api",
                conn_type: "http",
                description: "External API endpoint",
                host: "api.example.com",
                schema: nil,
                login: "api_user",
                password: "secret_token",
                port: 443,
                is_encrypted: true,
                is_extra_encrypted: false,
                extra: nil
            )
        ]
    }
}
