//
//  SharedUserDefaults.swift
//  AssisChat
//
//

import Foundation
import Security

class SharedUserDefaults {
    static let shared = UserDefaults(suiteName: AppGroup.identifier)!

    static let proKey = "pro:purchased"

    static let colorScheme = "settings:colorScheme"
    static let fontSize = "settings:fontSize"
    static let iCloudSync = "settings:iCloudSync"

    // Open AI
    static let openAIDomain = "settings:openAI:domain"
    static let openAIAPIKey = "settings:openAI:apiKey"

    // Anthropic
    static let anthropicDomain = "settings:anthropic:domain"
    static let anthropicAPIKey = "settings:anthropic:apiKey"

    // Hermes
    static let hermesBaseURL = "settings:hermes:baseURL"
    static let hermesAPIKey = "settings:hermes:apiKey"
    static let hermesSessionId = "settings:hermes:sessionId"
    static let hermesSessionKey = "settings:hermes:sessionKey"
    static let hermesModel = "settings:hermes:model"
    static let hermesDiscoveredModels = "settings:hermes:discoveredModels"
    static let hermesDefaultProfileDisplayName = "settings:hermes:defaultProfileDisplayName"
    static let hermesArchivedSessionIds = "settings:hermes:archivedSessionIds"
    static let hermesPendingIntentRoute = "intent:hermes:route"
    static let hermesPendingIntentSessionId = "intent:hermes:sessionId"
    static let hermesPendingIntentSessionTitle = "intent:hermes:sessionTitle"
    static let hermesPendingIntentSessionSource = "intent:hermes:sessionSource"
    static let hermesPendingIntentSessionUpdatedAt = "intent:hermes:sessionUpdatedAt"
    static let hermesPendingIntentPrompt = "intent:hermes:prompt"
    static let hermesPendingIntentChatId = "intent:hermes:chatId"
    static let archivedChatIds = "settings:chats:archivedIds"

    // Appearance
    static let appTheme = "settings:appTheme"

    static let migrationKey = "dataMigrationComplete"
    static let keychainMigrationKey = "keychainMigrationComplete"

    static func migrateIfNeeded() {
        // Check if migration has already occurred
        if shared.bool(forKey: migrationKey) {
            migrateSecretsToKeychainIfNeeded()
            return
        }

        // List the keys to migrate
        let keysToMigrate = [
            colorScheme,
            fontSize,
            openAIDomain,
            openAIAPIKey,
            iCloudSync,
        ]

        // Migrate the data
        for key in keysToMigrate {
            if let value = UserDefaults.standard.object(forKey: key) {
                shared.set(value, forKey: key)
            }
        }

        // Mark the migration as complete
        shared.set(true, forKey: migrationKey)

        migrateSecretsToKeychainIfNeeded()
    }

    static func migrateSecretsToKeychainIfNeeded() {
        guard !shared.bool(forKey: keychainMigrationKey) else { return }

        for key in [openAIAPIKey, anthropicAPIKey, hermesAPIKey] {
            if let value = shared.string(forKey: key), !value.isEmpty {
                try? KeychainSecrets.set(value, for: key)
                shared.removeObject(forKey: key)
            }

            if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
                try? KeychainSecrets.set(value, for: key)
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        shared.set(true, forKey: keychainMigrationKey)
    }
}

enum KeychainSecretError: Error {
    case unhandledStatus(OSStatus)
    case invalidData
}

enum KeychainSecrets {
    private static let service = "AssisChat.ProviderSecrets"
    private static let sharedAccessGroup = "BWDKW435B4.com.turnercore.AssisChatHermes.shared"

    static func get(_ key: String) -> String? {
        for query in readQueries(for: key) {
            var query = query
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            query[kSecReturnData as String] = true

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)

            if status == errSecItemNotFound || status == errSecMissingEntitlement {
                continue
            }

            guard status == errSecSuccess, let data = item as? Data else { continue }
            return String(data: data, encoding: .utf8)
        }

        return nil
    }

    static func set(_ value: String?, for key: String) throws {
        guard let value = value, !value.isEmpty else {
            try delete(key)
            return
        }

        let encoded = Data(value.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: encoded,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        var lastError: OSStatus = errSecSuccess
        for query in writeQueries(for: key) {
            let status = set(encodedAttributes: attributes, query: query)
            if status == errSecSuccess { return }

            if status == errSecMissingEntitlement {
                lastError = status
                continue
            }

            lastError = status
        }

        throw KeychainSecretError.unhandledStatus(lastError)
    }

    static func delete(_ key: String) throws {
        var lastError: OSStatus = errSecSuccess
        for query in writeQueries(for: key) {
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound || status == errSecMissingEntitlement {
                continue
            }

            lastError = status
        }

        guard lastError == errSecSuccess else {
            throw KeychainSecretError.unhandledStatus(lastError)
        }
    }

    private static func set(encodedAttributes attributes: [String: Any], query: [String: Any]) -> OSStatus {
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return errSecSuccess }

        guard updateStatus == errSecItemNotFound else {
            return updateStatus
        }

        var insert = query
        attributes.forEach { insert[$0.key] = $0.value }

        return SecItemAdd(insert as CFDictionary, nil)
    }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    private static func sharedQuery(for key: String) -> [String: Any] {
        var query = baseQuery(for: key)
        query[kSecAttrAccessGroup as String] = sharedAccessGroup
        return query
    }

    private static func readQueries(for key: String) -> [[String: Any]] {
        [
            sharedQuery(for: key),
            baseQuery(for: key)
        ]
    }

    private static func writeQueries(for key: String) -> [[String: Any]] {
        [
            sharedQuery(for: key),
            baseQuery(for: key)
        ]
    }
}
