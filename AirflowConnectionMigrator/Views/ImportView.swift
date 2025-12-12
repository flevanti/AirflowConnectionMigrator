// File: Views/ImportView.swift
// Purpose: Main view for importing Airflow connections from encrypted CSV
// Allows user to load file, select connections, choose collision strategy, and import

import SwiftUI
import UniformTypeIdentifiers
import Combine

/// View for importing Airflow connections
struct ImportView: View {
    @StateObject private var viewModel = ImportViewModel()
    @ObservedObject private var profileService = ConnectionProfileService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - File Selection
            GroupBox(label: Text("Import File").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    // File path
                    HStack {
                        Text("File Path:")
                            .frame(width: 140, alignment: .trailing)
                        
                        TextField("Path to CSV file", text: $viewModel.importFilePath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            selectImportFile()
                        }
                    }
                    
                    // File decryption key
                    HStack(alignment: .center) {
                        Text("File Decryption Key:")
                            .frame(width: 140, alignment: .trailing)
                        
                        TextField("Fernet key used to encrypt the file", text: $viewModel.fileDecryptionKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Text("Enter the encryption key that was used when exporting this file.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 150)
                    
                    // Load button
                    HStack {
                        Spacer()
                        
                        Button {
                            Task {
                                await viewModel.loadFile()
                            }
                        } label: {
                            HStack {
                                if viewModel.isLoadingFile {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                                Text(viewModel.isLoadingFile ? "Loading..." : "Load File")
                            }
                        }
                        .disabled(!viewModel.canLoadFile || viewModel.isLoadingFile)
                    }
                }
                .padding(8)
            }
            .frame(height: 150)
            
            // MARK: - Connection Selection List (always visible)
            GroupBox(label: HStack {
                Text("Select Connections to Import").font(.headline)
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
                        .disabled(viewModel.loadedConnections.isEmpty)
                        
                        Button("Deselect All") {
                            viewModel.deselectAll()
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.loadedConnections.isEmpty)
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Connection list (or empty state)
                    if viewModel.loadedConnections.isEmpty {
                        VStack {
                            Spacer()
                            Text("No connections loaded")
                                .foregroundColor(.secondary)
                                .italic()
                            Text("Load a CSV file to see connections")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(viewModel.loadedConnections) { connection in  // No $ binding
                                    ConnectionListItem(
                                        connection: connection,
                                        isSelected: Binding(
                                            get: {
                                                viewModel.loadedConnections.first(where: { $0.id == connection.id })?.isSelected ?? false
                                            },
                                            set: { newValue in
                                                if let index = viewModel.loadedConnections.firstIndex(where: { $0.id == connection.id }) {
                                                    viewModel.loadedConnections[index].isSelected = newValue
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
            .frame(height: 180)
            
            // MARK: - Target Database
            GroupBox(label: Text("Target Database").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    ConnectionDropdown(
                        selectedProfile: $viewModel.selectedProfile,
                        profiles: profileService.profiles,
                        onSelectionChange: { profile in
                            viewModel.selectProfile(profile)
                        }
                    )
                }
                .padding(8)
            }
            .frame(height: 70)
            
            // MARK: - Collision Strategy
            GroupBox(label: Text("Collision Handling").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Strategy:")
                            .frame(width: 100, alignment: .trailing)
                        
                        Picker("", selection: $viewModel.collisionStrategy) {
                            ForEach(CollisionStrategy.allCases) { strategy in
                                Text(strategy.rawValue).tag(strategy)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Show description for selected strategy
                    Text(viewModel.collisionStrategy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 100)
                }
                .padding(8)
            }
            
            // MARK: - Import Button
            Button {
                viewModel.initiateImport()
            } label: {
                HStack {
                    if viewModel.isImporting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Text(viewModel.isImporting ? "Importing..." : "Import Connections")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canImport || viewModel.isImporting)
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
        .confirmationDialog(
            viewModel.confirmationTitle,
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Proceed", role: .destructive) {
                viewModel.confirmAction()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.confirmationMessage)
        }
    }
    
    // MARK: - File Selection
    
    /// Opens a panel to select import file
    private func selectImportFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.message = "Select CSV file to import"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                viewModel.importFilePath = url.path
            }
        }
    }
}

// MARK: - Radio Button Component

/// Custom radio button for collision strategy selection
struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ImportView()
        .frame(width: 900, height: 800)
}
