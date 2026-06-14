//
//  SettingsFeature.swift
//  AssisChat
//
//

import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class SettingsFeature: ObservableObject {
    @AppStorage(SharedUserDefaults.appTheme, store: SharedUserDefaults.shared) var selectedAppTheme: AppTheme = .nous
    @AppStorage(SharedUserDefaults.fontSize, store: SharedUserDefaults.shared) var selectedFontSize: FontSize = .normal
    @AppStorage(SharedUserDefaults.iCloudSync, store: SharedUserDefaults.shared) var iCloudSync = false {
        didSet {
            essentialFeature.setCloudSync(sync: iCloudSync)
        }
    }

    @AppStorage(SharedUserDefaults.hermesBaseURL, store: SharedUserDefaults.shared) private(set) var configuredHermesBaseURL: String?
    @AppStorage(SharedUserDefaults.hermesSessionId, store: SharedUserDefaults.shared) var configuredHermesSessionId: String?
    @AppStorage(SharedUserDefaults.hermesSessionKey, store: SharedUserDefaults.shared) var configuredHermesSessionKey: String?
    @AppStorage(SharedUserDefaults.hermesModel, store: SharedUserDefaults.shared) var configuredHermesModel = Chat.HermesModel.default.rawValue
    @AppStorage(SharedUserDefaults.hermesDiscoveredModels, store: SharedUserDefaults.shared) private var configuredHermesDiscoveredModels = ""
    @AppStorage(SharedUserDefaults.hermesDefaultProfileDisplayName, store: SharedUserDefaults.shared) var hermesDefaultProfileDisplayName = ""
    @AppStorage(SharedUserDefaults.hermesArchivedSessionIds, store: SharedUserDefaults.shared) private var archivedHermesSessionIds = ""
    @AppStorage(SharedUserDefaults.archivedChatIds, store: SharedUserDefaults.shared) private var archivedChatIds = ""

    var configuredHermesAPIKey: String? {
        KeychainSecrets.get(SharedUserDefaults.hermesAPIKey)
    }

    let essentialFeature: EssentialFeature

    @Published private(set) var chattingAdapters: [String: ChattingAdapter] = [:]

    var orderedAdapters: [ChattingAdapter] {
        chattingAdapters.map { (key: String, value: ChattingAdapter) in
            value
        }.sorted { a1, a2 in
            a1.priority < a2.priority
        }
    }

    var modelToAdapter: [String: ChattingAdapter] {
        return chattingAdapters.flatMap { (adapterKey, adapter) -> [(String, ChattingAdapter)] in
            return adapter.models.map { (model) -> (String, ChattingAdapter) in
                return (model, adapter)
            }
        }.reduce(into: [String: ChattingAdapter]()) { (result, keyValue) in
            result[keyValue.0] = keyValue.1
        }
    }

    var activeModels: [String] {
        return chattingAdapters.flatMap { (adapterKey, adapter) -> [String] in
            return adapter.models.map { model in
                return model
            }
        }
    }

    var adapterReady: Bool {
        return !chattingAdapters.isEmpty
    }

    init(essentialFeature: EssentialFeature) {
        self.essentialFeature = essentialFeature

        if selectedAppTheme == .modern || selectedAppTheme == .hermesNous {
            selectedAppTheme = .nous
        }

        initiateAdapters()
    }

    func initiateAdapters() {
        SharedUserDefaults.migrateSecretsToKeychainIfNeeded()
        initiateHermesAdapter()
    }

    func initiateHermesAdapter() {
        guard let apiKey = configuredHermesAPIKey, !apiKey.isEmpty else {
            return
        }

        let adapter = HermesAdapter(
            essentialFeature: essentialFeature,
            config: .init(
                baseURL: configuredHermesBaseURL,
                apiKey: apiKey,
                model: configuredHermesModel,
                discoveredModels: discoveredHermesModels,
                sessionId: configuredHermesSessionId,
                sessionKey: configuredHermesSessionKey
            )
        )
        chattingAdapters[adapter.identifier] = adapter
    }

    @MainActor
    func validateAndConfigHermes(apiKey: String, baseURL: String?, sessionId: String?, sessionKey: String?) async throws -> ChattingAdapter {
        let adapter = HermesAdapter(
            essentialFeature: essentialFeature,
            config: .init(
                baseURL: baseURL,
                apiKey: apiKey,
                model: configuredHermesModel,
                discoveredModels: discoveredHermesModels,
                sessionId: sessionId,
                sessionKey: sessionKey
            )
        )

        try await adapter.validateConfig()

        chattingAdapters[adapter.identifier] = adapter
        try KeychainSecrets.set(apiKey, for: SharedUserDefaults.hermesAPIKey)
        configuredHermesBaseURL = baseURL
        configuredHermesSessionId = sessionId
        configuredHermesSessionKey = sessionKey

        if let baseURL = adapter.config.normalizedBaseURL {
            let client = HermesAPIClient(baseURL: baseURL, apiKey: apiKey, sessionId: sessionId, sessionKey: sessionKey)
            let models = await client.profileCandidates()
            updateHermesModels(models)
        }

        return adapter
    }

    var discoveredHermesModels: [String] {
        configuredHermesDiscoveredModels
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    @MainActor
    func updateHermesModels(_ models: [String]) {
        let normalized = Array(Set(models.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        guard !normalized.isEmpty else { return }

        configuredHermesDiscoveredModels = normalized.joined(separator: "\n")
        if !normalized.contains(configuredHermesModel) {
            configuredHermesModel = normalized[0]
        }
        initiateHermesAdapter()
    }

    func displayName(forHermesModel model: String?) -> String {
        guard let model = model?.nilIfBlank else {
            return Chat.HermesModel.default.rawValue
        }

        if model == Chat.HermesModel.default.rawValue,
           let displayName = hermesDefaultProfileDisplayName.nilIfBlank {
            return displayName
        }

        return model
    }

    func isHermesSessionArchived(_ session: HermesAPIClient.Session) -> Bool {
        archivedHermesSessionIdSet.contains(session.id)
    }

    func archiveHermesSession(_ session: HermesAPIClient.Session) {
        var ids = archivedHermesSessionIdSet
        ids.insert(session.id)
        archivedHermesSessionIds = serializeIds(ids)
    }

    func unarchiveHermesSession(_ session: HermesAPIClient.Session) {
        var ids = archivedHermesSessionIdSet
        ids.remove(session.id)
        archivedHermesSessionIds = serializeIds(ids)
    }

    func isChatArchived(_ chat: Chat) -> Bool {
        archivedChatIdSet.contains(chatArchiveId(chat))
    }

    func archiveChat(_ chat: Chat) {
        var ids = archivedChatIdSet
        ids.insert(chatArchiveId(chat))
        archivedChatIds = serializeIds(ids)
    }

    func unarchiveChat(_ chat: Chat) {
        var ids = archivedChatIdSet
        ids.remove(chatArchiveId(chat))
        archivedChatIds = serializeIds(ids)
    }

    private var archivedHermesSessionIdSet: Set<String> {
        parseIds(archivedHermesSessionIds)
    }

    private var archivedChatIdSet: Set<String> {
        parseIds(archivedChatIds)
    }

    private func chatArchiveId(_ chat: Chat) -> String {
        chat.objectID.uriRepresentation().absoluteString
    }

    private func parseIds(_ rawValue: String) -> Set<String> {
        Set(rawValue.split(separator: "\n").map(String.init).filter { !$0.isEmpty })
    }

    private func serializeIds(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: "\n")
    }
}

extension SettingsFeature {
    static let fontSizes: [FontSize] = [
        .large,
        .normal,
        .small,
    ]

    enum AppTheme: String, Hashable {
        case modern = "modern"
        case nous = "nous"
        case midnight = "midnight"
        case ember = "ember"
        case mono = "mono"
        case cyberpunk = "cyberpunk"
        case slate = "slate"
        case hermesNous = "hermes-nous"

        var localizedKey: LocalizedStringKey {
            switch self {
            case .modern: return "Modern"
            case .nous: return "Nous"
            case .midnight: return "Midnight"
            case .ember: return "Ember"
            case .mono: return "Mono"
            case .cyberpunk: return "Cyberpunk"
            case .slate: return "Slate"
            case .hermesNous: return "Hermes Nous"
            }
        }

        var accent: Color {
            theme(for: .dark).primary
        }

        var assistantBubble: Color {
            theme(for: .dark).card
        }

        var userBubble: Color {
            theme(for: .dark).userBubble
        }

        var preferredColorScheme: SwiftUI.ColorScheme {
            switch self {
            case .modern:
                return .light
            case .nous, .midnight, .ember, .mono, .cyberpunk, .slate, .hermesNous:
                return .dark
            }
        }
    }

    static let appThemes: [AppTheme] = [
        .nous,
        .midnight,
        .ember,
        .mono,
        .cyberpunk,
        .slate
    ]

    enum FontSize: String, Hashable {
        case large = "large"
        case normal = "normal"
        case small = "small"

        var value: CGFloat {
            #if os(macOS)
            switch self {
            case .large: return NSFont.systemFontSize + 2
            case .normal: return NSFont.systemFontSize
            case .small: return NSFont.systemFontSize - 2
            }
            #else
            switch self {
            case .large: return UIFont.preferredFont(forTextStyle: .body).pointSize + 2
            case .normal: return UIFont.preferredFont(forTextStyle: .body).pointSize
            case .small: return UIFont.preferredFont(forTextStyle: .body).pointSize - 2
            }
            #endif
        }

        var localizedLabel: String {
            switch self {
            case .large: return String(localized: "Large", comment: "The large size label of font size setting")
            case .normal: return String(localized: "Normal", comment: "The normal size label of font size setting")
            case .small: return String(localized: "Small", comment: "The small size label of font size setting")
            }
        }
    }
}
