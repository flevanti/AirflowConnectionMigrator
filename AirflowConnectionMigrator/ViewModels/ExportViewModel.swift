// File: ViewModels/ExportViewModel.swift
// Purpose: Manages the state and logic for the Export view
// Handles connection fetching, selection, encryption, and CSV export

import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import SwiftFernet


/// ViewModel for the Export view
/// Manages the export workflow from database to encrypted CSV file
@MainActor
class ExportViewModel: ObservableObject {
    
    // MARK: - Published Properties (trigger UI updates)
    
    /// Selected connection profile for source database
    @Published var selectedProfile: ConnectionProfile?
    
    /// All available connections from the database
    @Published var availableConnections: [AirflowConnection] = []
    
    /// Prefix to add to connection IDs during export (prevents collisions)
    @Published var connectionIdPrefix: String = ""
    
    /// Fernet key for encrypting the export file
    @Published var fileEncryptionKey: String = ""
    
    /// File path for export (without filename) - for display only
    @Published var exportPath: String = ""
    
    /// Filename for export (without path)
    @Published var exportFilename: String = ""
    
    /// Loading state flags
    @Published var isLoadingConnections = false
    @Published var isExporting = false
    @Published var isTestingConnection = false
    
    /// Logger for displaying progress in UI
    @Published var logger = Logger()
    
    /// Alert state
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    // MARK: - Computed Properties
    
    /// Returns only the selected connections
    var selectedConnections: [AirflowConnection] {
        return availableConnections.filter { $0.isSelected }
    }
    
    /// Returns count of selected connections
    var selectedCount: Int {
        return selectedConnections.count
    }
    
    /// Checks if export can proceed (has selections and required fields)
    var canExport: Bool {
        return !selectedConnections.isEmpty &&
               !fileEncryptionKey.isEmpty &&
        SwiftFernet.isValidKey(fileEncryptionKey)
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize with default settings
        let settings = AppSettings.shared
        self.exportPath = settings.defaultExportPath
        
        // Generate default filename (will be updated when profile is selected)
        self.exportFilename = "airflow_connections_\(Self.timestamp()).csv"
    }
    
    // MARK: - Connection Testing
    
    /// Tests the database connection
    func testConnection() async {
        guard let profile = selectedProfile else {
            showError("No Profile Selected", "Please select a connection profile first.")
            return
        }
        
        // Validate Fernet key
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
    
    // MARK: - Load Connections
    
    /// Loads all connections from the selected database
    func loadConnections() async {
        guard let profile = selectedProfile else {
            showError("No Profile Selected", "Please select a connection profile first.")
            return
        }
        
        guard !profile.fernetKey.isEmpty else {
            showError("Missing Fernet Key", "The selected profile doesn't have a Fernet key configured.")
            return
        }
        
        isLoadingConnections = true
        logger.section("Loading Connections from Database")
        logger.info("Connecting to: \(profile.connectionString())")
        
        let result = await DatabaseService.fetchConnections(from: profile, fernetKey: profile.fernetKey)
        
        isLoadingConnections = false
        
        switch result {
        case .success(let connections):
            availableConnections = connections
            logger.success("✓ Loaded \(connections.count) connection(s)")
            
            // Log each connection
            for conn in connections {
                logger.info("  - \(conn.conn_id) (\(conn.conn_type ?? "unknown"))")
            }
            
        case .failure(let error):
            logger.error("✗ Failed to load connections: \(error.localizedDescription)")
            showError("Load Failed", "Could not load connections from database: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Selection Management
    
    /// Selects all connections
    func selectAll() {
        for index in availableConnections.indices {
            availableConnections[index].isSelected = true
        }
        logger.info("Selected all \(availableConnections.count) connections")
    }
    
    /// Deselects all connections
    func deselectAll() {
        for index in availableConnections.indices {
            availableConnections[index].isSelected = false
        }
        logger.info("Deselected all connections")
    }
    
    /// Toggles selection for a specific connection
    /// - Parameter connection: The connection to toggle
    func toggleSelection(for connection: AirflowConnection) {
        guard let index = availableConnections.firstIndex(where: { $0.id == connection.id }) else {
            return
        }
        availableConnections[index].isSelected.toggle()
    }
    
    // MARK: - Fernet Key Management
    
    /// Generates a new random Fernet key for file encryption
    func generateFileEncryptionKey() {
        fileEncryptionKey = SwiftFernet.generateKey()
        logger.info("Generated new file encryption key")
    }
    
    /// Copies the file encryption key to clipboard
    func copyFileEncryptionKeyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fileEncryptionKey, forType: .string)
        logger.info("File encryption key copied to clipboard")
    }
    
    // MARK: - Export Operation
    
    /// Shows a save panel and performs the export
    func performExportWithSavePanel() {
        // Validation
        guard canExport else {
            showError("Cannot Export", "Please ensure you have selected connections and provided a valid encryption key.")
            return
        }
        
        // Validate prefix length
        if connectionIdPrefix.count > 10 {
            showError("Prefix Too Long", "Connection ID prefix must be 10 characters or less.")
            return
        }
        
        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Export Airflow Connections"
        savePanel.message = "Choose where to save the encrypted connections file"
        savePanel.nameFieldStringValue = exportFilename
        
        // Set default directory if valid
        if !exportPath.isEmpty {
            savePanel.directoryURL = URL(fileURLWithPath: exportPath)
        }
        
        // Show panel and handle response
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                // Update the display path
                self.exportPath = url.deletingLastPathComponent().path
                self.exportFilename = url.lastPathComponent
                
                // Perform export to selected location
                Task {
                    await self.performExport(to: url)
                }
            }
        }
    }
    
    /// Performs the actual export operation to a specific URL
    private func performExport(to fileURL: URL) async {
        // REMOVED: Redundant guard - canExport already validates everything needed
        
        isExporting = true
        logger.section("Starting Export Operation")
        logger.info("Exporting \(selectedCount) connection(s)")
        logger.info("Export file: \(fileURL.path)")
        
        // Apply prefix to connection IDs if specified
        var connectionsToExport = selectedConnections
        if !connectionIdPrefix.isEmpty {
            logger.info("Applying prefix '\(connectionIdPrefix)' to connection IDs")
            connectionsToExport = connectionsToExport.map { conn in
                var modifiedConn = conn
                modifiedConn.conn_id = "\(connectionIdPrefix)\(conn.conn_id)"
                return modifiedConn
            }
        }
        
        // Export to CSV with file encryption
        logger.info("Encrypting connections with file encryption key...")
        let result = await CSVService.exportConnections(
            connectionsToExport,
            to: fileURL,
            fernetKey: fileEncryptionKey
        )
        
        isExporting = false
        
        switch result {
        case .success(let url):
            logger.success("✓ Export completed successfully!")
            logger.info("File saved to: \(url.path)")
            logger.separator()
            logger.warning("⚠️ IMPORTANT: Save the file encryption key to share with the import destination:")
            logger.info("File Encryption Key: \(fileEncryptionKey)")
            logger.separator()
            
            showSuccess(
                "Export Successful",
                "Exported \(selectedCount) connection(s) to:\n\(url.path)\n\nDon't forget to share the file encryption key with the recipient!"
            )
            
        case .failure(let error):
            logger.error("✗ Export failed: \(error.localizedDescription)")
            showError("Export Failed", error.localizedDescription)
        }
    }
    
    // MARK: - Profile Selection
    
    /// Updates the selected profile and regenerates filename
    /// - Parameter profile: The newly selected profile
    func selectProfile(_ profile: ConnectionProfile?) {
        print("🔍 selectProfile called - old connections count: \(availableConnections.count)")
        
        // Clear loaded connections when changing profile - BEFORE updating selectedProfile
        availableConnections.removeAll()
        availableConnections=[]
        
        selectedProfile = profile
        
        if let profile = profile {
            let settings = AppSettings.shared
            exportFilename = settings.generateExportFilename(connectionName: profile.name)
            logger.info("Selected profile: \(profile.name)")
        }
        
        print("🔍 selectProfile - after clear, connections count: \(availableConnections.count)")
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
    
    // MARK: - Utility
    
    /// Returns current timestamp for filename
    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}
