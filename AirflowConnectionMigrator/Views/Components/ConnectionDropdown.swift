// File: Views/Components/ConnectionDropdown.swift
// Purpose: Reusable dropdown for selecting connection profiles
// Used in Export, Import, and Settings views

import SwiftUI

/// Dropdown picker for selecting a connection profile
/// Shows profile name and connection string
struct ConnectionDropdown: View {
    /// The currently selected profile
    @Binding var selectedProfile: ConnectionProfile?
    
    /// All available profiles to choose from
    let profiles: [ConnectionProfile]
    
    /// Dummy uuid for the dropdown placeholder
    private let placeholderUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    
    /// Optional callback when selection changes
    var onSelectionChange: ((ConnectionProfile?) -> Void)?
    
    var body: some View {
        HStack {
            Text("Connection:")
                .frame(width: 100, alignment: .trailing)
            
            if profiles.isEmpty {
                Text("No profiles available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Picker("", selection: Binding(
                    get: { selectedProfile?.id ?? placeholderUUID },
                    set: { newId in
                        if newId != placeholderUUID {  // Ignore placeholder selection
                            selectedProfile = profiles.first { $0.id == newId }
                            onSelectionChange?(selectedProfile)
                        }
                    }
                )) {
                    // Optional "Select..." placeholder
                    Text("Select a profile...")
                        .tag(placeholderUUID)
                    
                    // Profile options
                    ForEach(profiles) { profile in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.body)
                            Text(profile.connectionString())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(profile.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ConnectionDropdown(
            selectedProfile: .constant(nil),
            profiles: [
                ConnectionProfile(name: "Local Dev", host: "127.0.0.1", port: 5432, database: "postgres", username: "postgres"),
                ConnectionProfile(name: "Staging", host: "staging.example.com", port: 5432, database: "airflow", username: "admin"),
                ConnectionProfile(name: "Production", host: "prod.example.com", port: 5432, database: "airflow", username: "admin")
            ]
        )
        
        ConnectionDropdown(
            selectedProfile: .constant(nil),
            profiles: []
        )
    }
    .padding()
    .frame(width: 500)
}
