// File: AirflowConnectionMigratorApp.swift
// Purpose: Main app entry point
// Configures the SwiftUI app and window

import SwiftUI

/// Main application structure
@main
struct AirflowConnectionMigratorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // CHANGED: Remove windowStyle and windowResizability to allow proper resizing
        // The default titlebar style works better with resizing
        .defaultSize(width: 900, height: 800)
        .commands {
            // Remove "New Window" command
            CommandGroup(replacing: .newItem) {}
        }
    }
}

/// Application delegate for handling app lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Quit app when main window is closed
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // CHANGED: Set minimum window size wider to prevent tab labels from disappearing
        if let window = NSApplication.shared.windows.first {
            window.minSize = NSSize(width: 950, height: 700)  // Increased minimum width
            window.maxSize = NSSize(width: 1400, height: 1200)
        }
    }
}
