// File: ContentView.swift
// Purpose: Main container view with tab navigation
// Provides access to Export, Import, and Settings views

import SwiftUI

/// Main content view with tabbed interface
struct ContentView: View {
    var body: some View {
        TabView {
            // MARK: - Export Tab
            ExportView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(0)
            
            // MARK: - Import Tab
            ImportView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .tag(1)
            
            // MARK: - Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        // CHANGED: Set frame with ideal size instead of min/max constraints
        // This allows the window to be resized while suggesting a good default size
        .frame(idealWidth: 900, idealHeight: 800)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
