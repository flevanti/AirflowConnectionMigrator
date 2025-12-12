// File: Views/ExportView.swift
// Purpose: Main view for exporting Airflow connections to encrypted CSV
// Allows user to select source DB, choose connections, and export to file

import SwiftUI
import Combine

/// View for exporting Airflow connections
struct ExportView: View {
    @StateObject private var viewModel = ExportViewModel()
    @ObservedObject private var profileService = ConnectionProfileService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Connection Selection
            GroupBox(label: Text("Source Database").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    ConnectionDropdown(
                        selectedProfile: $viewModel.selectedProfile,
                        profiles: profileService.profiles,
                        onSelectionChange: { profile in
                            viewModel.selectProfile(profile)
                        }
                    )
                    
                    // CHANGED: Removed Test Connection button - only in Settings
                    HStack {
                        Spacer()
                        
                        Button("Load Connections") {
                            Task {
                                await viewModel.loadConnections()
                            }
                        }
                        .disabled(viewModel.selectedProfile == nil || viewModel.isLoadingConnections)
                        
                        if viewModel.isLoadingConnections {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
                .padding(8)
            }
            .frame(height: 80)
            
            // MARK: - Connection Selection List (always visible)
            GroupBox(label: HStack {
                Text("Select Connections to Export").font(.headline)
                Spacer()
                Text("\(viewModel.selectedCount) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    // Select All / Deselect All buttons
                    HStack {
                        Button("Select All") {
                            viewModel.selectAll()
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.availableConnections.isEmpty)
                        
                        Button("Deselect All") {
                            viewModel.deselectAll()
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.availableConnections.isEmpty)
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Connection list (or empty state)
                    if viewModel.availableConnections.isEmpty {
                        VStack {
                            Spacer()
                            Text("No connections loaded")
                                .foregroundColor(.secondary)
                                .italic()
                            Text("Click 'Load Connections' to fetch from database")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(viewModel.availableConnections) { connection in  // ← No $ here
                                            ConnectionListItem(
                                                connection: connection,
                                                isSelected: Binding(
                                                    get: {
                                                        viewModel.availableConnections.first(where: { $0.id == connection.id })?.isSelected ?? false
                                                    },
                                                    set: { newValue in
                                                        if let index = viewModel.availableConnections.firstIndex(where: { $0.id == connection.id }) {
                                                            viewModel.availableConnections[index].isSelected = newValue
                                                        }
                                                    }
                                                )
                                            )
                                        }
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(height: 240)
            
            // MARK: - Export Options
            GroupBox(label: Text("Export Options").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    // Connection ID Prefix
                    HStack {
                        Text("ID Prefix:")
                            .frame(width: 140, alignment: .trailing)
                        
                        TextField("Optional (max 10 chars)", text: $viewModel.connectionIdPrefix)
                            .textFieldStyle(.roundedBorder)
                            .help("Add a prefix to connection IDs to prevent collisions during import")
                    }
                    
                    Divider()
                    
                    // File Encryption Key
                    HStack(alignment: .center) {
                        Text("File Encryption Key:")
                            .frame(width: 140, alignment: .trailing)
                        
                        TextField("Fernet key for encrypting export file", text: $viewModel.fileEncryptionKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        
                        Button("Generate") {
                            viewModel.generateFileEncryptionKey()
                        }
                        
                        Button {
                            viewModel.copyFileEncryptionKeyToClipboard()
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .help("Copy to clipboard")
                        .disabled(viewModel.fileEncryptionKey.isEmpty)
                    }
                    
                    Text("⚠️ Save this key! You'll need it to import this file.")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.leading, 150)
                }
                .padding(8)
            }
            .frame(height: 130)
            
            // MARK: - Export Button
            Button {
                // Use save panel instead of direct file write
                viewModel.performExportWithSavePanel()
            } label: {
                HStack {
                    if viewModel.isExporting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Text(viewModel.isExporting ? "Exporting..." : "Export Connections")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canExport || viewModel.isExporting)
            .frame(height: 40)
            
            // MARK: - Log Output
            LogTextView(logger: viewModel.logger)
        }
        .padding()
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK") {
                viewModel.showAlert = false
            }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

// MARK: - Preview

#Preview {
    ExportView()
        .frame(width: 900, height: 800)
}
