// File: Views/Components/ConnectionListItem.swift
// Purpose: Checkbox list item for displaying and selecting Airflow connections
// Used in Export and Import views for connection selection

import SwiftUI

/// A selectable list item for an Airflow connection
/// Shows checkbox, connection ID, type, and description
struct ConnectionListItem: View {
    /// The connection to display
    let connection: AirflowConnection
    
    /// Whether this connection is selected
    @Binding var isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Toggle("", isOn: $isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
            
            // Connection icon (based on type)
            Image(systemName: iconForConnectionType(connection.conn_type))
                .foregroundColor(colorForConnectionType(connection.conn_type))
                .frame(width: 20)
            
            // Connection details
            VStack(alignment: .leading, spacing: 4) {
                // Connection ID
                Text(connection.conn_id)
                    .font(.body)
                    .fontWeight(.medium)
                
                // Type and description (if available)
                HStack(spacing: 8) {
                    if let type = connection.conn_type {
                        Text(type)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if let description = connection.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Host info (if available)
            if let host = connection.host {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(host)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let port = connection.port {
                        Text(":\(port)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            isSelected.toggle()
        }
    }
    
    /// Returns an SF Symbol icon name based on connection type
    private func iconForConnectionType(_ type: String?) -> String {
        guard let type = type?.lowercased() else {
            return "link.circle"
        }
        
        switch type {
        case "postgres", "postgresql":
            return "cylinder.fill"
        case "mysql":
            return "cylinder.fill"
        case "aws", "snowflake":
            return "snowflake"
        default:
            return "link.circle"
        }
    }
    
    /// Returns a color based on connection type
    private func colorForConnectionType(_ type: String?) -> Color {
        guard let type = type?.lowercased() else {
            return .gray
        }
        
        switch type {
        case "postgres", "postgresql":
            return .blue
        case "mysql":
            return .orange
        case "snowflake":
            return .blue
        default:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        ConnectionListItem(
            connection: AirflowConnection(
                conn_id: "postgres_default",
                conn_type: "postgres",
                description: "Default PostgreSQL connection",
                host: "localhost",
                port: 5432
            ),
            isSelected: .constant(true)
        )
        
        ConnectionListItem(
            connection: AirflowConnection(
                conn_id: "aws_prod",
                conn_type: "aws",
                description: "Production AWS account with S3 and EC2 access"
            ),
            isSelected: .constant(false)
        )
        
        ConnectionListItem(
            connection: AirflowConnection(
                conn_id: "http_api",
                conn_type: "http",
                host: "api.example.com",
                port: 443
            ),
            isSelected: .constant(false)
        )
    }
    .padding()
    .frame(width: 600)
}
