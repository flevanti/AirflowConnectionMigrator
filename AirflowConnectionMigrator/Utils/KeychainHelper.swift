// File: Utils/KeychainHelper.swift
// Purpose: Secure storage for sensitive data using macOS Keychain
// Handles passwords and Fernet keys for connection profiles

import Foundation
import Security

/// Wrapper for macOS Keychain operations
/// Provides simple save/read/delete operations for secure string storage
class KeychainHelper {
    /// Shared singleton instance
    static let shared = KeychainHelper()
    
    private init() {}
    
    // MARK: - Save
    
    /// Saves a string value to the Keychain
    /// If a value already exists for this service, it will be updated
    /// - Parameters:
    ///   - value: The string to store securely
    ///   - service: Unique identifier for this item (e.g., "airflow.connection.uuid.password")
    /// - Returns: true if save was successful
    @discardableResult
    func save(_ value: String, service: String) -> Bool {
        // Convert string to Data for Keychain storage
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        // Check if item already exists
        if read(service: service) != nil {
            // Update existing item
            return update(data, service: service)
        } else {
            // Create new item
            return create(data, service: service)
        }
    }
    
    /// Creates a new Keychain item
    private func create(_ data: Data, service: String) -> Bool {
        // Build query dictionary for Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,  // Type of item
            kSecAttrService as String: service,              // Unique service identifier
            kSecValueData as String: data,                   // The actual data to store
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked  // Only accessible when device is unlocked
        ]
        
        // Attempt to add to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else {
            print("⚠️ Keychain create failed for service '\(service)': \(status)")
            return false
        }
    }
    
    /// Updates an existing Keychain item
    private func update(_ data: Data, service: String) -> Bool {
        // Query to find the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        // Data to update
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        // Attempt to update
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status == errSecSuccess {
            return true
        } else {
            print("⚠️ Keychain update failed for service '\(service)': \(status)")
            return false
        }
    }
    
    // MARK: - Read
    
    /// Reads a string value from the Keychain
    /// - Parameter service: Unique identifier for the item to retrieve
    /// - Returns: The stored string, or nil if not found or error occurred
    func read(service: String) -> String? {
        // Build query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,        // Return the actual data
            kSecMatchLimit as String: kSecMatchLimitOne  // Only return one result
        ]
        
        // Variable to hold the result
        var result: AnyObject?
        
        // Attempt to retrieve from Keychain
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // Check if successful
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            
            // Don't print error for "item not found" - that's normal
            if status != errSecItemNotFound {
                print("⚠️ Keychain read failed for service '\(service)': \(status)")
            }
            return nil
        }
        
        return value
    }
    
    // MARK: - Delete
    
    /// Deletes an item from the Keychain
    /// - Parameter service: Unique identifier for the item to delete
    /// - Returns: true if deletion was successful or item didn't exist
    @discardableResult
    func delete(service: String) -> Bool {
        // Build query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        // Attempt to delete
        let status = SecItemDelete(query as CFDictionary)
        
        // Success if deleted or if item wasn't found (idempotent operation)
        if status == errSecSuccess || status == errSecItemNotFound {
            return true
        } else {
            print("⚠️ Keychain delete failed for service '\(service)': \(status)")
            return false
        }
    }
    
    // MARK: - Bulk Operations
    
    /// Deletes all items created by this app from the Keychain
    /// Useful for complete app reset or cleanup
    /// USE WITH CAUTION - This cannot be undone
    func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        SecItemDelete(query as CFDictionary)
        print("🗑️ All Keychain items deleted")
    }
}
