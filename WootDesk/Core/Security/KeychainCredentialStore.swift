import Foundation
import Security
import os

/// Apple Keychain implementation of `CredentialStore`.
///
/// Security rationale:
/// - Uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` in iOS and release builds.
/// - Uses the default macOS Keychain only for ad-hoc Debug builds that cannot
///   access the data-protection Keychain without a provisioned application identifier.
/// - Protects personal access tokens at rest.
/// - Never marks tokens as synchronisable.
public final class KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    private let service: String
    private let accessGroup: String?
    private let usesDataProtectionKeychain: Bool

    public init(
        service: String = "dev.n85.wootdesk.credentials",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
        #if os(macOS) && DEBUG
        self.usesDataProtectionKeychain = Self.hasDataProtectionKeychainEntitlement()
        #else
        self.usesDataProtectionKeychain = true
        #endif
    }

    public func saveToken(_ token: String, for profileID: UUID) throws {
        guard let data = token.data(using: .utf8) else {
            throw CredentialError.invalidTokenData
        }

        let account = profileID.uuidString

        // Query to check if token exists
        var query = baseQuery(for: account)
        query[kSecValueData as String] = data
        if usesDataProtectionKeychain {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Update existing item
            let updateQuery = baseQuery(for: account)
            var attributesToUpdate: [String: Any] = [kSecValueData as String: data]
            if usesDataProtectionKeychain {
                attributesToUpdate[kSecAttrAccessible as String] =
                    kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            }
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                AppLogger.auth.error("Keychain update failed with status: \(updateStatus)")
                throw CredentialError.keychainError(status: updateStatus)
            }
        } else if status != errSecSuccess {
            AppLogger.auth.error("Keychain save failed with status: \(status)")
            throw CredentialError.keychainError(status: status)
        }
    }

    public func loadToken(for profileID: UUID) throws -> String? {
        let account = profileID.uuidString
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            AppLogger.auth.error("Keychain read failed with status: \(status)")
            throw CredentialError.keychainError(status: status)
        }

        guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
            throw CredentialError.invalidTokenData
        }

        return token
    }

    public func deleteToken(for profileID: UUID) throws {
        let account = profileID.uuidString
        let query = baseQuery(for: account)

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            AppLogger.auth.error("Keychain delete failed with status: \(status)")
            throw CredentialError.keychainError(status: status)
        }
    }

    private func baseQuery(for account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        if usesDataProtectionKeychain {
            #if os(macOS)
            query[kSecUseDataProtectionKeychain as String] = true
            #endif
        }
        return query
    }

    #if os(macOS) && DEBUG
    /// An ad-hoc signature has no authorised Keychain access group. Asking for
    /// the data-protection Keychain in that environment fails with
    /// `errSecMissingEntitlement`, so local Debug builds use the default macOS
    /// Keychain instead.
    private static func hasDataProtectionKeychainEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else {
            return false
        }

        if let groups = SecTaskCopyValueForEntitlement(
            task,
            "keychain-access-groups" as CFString,
            nil
        ) as? [String], !groups.isEmpty {
            return true
        }

        if let applicationIdentifier = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.application-identifier" as CFString,
            nil
        ) as? String, !applicationIdentifier.isEmpty {
            return true
        }

        return false
    }
    #endif
}

public enum CredentialError: LocalizedError, Sendable {
    case invalidTokenData
    case keychainError(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidTokenData:
            return "The Chatwoot credential could not be encoded for secure storage."
        case .keychainError(let status) where status == errSecMissingEntitlement:
            return "WootDesk is not signed with the Keychain entitlement required for secure storage."
        case .keychainError:
            return "Apple Keychain could not complete the secure storage operation."
        }
    }
}
