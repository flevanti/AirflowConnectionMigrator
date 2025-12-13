// File: Services/UpdateChecker.swift
// Purpose: Check GitHub for new releases

import Foundation

/// Checks for app updates on GitHub
class UpdateChecker {
    
    /// GitHub API endpoint for releases - uses AppConstants
    private static var releasesURL: String {
        AppConstants.githubReleasesAPIURL
    }
    
    /// Result of update check
    struct UpdateInfo {
        let latestVersion: String
        let downloadURL: String
        let releaseNotes: String
        let isNewer: Bool
    }
    
    /// Checks GitHub for the latest release
    /// - Returns: Update info if successful
    static func checkForUpdates() async -> Result<UpdateInfo, Error> {
        guard let url = URL(string: releasesURL) else {
            return .failure(UpdateError.invalidURL)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // ADDED: Debug logging
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 GitHub API Status Code: \(httpResponse.statusCode)")
            }
            
            // ADDED: Print raw response to see what we got
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 GitHub API Response: \(jsonString.prefix(200))...")
            }
            
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            
            let currentVersion = getCurrentVersion()
            let isNewer = isVersion(release.tagName, newerThan: currentVersion)
            
            let info = UpdateInfo(
                latestVersion: release.tagName,
                downloadURL: release.htmlURL,
                releaseNotes: release.body ?? "No release notes available",
                isNewer: isNewer
            )
            
            return .success(info)
            
        } catch {
            print("🔴 Update check error: \(error)")  // ADDED
            return .failure(error)
        }
    }
    
    /// Gets current app version from bundle
    private static func getCurrentVersion() -> String {
        return AppConstants.appVersion
    }
    
    /// Compares two semantic versions
    /// - Parameters:
    ///   - version1: First version (e.g., "v1.2.3" or "1.2.3")
    ///   - version2: Second version
    /// - Returns: True if version1 is newer than version2
    private static func isVersion(_ version1: String, newerThan version2: String) -> Bool {
        let v1 = version1.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let v2 = version2.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(parts1.count, parts2.count) {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        
        return false // Versions are equal
    }
}

// MARK: - GitHub API Models

private struct GitHubRelease: Codable {
    let tagName: String
    let htmlURL: String
    let body: String?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
    }
}

// MARK: - Errors

enum UpdateError: LocalizedError {
    case invalidURL
    case noReleasesFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub URL"
        case .noReleasesFound:
            return "No releases found on GitHub"
        }
    }
}
