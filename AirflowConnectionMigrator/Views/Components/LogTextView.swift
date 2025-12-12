// File: Views/Components/LogTextView.swift
// Purpose: Scrollable text view for displaying log messages
// Shows timestamped, colored log entries with auto-scroll to bottom

import SwiftUI

/// A scrollable text view that displays log entries
/// Features:
/// - Auto-scrolls to bottom when new logs appear
/// - Color-coded messages by type
/// - Timestamp display
/// - Copy all logs button
struct LogTextView: View {
    /// Logger instance to observe
    @ObservedObject var logger: Logger
    
    /// Scroll view proxy for auto-scrolling
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and clear button
            HStack {
                Text("Logs")
                    .font(.headline)
                
                Spacer()
                
                Button("Copy All") {
                    copyAllLogs()
                }
                .buttonStyle(.borderless)
                
                Button("Clear") {
                    logger.clear()
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            
            Divider()
            
            // Log entries in scroll view
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(logger.entries) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: logger.entries.count) { _ in
                    // Auto-scroll to bottom when new log appears
                    if let lastEntry = logger.entries.last {
                        withAnimation {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 200)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    /// Copies all logs to clipboard
    private func copyAllLogs() {
        let allLogs = logger.getAllLogsAsString()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allLogs, forType: .string)
    }
}

/// Single log entry row
struct LogEntryRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(entry.timestampString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            // Icon/Emoji
            Text(entry.type.prefix)
                .font(.caption)
                .frame(width: 20)
            
            // Message
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(colorForLogType(entry.type))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
    
    /// Returns appropriate color for log type
    private func colorForLogType(_ type: LogType) -> Color {
        switch type {
        case .info:
            return .primary
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    LogTextView(logger: {
        let logger = Logger()
        logger.info("Application started")
        logger.success("Connection successful")
        logger.warning("This is a warning message")
        logger.error("An error occurred")
        logger.info("Operation completed")
        return logger
    }())
    .frame(width: 600, height: 300)
    .padding()
}
