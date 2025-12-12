// File: Services/FernetService.swift
// Purpose: Handles Fernet encryption/decryption operations
// Implements Fernet symmetric encryption compatible with Python's cryptography.fernet

//
//
// PLEASE NOTE ⬅️⬅️⬅️⬅️
// THIS CLASS HAS BEEN REPLACED BY THE SAME CODE BUT IN A SEPARATE LIBRARY TO BE REUSABLE IN OTHER PROJECTS
// KEPT HERE FOR THE MOMENT TO BE SURE I HAVEN'T FORGOTTEN ANYTHING....
//
//



import Foundation
import CryptoSwift

/// Service for Fernet encryption and decryption operations
/// Fernet is a symmetric encryption method that ensures encrypted data cannot be manipulated without the key
/// Compatible with Python's cryptography.fernet library
class FernetService_NOT_USED_ANYMORE {
    
    // MARK: - Key Generation
    
    /// Generates a new random Fernet key
    /// - Returns: Base64-encoded 32-byte key suitable for Fernet operations
    static func generateKey() -> String {
        // Fernet uses 32 bytes (256 bits) for the key
        let keyBytes = AES.randomIV(32)  // Generate 32 random bytes
        return Data(keyBytes).base64EncodedString()
    }
    
    // MARK: - Encryption

    /// Encrypts a string value using Fernet encryption
    /// Compatible with Python's cryptography.fernet library (URL-safe Base64)
    /// - Parameters:
    ///   - value: The plaintext string to encrypt
    ///   - key: Base64-encoded Fernet key (accepts both standard and URL-safe Base64)
    /// - Returns: Base64-encoded encrypted string, or nil if encryption fails
    static func encrypt(_ value: String, withKey key: String) -> String? {
        // Handle nil/empty values
        guard !value.isEmpty else {
            return nil
        }
        
        // Convert URL-safe Base64 to standard Base64
        // Python's Fernet uses URL-safe Base64 with _ instead of / and - instead of +
        let standardBase64 = key
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")
        
        // Decode the Fernet key from Base64
        guard let keyData = Data(base64Encoded: standardBase64),
              keyData.count == 32 else {
            print("⚠️ Invalid Fernet key format or length")
            return nil
        }
        
        // Convert string to Data
        guard let plainData = value.data(using: .utf8) else {
            print("⚠️ Failed to convert value to data")
            return nil
        }
        
        do {
            // Fernet token format:
            // Version (1 byte) | Timestamp (8 bytes) | IV (16 bytes) | Ciphertext (variable) | HMAC (32 bytes)
            
            // 1. Version byte (always 0x80 for Fernet)
            var token = Data([0x80])
            
            // 2. Timestamp (current time as 64-bit big-endian integer)
            let timestamp = UInt64(Date().timeIntervalSince1970)
            var timestampBytes = timestamp.bigEndian
            token.append(Data(bytes: &timestampBytes, count: 8))
            
            // 3. Generate random IV (16 bytes for AES-128)
            let iv = AES.randomIV(16)
            token.append(Data(iv))
            
            // 4. Encrypt the data using AES-128-CBC
            // Fernet uses the last 16 bytes of the key for AES encryption
            let encryptionKey = Array(keyData.suffix(16))
            let aes = try AES(key: encryptionKey, blockMode: CBC(iv: iv), padding: .pkcs7)
            let ciphertext = try aes.encrypt(Array(plainData))
            token.append(Data(ciphertext))
            
            // 5. Calculate HMAC-SHA256 over the entire token so far
            // Fernet uses the first 16 bytes of the key for HMAC
            let hmacKey = Array(keyData.prefix(16))
            let hmac = try HMAC(key: hmacKey, variant: .sha2(.sha256)).authenticate(Array(token))
            token.append(Data(hmac))
            
            // 6. Base64-encode the complete token
            return token.base64EncodedString()
            
        } catch {
            print("⚠️ Encryption error: \(error)")
            return nil
        }
    }

    // MARK: - Decryption

    /// Decrypts a Fernet-encrypted string
    /// Compatible with Python's cryptography.fernet library (URL-safe Base64)
    /// - Parameters:
    ///   - encryptedValue: Base64-encoded Fernet token (URL-safe Base64 format)
    ///   - key: Base64-encoded Fernet key (must match the key used for encryption, accepts both standard and URL-safe Base64)
    /// - Returns: Decrypted plaintext string, or nil if decryption fails
    static func decrypt(_ encryptedValue: String, withKey key: String) -> String? {
        // Handle nil/empty values
        guard !encryptedValue.isEmpty else {
            return nil
        }
        
        // Convert URL-safe Base64 to standard Base64 for the KEY
        let standardBase64Key = key
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")
        
        // Convert URL-safe Base64 to standard Base64 for the ENCRYPTED TOKEN
        let standardBase64Token = encryptedValue
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")
        
        // Decode the Fernet key from Base64
        guard let keyData = Data(base64Encoded: standardBase64Key),
              keyData.count == 32 else {
            print("⚠️ Invalid Fernet key format or length")
            return nil
        }
        
        // Decode the Fernet token from Base64
        guard let tokenData = Data(base64Encoded: standardBase64Token) else {
            print("⚠️ Invalid Fernet token format")
            return nil
        }
        
        // Minimum token size: 1 (version) + 8 (timestamp) + 16 (IV) + 16 (min ciphertext) + 32 (HMAC) = 73 bytes
        guard tokenData.count >= 73 else {
            print("⚠️ Fernet token too short")
            return nil
        }
        
        do {
            // 1. Extract components from token
            var offset = 0
            
            // Version (1 byte)
            let version = tokenData[offset]
            guard version == 0x80 else {
                print("⚠️ Unsupported Fernet version: \(version)")
                return nil
            }
            offset += 1
            
            // Timestamp (8 bytes) - not used for decryption but part of HMAC
            offset += 8
            
            // IV (16 bytes)
            let iv = Array(tokenData.subdata(in: offset..<(offset + 16)))
            offset += 16
            
            // Ciphertext (everything except the last 32 bytes which are HMAC)
            let hmacSize = 32
            let ciphertextEndIndex = tokenData.count - hmacSize
            let ciphertext = Array(tokenData.subdata(in: offset..<ciphertextEndIndex))
            
            // HMAC (last 32 bytes)
            let providedHmac = tokenData.suffix(hmacSize)
            
            // 2. Verify HMAC before decryption
            let dataToVerify = tokenData.prefix(ciphertextEndIndex)
            let hmacKey = Array(keyData.prefix(16))  // First 16 bytes for HMAC
            let calculatedHmac = try HMAC(key: hmacKey, variant: .sha2(.sha256)).authenticate(Array(dataToVerify))

            guard Data(calculatedHmac) == providedHmac else {
                print("⚠️ HMAC verification failed - data may be corrupted or key is incorrect")
                return nil
            }
            
            // 3. Decrypt the ciphertext
            let encryptionKey = Array(keyData.suffix(16))  // Last 16 bytes for AES
            let aes = try AES(key: encryptionKey, blockMode: CBC(iv: iv), padding: .pkcs7)
            let decryptedBytes = try aes.decrypt(ciphertext)
            
            // 4. Convert decrypted bytes back to string
            guard let decryptedString = String(bytes: decryptedBytes, encoding: .utf8) else {
                print("⚠️ Failed to convert decrypted data to string")
                return nil
            }
            
            return decryptedString
            
        } catch {
            print("⚠️ Decryption error: \(error)")
            return nil
        }
    }
    
    // MARK: - Validation
    
    /// Validates that a string is a valid Base64-encoded Fernet key
    /// Accepts both standard Base64 and URL-safe Base64 formats (matching Python's Fernet)
    /// - Parameter key: The key string to validate (can contain - and _ for URL-safe Base64)
    /// - Returns: true if the key is valid (32 bytes when decoded)
    static func isValidKey(_ key: String) -> Bool {
        // Convert URL-safe Base64 to standard Base64
        // Python's Fernet uses URL-safe Base64 with _ instead of / and - instead of +
        let standardBase64 = key
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")
        
        guard let keyData = Data(base64Encoded: standardBase64) else {
            return false
        }
        return keyData.count == 32
    }
    
    /// Tests encryption and decryption with a given key
    /// Useful for validating that a key works correctly
    /// - Parameter key: The Fernet key to test
    /// - Returns: true if encryption and decryption work correctly
    static func testKey(_ key: String) -> Bool {
        let testString = "test_encryption_\(UUID().uuidString)"
        
        guard let encrypted = encrypt(testString, withKey: key),
              let decrypted = decrypt(encrypted, withKey: key) else {
            return false
        }
        
        return decrypted == testString
    }
}
