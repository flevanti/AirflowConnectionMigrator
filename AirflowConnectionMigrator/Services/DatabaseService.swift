// File: Services/DatabaseService.swift
// Purpose: Handles all PostgreSQL database operations for Airflow connections
// Connects to Airflow's metadata database to read and write connection records

import Foundation
import PostgresNIO
import SwiftFernet


/// Custom errors for database operations
enum DatabaseError: LocalizedError {
    case decryptionFailed(connId: String, field: String)
    case invalidFernetKey

    var errorDescription: String? {
        switch self {
        case .decryptionFailed(let connId, let field):
            return "Failed to decrypt '\(field)' for connection '\(connId)'. The Fernet key may be incorrect."
        case .invalidFernetKey:
            return "Invalid Fernet key format. Please check the key in your connection profile."
        }
    }
}

/// Service for interacting with Airflow's PostgreSQL metadata database
/// Handles connection testing, reading, and writing of Airflow connection records
class DatabaseService {

    // MARK: - Connection Testing

    /// Tests if a database connection is successful
    /// - Parameter profile: Connection profile with database credentials
    /// - Returns: Result with success message or error
    static func testConnection(_ profile: ConnectionProfile) async -> Result<String, Error> {
        do {
            // Create PostgreSQL configuration
            let config = PostgresConnection.Configuration(
                host: profile.host,
                port: profile.port,
                username: profile.username,
                password: profile.password,
                database: profile.database,
                tls: .disable  // Disable TLS for local connections (enable for production)
            )

            // Attempt to connect
            let connection = try await PostgresConnection.connect(
                configuration: config,
                id: 1,
                logger: .init(label: "test-connection")
            )

            // Execute a simple query to verify connection works
            let rows = try await connection.query("SELECT version()", logger: .init(label: "test-query"))

            // Close the connection
            try await connection.close()

            // Extract version string for confirmation
            var versionString = "Connection successful"
            for try await (version) in rows.decode(String.self) {
                versionString = "Connected to: \(version)"
                break
            }

            return .success(versionString)

        } catch {
            return .failure(error)
        }
    }

    // MARK: - Reading Connections

    /// Fetches all Airflow connections from the database
    /// - Parameters:
    ///   - profile: Connection profile for database access
    ///   - fernetKey: Fernet key to decrypt encrypted fields
    /// - Returns: Result with array of AirflowConnection or error
    static func fetchConnections(
        from profile: ConnectionProfile,
        fernetKey: String
    ) async -> Result<[AirflowConnection], Error> {
        do {
            // ADDED: Validate Fernet key format before attempting decryption
            guard SwiftFernet.isValidKey(fernetKey) else {
                return .failure(DatabaseError.invalidFernetKey)
            }

            // Create PostgreSQL configuration
            let config = PostgresConnection.Configuration(
                host: profile.host,
                port: profile.port,
                username: profile.username,
                password: profile.password,
                database: profile.database,
                tls: .disable
            )

            // Connect to database
            let connection = try await PostgresConnection.connect(
                configuration: config,
                id: 1,
                logger: .init(label: "fetch-connections")
            )

            // Query to fetch all connections
            let query = """
                SELECT conn_id, conn_type, description, host, schema, login,
                       password, port, is_encrypted, is_extra_encrypted, extra
                FROM public.connection
                ORDER BY conn_id
            """

            let rows = try await connection.query(
                PostgresQuery(unsafeSQL: query),
                logger: .init(label: "fetch-query")
            )

            var connections: [AirflowConnection] = []

            // Decode each row into an AirflowConnection
            for try await (conn_id, conn_type, description, host, schema, login, password, port, is_encrypted, is_extra_encrypted, extra) in rows.decode(
                (String, String?, String?, String?, String?, String?, String?, Int?, Bool, Bool, String?).self,
                context: .default
            ) {
                // CHANGED: Decrypt password if encrypted - FAIL if decryption fails
                var decryptedPassword = password
                if is_encrypted, let encryptedPassword = password, !encryptedPassword.isEmpty {
                    guard let decrypted = SwiftFernet.decrypt(encryptedPassword, withKey: fernetKey) else {
                        // Close connection before throwing error
                        try await connection.close()
                        throw DatabaseError.decryptionFailed(connId: conn_id, field: "password")
                    }
                    decryptedPassword = decrypted
                }

                // CHANGED: Decrypt extra if encrypted - FAIL if decryption fails
                var decryptedExtra = extra
                if is_extra_encrypted, let encryptedExtra = extra, !encryptedExtra.isEmpty {
                    guard let decrypted = SwiftFernet.decrypt(encryptedExtra, withKey: fernetKey) else {
                        // Close connection before throwing error
                        try await connection.close()
                        throw DatabaseError.decryptionFailed(connId: conn_id, field: "extra")
                    }
                    decryptedExtra = decrypted
                }

                // Create AirflowConnection object
                let connectionRecord = AirflowConnection(
                    conn_id: conn_id,
                    conn_type: conn_type,
                    description: description,
                    host: host,
                    schema: schema,
                    login: login,
                    password: decryptedPassword,
                    port: port,
                    is_encrypted: is_encrypted,
                    is_extra_encrypted: is_extra_encrypted,
                    extra: decryptedExtra
                )

                connections.append(connectionRecord)
            }

            // Close connection
            try await connection.close()

            return .success(connections)

        } catch {
            return .failure(error)
        }
    }

    // MARK: - Checking for Existing Connections

    /// Checks which connection IDs already exist in the database
    /// - Parameters:
    ///   - profile: Connection profile for database access
    ///   - connectionIds: Array of connection IDs to check
    /// - Returns: Result with array of existing connection IDs or error
    static func checkExistingConnections(
        in profile: ConnectionProfile,
        connectionIds: [String]
    ) async -> Result<[String], Error> {
        guard !connectionIds.isEmpty else {
            return .success([])
        }

        do {
            // Create PostgreSQL configuration
            let config = PostgresConnection.Configuration(
                host: profile.host,
                port: profile.port,
                username: profile.username,
                password: profile.password,
                database: profile.database,
                tls: .disable
            )

            // Connect to database
            let connection = try await PostgresConnection.connect(
                configuration: config,
                id: 1,
                logger: .init(label: "check-connections")
            )

            // Build parameterized query with placeholders
            let placeholders = connectionIds.enumerated().map { "$\($0.offset + 1)" }.joined(separator: ", ")
            let query = "SELECT conn_id FROM public.connection WHERE conn_id IN (\(placeholders))"

            // Create bindings array
            var bindings = PostgresBindings()
            for connId in connectionIds {
                bindings.append(connId)
            }

            // Execute query
            let rows = try await connection.query(
                PostgresQuery(unsafeSQL: query, binds: bindings),
                logger: .init(label: "check-query")
            )

            var existingIds: [String] = []

            // Collect existing connection IDs using tuple decoding
            for try await (connId) in rows.decode(String.self, context: .default) {
                existingIds.append(connId)
            }

            // Close connection
            try await connection.close()

            return .success(existingIds)

        } catch {
            return .failure(error)
        }
    }

    // MARK: - Inserting Connections

    /// Inserts new connections into the database
    /// - Parameters:
    ///   - connections: Array of connections to insert
    ///   - profile: Connection profile for database access
    ///   - fernetKey: Fernet key to encrypt sensitive fields
    /// - Returns: Result with success count or error
    static func insertConnections(
        _ connections: [AirflowConnection],
        into profile: ConnectionProfile,
        fernetKey: String
    ) async -> Result<Int, Error> {
        guard !connections.isEmpty else {
            return .success(0)
        }

        do {
            // ADDED: Validate Fernet key format before attempting encryption
            guard SwiftFernet.isValidKey(fernetKey) else {
                return .failure(DatabaseError.invalidFernetKey)
            }

            // Create PostgreSQL configuration
            let config = PostgresConnection.Configuration(
                host: profile.host,
                port: profile.port,
                username: profile.username,
                password: profile.password,
                database: profile.database,
                tls: .disable
            )

            // Connect to database
            let connection = try await PostgresConnection.connect(
                configuration: config,
                id: 1,
                logger: .init(label: "insert-connections")
            )

            // Insert query template
            let insertQuery = """
                INSERT INTO public.connection
                (conn_id, conn_type, description, host, schema, login, password, port, is_encrypted, is_extra_encrypted, extra)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            """

            var insertedCount = 0

            // Insert each connection
            for conn in connections {
                // CHANGED: Encrypt password if needed - FAIL if encryption fails
                var finalPassword = conn.password
                if conn.is_encrypted, let pwd = conn.password, !pwd.isEmpty {
                    guard let encrypted = SwiftFernet.encrypt(pwd, withKey: fernetKey) else {
                        try await connection.close()
                        throw DatabaseError.decryptionFailed(connId: conn.conn_id, field: "password (encryption)")
                    }
                    finalPassword = encrypted
                }

                // CHANGED: Encrypt extra if needed - FAIL if encryption fails
                var finalExtra = conn.extra
                if conn.is_extra_encrypted, let ext = conn.extra, !ext.isEmpty {
                    guard let encrypted = SwiftFernet.encrypt(ext, withKey: fernetKey) else {
                        try await connection.close()
                        throw DatabaseError.decryptionFailed(connId: conn.conn_id, field: "extra (encryption)")
                    }
                    finalExtra = encrypted
                }

                // Create bindings for this connection
                var bindings = PostgresBindings()
                bindings.append(conn.conn_id)
                bindings.append(conn.conn_type)
                bindings.append(conn.description)
                bindings.append(conn.host)
                bindings.append(conn.schema)
                bindings.append(conn.login)
                bindings.append(finalPassword)
                bindings.append(conn.port)
                bindings.append(conn.is_encrypted)
                bindings.append(conn.is_extra_encrypted)
                bindings.append(finalExtra)

                // Execute insert
                _ = try await connection.query(
                    PostgresQuery(unsafeSQL: insertQuery, binds: bindings),
                    logger: .init(label: "insert-query")
                )

                insertedCount += 1
            }

            // Close connection
            try await connection.close()

            return .success(insertedCount)

        } catch {
            return .failure(error)
        }
    }

    // MARK: - Updating Connections

    /// Updates existing connections in the database (for overwrite strategy)
    /// - Parameters:
    ///   - connections: Array of connections to update
    ///   - profile: Connection profile for database access
    ///   - fernetKey: Fernet key to encrypt sensitive fields
    /// - Returns: Result with success count or error
    static func updateConnections(
        _ connections: [AirflowConnection],
        in profile: ConnectionProfile,
        fernetKey: String
    ) async -> Result<Int, Error> {
        guard !connections.isEmpty else {
            return .success(0)
        }

        do {
            // ADDED: Validate Fernet key format before attempting encryption
            guard SwiftFernet.isValidKey(fernetKey) else {
                return .failure(DatabaseError.invalidFernetKey)
            }

            // Create PostgreSQL configuration
            let config = PostgresConnection.Configuration(
                host: profile.host,
                port: profile.port,
                username: profile.username,
                password: profile.password,
                database: profile.database,
                tls: .disable
            )

            // Connect to database
            let connection = try await PostgresConnection.connect(
                configuration: config,
                id: 1,
                logger: .init(label: "update-connections")
            )

            // Update query template
            let updateQuery = """
                UPDATE public.connection
                SET conn_type = $2, description = $3, host = $4, schema = $5, login = $6,
                    password = $7, port = $8, is_encrypted = $9, is_extra_encrypted = $10, extra = $11
                WHERE conn_id = $1
            """

            var updatedCount = 0

            // Update each connection
            for conn in connections {
                // CHANGED: Encrypt password if needed - FAIL if encryption fails
                var finalPassword = conn.password
                if conn.is_encrypted, let pwd = conn.password, !pwd.isEmpty {
                    guard let encrypted = SwiftFernet.encrypt(pwd, withKey: fernetKey) else {
                        try await connection.close()
                        throw DatabaseError.decryptionFailed(connId: conn.conn_id, field: "password (encryption)")
                    }
                    finalPassword = encrypted
                }

                // CHANGED: Encrypt extra if needed - FAIL if encryption fails
                var finalExtra = conn.extra
                if conn.is_extra_encrypted, let ext = conn.extra, !ext.isEmpty {
                    guard let encrypted = SwiftFernet.encrypt(ext, withKey: fernetKey) else {
                        try await connection.close()
                        throw DatabaseError.decryptionFailed(connId: conn.conn_id, field: "extra (encryption)")
                    }
                    finalExtra = encrypted
                }

                // Create bindings for this connection
                var bindings = PostgresBindings()
                bindings.append(conn.conn_id)  // WHERE clause
                bindings.append(conn.conn_type)
                bindings.append(conn.description)
                bindings.append(conn.host)
                bindings.append(conn.schema)
                bindings.append(conn.login)
                bindings.append(finalPassword)
                bindings.append(conn.port)
                bindings.append(conn.is_encrypted)
                bindings.append(conn.is_extra_encrypted)
                bindings.append(finalExtra)

                // Execute update
                _ = try await connection.query(
                    PostgresQuery(unsafeSQL: updateQuery, binds: bindings),
                    logger: .init(label: "update-query")
                )

                updatedCount += 1
            }

            // Close connection
            try await connection.close()

            return .success(updatedCount)

        } catch {
            return .failure(error)
        }
    }
}
