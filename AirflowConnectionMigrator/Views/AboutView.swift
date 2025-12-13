// File: Views/AboutView.swift
// Purpose: About window showing app information and links

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon (you can replace with your actual icon)
            Image(systemName: "airplane.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            // App Name
            Text(AppConstants.appName)
                .font(.title)
                .fontWeight(.bold)
            
            // Version
            Text("Version \(AppConstants.appVersion) (Build \(AppConstants.buildNumber))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Description
            Text(AppConstants.appDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            // Links
            VStack(spacing: 12) {
                Link("📖 View on GitHub", destination: URL(string: AppConstants.githubRepoURL)!)
                    .font(.body)
                
                Link("🐛 Report an Issue", destination: URL(string: AppConstants.githubIssuesURL)!)
                    .font(.body)
                
                Link("✉️ Contact Developer", destination: URL(string: AppConstants.supportEmailURL)!)
                    .font(.body)
            }
            .padding(.vertical, 10)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Copyright
            Text(AppConstants.copyright)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Licensed under \(AppConstants.license)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Close button
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.top, 10)
        }
        .padding(30)
        .frame(width: 450)
    }
}

#Preview {
    AboutView()
}
