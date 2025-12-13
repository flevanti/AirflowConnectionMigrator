// File: Utils/AppConstants.swift
// Purpose: Central configuration for app-wide constants
// Update these values once and they're used everywhere

import Foundation

/// Application constants and configuration
enum AppConstants {
    
    // MARK: - Version Info
    
    /// Current app version from bundle
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "99.99.99"
    }
    
    /// Current build number from bundle
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "99"
    }
    
    // MARK: - GitHub Repository
    
    /// GitHub username
    static let githubUsername = "flevanti"
    
    /// Repository name
    static let repositoryName = "AirflowConnectionMigrator"
    
    /// Base GitHub repository URL
    static var githubRepoURL: String {
        "https://github.com/\(githubUsername)/\(repositoryName)"
    }
    
    /// GitHub issues URL
    static var githubIssuesURL: String {
        "\(githubRepoURL)/issues"
    }
    
    /// GitHub releases API URL
    static var githubReleasesAPIURL: String {
        "https://api.github.com/repos/\(githubUsername)/\(repositoryName)/releases/latest"
    }
    
    // MARK: - Contact Info
    
    /// Developer email
    static let developerEmail = "levanti.francesco@gmail.com"
    
    /// Email support URL
    static var supportEmailURL: String {
        "mailto:\(developerEmail)"
    }
    
    // MARK: - App Info
    
    /// App display name
    static let appName = "Airflow Connection Migrator"
    
    /// Copyright text with current year
    static var copyright: String {
        let year = Calendar.current.component(.year, from: Date())
        return "© \(year) Francesco Levanti"
    }
    
    /// License type
    static let license = "Apache 2.0"
    
    /// App description
    static let appDescription = "Securely export and import Apache Airflow connections between environments"
}
