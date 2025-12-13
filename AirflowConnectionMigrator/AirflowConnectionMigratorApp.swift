// File: AirflowConnectionMigratorApp.swift
// Purpose: Main app entry point with menu commands

import SwiftUI

@main
struct AirflowConnectionMigratorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 900, height: 800)
        .commands {
            // Replace default About menu item
            CommandGroup(replacing: .appInfo) {
                Button("About Airflow Connection Migrator") {
                    showAboutWindow()
                }
                .keyboardShortcut("a", modifiers: [.command])
            }
            
            // Add Check for Updates menu item
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    Task {
                        await checkForUpdates()
                    }
                }
                
                Divider()
            }
            
            // Remove "New Window" command
            CommandGroup(replacing: .newItem) {}
        }
    }
    
    /// Show About window
    private func showAboutWindow() {
        let aboutView = AboutView()
        let hostingController = NSHostingController(rootView: aboutView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "About"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    /// Check for updates and show alert
    @MainActor
    private func checkForUpdates() async {
        let result = await UpdateChecker.checkForUpdates()
        
        switch result {
        case .success(let info):
            if info.isNewer {
                showUpdateAvailableAlert(info: info)
            } else {
                showNoUpdateAlert(currentVersion: info.latestVersion)
            }
            
        case .failure(let error):
            showUpdateErrorAlert(error: error)
        }
    }
    
    private func showUpdateAvailableAlert(info: UpdateChecker.UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = """
            A new version (\(info.latestVersion)) is available!
            
            You're currently running version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
            
            Release Notes:
            \(info.releaseNotes.prefix(200))...
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: info.downloadURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func showNoUpdateAlert(currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "You're Up to Date"
        alert.informativeText = "You're running the latest version (\(currentVersion))."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showUpdateErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = "Couldn't check for updates: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.minSize = NSSize(width: 950, height: 700)
            window.maxSize = NSSize(width: 1400, height: 1200)
        }
    }
}
