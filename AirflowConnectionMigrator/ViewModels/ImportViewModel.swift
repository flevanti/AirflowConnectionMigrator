// File: ViewModels/ImportViewModel.swift
// Purpose: Manages the state and logic for the Import view
// Handles file loading, decryption, connection selection, and database import

import Combine
import Foundation
import SwiftFernet
import SwiftUI

/// ViewModel for the Import view
/// Manages the import workflow from encrypted CSV file to database
@MainActor
class ImportViewModel: ObservableObject {

    // MARK: - Published Properties (trigger UI updates)

    /// File path to the CSV file to import
    @Published var importFilePath: String = "" {
        didSet {
            // Clear loaded connections when file path changes
            if importFilePath != oldValue && !loadedConnections.isEmpty {
                loadedConnections.removeAll()
                logger.info("Cleared connections due to file path change")
            }
        }
    }

    /// Fernet key for decrypting the import file
    @Published var fileDecryptionKey: String = ""

    /// Connections loaded from file
    @Published var loadedConnections: [AirflowConnection] = []

    /// Selected connection profile for target database
    @Published var selectedProfile: ConnectionProfile?

    /// Collision handling strategy
    @Published var collisionStrategy: CollisionStrategy = .default

    /// Loading state flags
    @Published var isLoadingFile = false
    @Published var isImporting = false
    @Published var isTestingConnection = false
    @Published var isCheckingCollisions = false

    /// Logger for displaying progress in UI
    @Published var logger = Logger()

    /// Alert state
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    /// Confirmation dialog state
    @Published var showConfirmation = false
    @Published var confirmationTitle = ""
    @Published var confirmationMessage = ""
    private var confirmationAction: (() -> Void)?

    // MARK: - Computed Properties

    /// Returns only the selected connections
    var selectedConnections: [AirflowConnection] {
        return loadedConnections.filter { $0.isSelected }
    }

    /// Returns count of selected connections
    var selectedCount: Int {
        return selectedConnections.count
    }

    /// Checks if import can proceed
    var canImport: Bool {
        return !selectedConnections.isEmpty && selectedProfile != nil && !selectedProfile!.fernetKey.isEmpty
    }

    /// Checks if file can be loaded
    var canLoadFile: Bool {
        return !importFilePath.isEmpty && !fileDecryptionKey.isEmpty && SwiftFernet.isValidKey(fileDecryptionKey)
    }


    // MARK: - Connection Testing

    /// Tests the database connection
    func testConnection() async {
        guard let profile = selectedProfile else {
            showError("No Profile Selected", "Please select a connection profile first.")
            return
        }

        guard !profile.fernetKey.isEmpty else {
            showError("Missing Fernet Key", "The selected profile doesn't have a Fernet key configured.")
            return
        }

        guard SwiftFernet.isValidKey(profile.fernetKey) else {
            showError("Invalid Fernet Key", "The Fernet key in the profile is invalid.")
            return
        }

        isTestingConnection = true
        logger.info("Testing connection to \(profile.name)...")

        let result = await DatabaseService.testConnection(profile)

        isTestingConnection = false

        switch result {
        case .success(let message):
            logger.success("✓ \(message)")
            showSuccess("Connection Successful", message)
        case .failure(let error):
            logger.error("✗ Connection failed: \(error.localizedDescription)")
            showError("Connection Failed", error.localizedDescription)
        }
    }

    // MARK: - Load File

    /// Loads and decrypts connections from the CSV file
    func loadFile() async {
        guard canLoadFile else {
            showError("Cannot Load File", "Please provide a valid file path and decryption key.")
            return
        }

        let fileURL = URL(fileURLWithPath: importFilePath)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: importFilePath) else {
            showError("File Not Found", "The specified file does not exist:\n\(importFilePath)")
            return
        }

        isLoadingFile = true
        logger.section("Loading Connections from File")
        logger.info("File: \(fileURL.lastPathComponent)")
        logger.info("Decrypting with provided file encryption key...")

        let result = await CSVService.importConnections(from: fileURL, fernetKey: fileDecryptionKey)

        isLoadingFile = false

        switch result {
        case .success(let connections):
            loadedConnections = connections
            // Select all by default
            for index in loadedConnections.indices {
                loadedConnections[index].isSelected = true
            }

            logger.success("✓ Loaded \(connections.count) connection(s) from file")

            // Log each connection
            for conn in connections {
                logger.info("  - \(conn.conn_id) (\(conn.conn_type ?? "unknown"))")
            }

        case .failure(let error):
            logger.error("✗ Failed to load file: \(error.localizedDescription)")
            showError("Load Failed", error.localizedDescription)
        }
    }

    // MARK: - Selection Management

    /// Selects all connections
    func selectAll() {
        for index in loadedConnections.indices {
            loadedConnections[index].isSelected = true
        }
        logger.info("Selected all \(loadedConnections.count) connections")
    }

    /// Deselects all connections
    func deselectAll() {
        for index in loadedConnections.indices {
            loadedConnections[index].isSelected = false
        }
        logger.info("Deselected all connections")
    }

    /// Toggles selection for a specific connection
    /// - Parameter connection: The connection to toggle
    func toggleSelection(for connection: AirflowConnection) {
        guard let index = loadedConnections.firstIndex(where: { $0.id == connection.id }) else {
            return
        }
        loadedConnections[index].isSelected.toggle()
    }

    // MARK: - Import Operation

    /// Initiates the import process with confirmation
    func initiateImport() {
        guard canImport else {
            showError("Cannot Import", "Please ensure you have selected connections and a target profile.")
            return
        }

        // Show confirmation dialog
        confirmationTitle = "Confirm Import"
        confirmationMessage = collisionStrategy.confirmationMessage(connectionCount: selectedCount)
        confirmationAction = {
            Task {
                await self.performImport()
            }
        }
        showConfirmation = true
    }

    /// Performs the actual import operation
    private func performImport() async {
        guard let profile = selectedProfile else {
            return
        }

        isImporting = true
        logger.section("Starting Import Operation")
        logger.info("Importing \(selectedCount) connection(s) to: \(profile.name)")
        logger.info("Collision strategy: \(collisionStrategy.rawValue)")

        // Check for existing connection IDs
        logger.info("Checking for existing connection IDs in target database...")
        isCheckingCollisions = true

        let connectionIds = selectedConnections.map { $0.conn_id }
        let checkResult = await DatabaseService.checkExistingConnections(in: profile, connectionIds: connectionIds)

        isCheckingCollisions = false

        switch checkResult {
        case .success(let existingIds):
            if !existingIds.isEmpty {
                logger.warning("Found \(existingIds.count) existing connection ID(s):")
                for id in existingIds {
                    logger.warning("  - \(id)")
                }

                // Handle based on collision strategy
                await handleCollisions(existingIds: existingIds, profile: profile)
            } else {
                logger.success("✓ No collisions detected")
                // Proceed with insert
                await insertAllConnections(profile: profile)
            }

        case .failure(let error):
            isImporting = false
            logger.error("✗ Failed to check existing connections: \(error.localizedDescription)")
            showError("Check Failed", error.localizedDescription)
        }
    }

    /// Handles connection ID collisions based on selected strategy
    private func handleCollisions(existingIds: [String], profile: ConnectionProfile) async {
        switch collisionStrategy {
        case .stopCompletely:
            // Stop the import
            isImporting = false
            logger.error("✗ Import stopped due to existing connection IDs")
            showError(
                "Import Stopped",
                "The following connection IDs already exist:\n\(existingIds.joined(separator: ", "))\n\nNo connections were imported."
            )

        case .skipExisting:
            // Filter out existing connections and import the rest
            let connectionsToImport = selectedConnections.filter { !existingIds.contains($0.conn_id) }

            if connectionsToImport.isEmpty {
                isImporting = false
                logger.warning("All selected connections already exist. Nothing to import.")
                showError("Nothing to Import", "All selected connections already exist in the target database.")
            } else {
                logger.info("Skipping \(existingIds.count) existing connection(s)")
                logger.info("Importing \(connectionsToImport.count) new connection(s)")
                await insertConnections(connectionsToImport, profile: profile)
            }

        case .overwrite:
            // Separate connections into insert and update groups
            let connectionsToUpdate = selectedConnections.filter { existingIds.contains($0.conn_id) }
            let connectionsToInsert = selectedConnections.filter { !existingIds.contains($0.conn_id) }

            logger.info("Updating \(connectionsToUpdate.count) existing connection(s)")
            logger.info("Inserting \(connectionsToInsert.count) new connection(s)")

            // CHANGED: Track counts for final summary
            var updatedCount = 0
            var insertedCount = 0

            // Update existing connections
            if !connectionsToUpdate.isEmpty {
                let updateResult = await updateConnections(connectionsToUpdate, profile: profile)
                if let count = updateResult {
                    updatedCount = count
                } else {
                    // Update failed, stop here
                    return
                }
            }

            // Insert new connections
            if !connectionsToInsert.isEmpty {
                let insertResult = await insertConnections(connectionsToInsert, profile: profile, completeAfter: false)
                if let count = insertResult {
                    insertedCount = count
                } else {
                    // Insert failed, stop here
                    return
                }
            }

            // CHANGED: Complete import with both counts
            completeImport(insertedCount: insertedCount, updatedCount: updatedCount)
        }
    }

    /// Inserts all selected connections
    private func insertAllConnections(profile: ConnectionProfile) async {
        await insertConnections(selectedConnections, profile: profile)
    }

    /// Inserts specific connections into the database
    /// - Parameters:
    ///   - connections: Connections to insert
    ///   - profile: Target profile
    ///   - completeAfter: Whether to call completeImport after insertion (default: true)
    /// - Returns: Number of inserted connections, or nil if failed
    @discardableResult
    private func insertConnections(_ connections: [AirflowConnection], profile: ConnectionProfile, completeAfter: Bool = true) async -> Int? {
        logger.info("Inserting \(connections.count) connection(s)...")

        let result = await DatabaseService.insertConnections(
            connections,
            into: profile,
            fernetKey: profile.fernetKey
        )

        switch result {
        case .success(let count):
            logger.success("✓ Successfully inserted \(count) connection(s)")

            // Complete import if this is the only operation
            if completeAfter {
                completeImport(insertedCount: count, updatedCount: 0)
            }

            return count

        case .failure(let error):
            isImporting = false
            logger.error("✗ Insert failed: \(error.localizedDescription)")
            showError("Insert Failed", error.localizedDescription)
            return nil
        }
    }

    /// Updates specific connections in the database
    /// - Returns: Number of updated connections, or nil if failed
    @discardableResult
    private func updateConnections(_ connections: [AirflowConnection], profile: ConnectionProfile) async -> Int? {
        logger.info("Updating \(connections.count) connection(s)...")

        let result = await DatabaseService.updateConnections(
            connections,
            in: profile,
            fernetKey: profile.fernetKey
        )

        switch result {
        case .success(let count):
            logger.success("✓ Successfully updated \(count) connection(s)")
            return count

        case .failure(let error):
            isImporting = false
            logger.error("✗ Update failed: \(error.localizedDescription)")
            showError("Update Failed", error.localizedDescription)
            return nil
        }
    }

    /// Completes the import operation
    private func completeImport(insertedCount: Int, updatedCount: Int) {
        isImporting = false
        logger.separator()
        logger.success("✓ Import completed successfully!")

        var message = ""
        if insertedCount > 0 {
            message += "Inserted: \(insertedCount) connection(s)\n"
        }
        if updatedCount > 0 {
            message += "Updated: \(updatedCount) connection(s)\n"
        }

        showSuccess("Import Successful", message)
    }

    // MARK: - Profile Selection

    /// Updates the selected profile
    /// - Parameter profile: The newly selected profile
    func selectProfile(_ profile: ConnectionProfile?) {
        selectedProfile = profile

        if let profile = profile {
            logger.info("Selected profile: \(profile.name)")
        }
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

    /// Executes the pending confirmation action
    func confirmAction() {
        confirmationAction?()
        confirmationAction = nil
    }
}
