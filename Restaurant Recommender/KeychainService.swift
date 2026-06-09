//
//  KeychainService.swift
//  Simple Todo App
//

import Foundation
import Security

nonisolated enum KeychainError: Error {
    case encodingFailed
    case unexpectedStatus(OSStatus)
}

/// Thin wrapper around the Keychain Services API for storing small string
/// secrets (e.g. auth tokens) as generic passwords.
///
/// Items are written with `.afterFirstUnlockThisDeviceOnly`, which keeps them
/// off iCloud Keychain backup/sync (they're tied to this device) while still
/// letting background refreshes read them before the user unlocks the device
/// post-reboot.
nonisolated struct KeychainService {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.simpletodoapp") {
        self.service = service
    }

    private func query(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func save(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let baseQuery = query(account: account)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    func read(account: String) -> String? {
        var matchQuery = query(account: account)
        matchQuery[kSecReturnData as String] = true
        matchQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(matchQuery as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }

    func delete(account: String) {
        SecItemDelete(query(account: account) as CFDictionary)
    }
}
