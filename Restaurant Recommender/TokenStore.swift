//
//  TokenStore.swift
//  Simple Todo App
//

import Foundation

/// Persists the access/refresh token pair in the Keychain.
///
/// Tokens are never written to `UserDefaults` or any on-disk plist — only the
/// Keychain, which is encrypted at rest and (with `.afterFirstUnlockThisDeviceOnly`)
/// excluded from device backups.
nonisolated struct TokenStore {
    private let keychain: KeychainService

    private enum Account: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    var accessToken: String? {
        keychain.read(account: Account.accessToken.rawValue)
    }

    var refreshToken: String? {
        keychain.read(account: Account.refreshToken.rawValue)
    }

    func save(accessToken: String, refreshToken: String) throws {
        try keychain.save(accessToken, account: Account.accessToken.rawValue)
        try keychain.save(refreshToken, account: Account.refreshToken.rawValue)
    }

    /// Updates only the access token, leaving the refresh token untouched.
    func updateAccessToken(_ accessToken: String) throws {
        try keychain.save(accessToken, account: Account.accessToken.rawValue)
    }

    func clear() {
        keychain.delete(account: Account.accessToken.rawValue)
        keychain.delete(account: Account.refreshToken.rawValue)
    }
}
