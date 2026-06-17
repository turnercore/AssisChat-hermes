//
//  HermesAppIntents.swift
//  AssisChat
//

import Foundation
import CoreData

#if canImport(AppIntents)
import AppIntents

@available(iOS 16.0, macOS 13.0, *)
struct HermesSessionEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Hermes Session")
    static var defaultQuery = HermesSessionQuery()

    let id: String
    let title: String
    let source: String?
    let updatedAt: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title.nilIfBlank ?? id)",
            subtitle: source?.nilIfBlank.map { "\($0)" }
        )
    }

    var session: HermesAPIClient.Session {
        HermesAPIClient.Session(id: id, title: title, source: source, updatedAt: updatedAt)
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct HermesSessionQuery: EntityStringQuery {
    func entities(for identifiers: [HermesSessionEntity.ID]) async throws -> [HermesSessionEntity] {
        let sessions = try await loadSessions(limit: 100)
        return sessions.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HermesSessionEntity] {
        try await loadSessions(limit: 12)
    }

    func entities(matching string: String) async throws -> [HermesSessionEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return try await suggestedEntities()
        }

        return try await loadSessions(limit: 100).filter { entity in
            entity.id.lowercased().contains(query)
                || entity.title.lowercased().contains(query)
                || entity.source?.lowercased().contains(query) == true
        }
    }

    private func loadSessions(limit: Int) async throws -> [HermesSessionEntity] {
        guard let client = HermesIntentClientFactory.client() else { return [] }
        return try await client.sessions(limit: limit).items.map(HermesSessionEntity.init(session:))
    }
}

@available(iOS 16.0, macOS 13.0, *)
private extension HermesSessionEntity {
    init(session: HermesAPIClient.Session) {
        id = session.id
        title = session.displayTitle
        source = session.source
        updatedAt = session.updatedAt
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct HermesChatEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Chat")
    static var defaultQuery = HermesChatQuery()

    let id: String
    let name: String
    let updatedAt: Date?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name.nilIfBlank ?? "Chat")",
            subtitle: updatedAt.map { "\($0.formatted(date: .abbreviated, time: .shortened))" }
        )
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct HermesChatQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [HermesChatEntity.ID]) async throws -> [HermesChatEntity] {
        try localChats().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [HermesChatEntity] {
        Array(try localChats().prefix(12))
    }

    @MainActor
    func entities(matching string: String) async throws -> [HermesChatEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return try await suggestedEntities()
        }

        return try localChats().filter { entity in
            entity.name.lowercased().contains(query) || entity.id.lowercased().contains(query)
        }
    }

    @MainActor
    private func localChats() throws -> [HermesChatEntity] {
        let request = Chat.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Chat.rawUpdatedAt, ascending: false)]
        request.fetchLimit = 100
        return try PersistenceController.shared.container.viewContext.fetch(request).map { chat in
            HermesChatEntity(
                id: chat.objectID.uriRepresentation().absoluteString,
                name: chat.name,
                updatedAt: chat.rawUpdatedAt
            )
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct StartHermesTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Start New Hermes Task"
    static var description = IntentDescription("Open DaisyChat ready to start a new Hermes task.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        HermesIntentRouter.requestNewTask()
        return .result(dialog: "Opening a new Hermes task.")
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct StartHermesTaskWithPromptIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Hermes Task With Prompt"
    static var description = IntentDescription("Open DaisyChat with a Hermes prompt already filled in.")
    static var openAppWhenRun = true

    @Parameter(title: "Prompt")
    var prompt: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        HermesIntentRouter.requestNewTask(prompt: prompt)
        return .result(dialog: "Opening a new Hermes task.")
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct OpenRecentHermesSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Recent Hermes Session"
    static var description = IntentDescription("Open the most recently updated Hermes session.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let client = HermesIntentClientFactory.client() else {
            HermesIntentRouter.requestNewTask()
            return .result(dialog: "Hermes is not configured yet.")
        }

        do {
            if let session = try await client.sessions(limit: 1).items.first {
                HermesIntentRouter.requestRecentSession(session)
                return .result(dialog: "Opening \(session.displayTitle).")
            }

            HermesIntentRouter.requestNewTask()
            return .result(dialog: "No recent Hermes sessions were found.")
        } catch {
            HermesIntentRouter.requestNewTask()
            return .result(dialog: "Could not load recent Hermes sessions.")
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct OpenHermesSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Hermes Session"
    static var description = IntentDescription("Open a selected Hermes session in DaisyChat.")
    static var openAppWhenRun = true

    @Parameter(title: "Session", query: HermesSessionQuery())
    var session: HermesSessionEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        HermesIntentRouter.requestRecentSession(session.session)
        return .result(dialog: "Opening \(session.title).")
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct OpenHermesChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Open DaisyChat Chat"
    static var description = IntentDescription("Open a selected local DaisyChat chat.")
    static var openAppWhenRun = true

    @Parameter(title: "Chat", query: HermesChatQuery())
    var chat: HermesChatEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        HermesIntentRouter.requestLocalChat(id: chat.id)
        return .result(dialog: "Opening \(chat.name).")
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct CheckHermesHealthIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Hermes Health"
    static var description = IntentDescription("Check whether the configured Hermes server is reachable.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let client = HermesIntentClientFactory.client() else {
            return .result(dialog: "Hermes is not configured yet.")
        }

        do {
            let health = try await client.health()
            return .result(dialog: "Hermes status: \(health.status).")
        } catch {
            return .result(dialog: "Hermes health check failed.")
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct ContinueLastChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Continue Last Chat"
    static var description = IntentDescription("Open DaisyChat at the most recent local chat.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        HermesIntentRouter.requestContinueLastChat()
        return .result(dialog: "Opening your last chat.")
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct HermesAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenHermesSessionIntent(),
            phrases: [
                "Open \(\.$session) in \(.applicationName)",
                "Show Hermes session \(\.$session) in \(.applicationName)"
            ],
            shortTitle: "Session",
            systemImageName: "rectangle.stack"
        )

        AppShortcut(
            intent: OpenHermesChatIntent(),
            phrases: [
                "Open chat \(\.$chat) in \(.applicationName)",
                "Continue \(\.$chat) in \(.applicationName)"
            ],
            shortTitle: "Chat",
            systemImageName: "bubble.left.and.bubble.right"
        )

        AppShortcut(
            intent: StartHermesTaskIntent(),
            phrases: [
                "Start a Hermes task in \(.applicationName)",
                "New Hermes task in \(.applicationName)"
            ],
            shortTitle: "New Task",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: OpenRecentHermesSessionIntent(),
            phrases: [
                "Open recent Hermes session in \(.applicationName)",
                "Show my latest Hermes session in \(.applicationName)"
            ],
            shortTitle: "Recent Session",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: CheckHermesHealthIntent(),
            phrases: [
                "Check Hermes health in \(.applicationName)",
                "Is Hermes healthy in \(.applicationName)"
            ],
            shortTitle: "Health",
            systemImageName: "heart.text.square"
        )

        AppShortcut(
            intent: ContinueLastChatIntent(),
            phrases: [
                "Continue last chat in \(.applicationName)",
                "Open my last DaisyChat in \(.applicationName)"
            ],
            shortTitle: "Last Chat",
            systemImageName: "bubble.left.and.bubble.right"
        )
    }
}

private enum HermesIntentClientFactory {
    static func client() -> HermesAPIClient? {
        guard
            let token = KeychainSecrets.get(SharedUserDefaults.hermesAPIKey)?.nilIfBlank,
            let baseURL = ProviderEndpoint.normalizedBaseURL(
                SharedUserDefaults.shared.string(forKey: SharedUserDefaults.hermesBaseURL),
                defaultValue: "http://127.0.0.1:8642"
            )
        else {
            return nil
        }

        return HermesAPIClient(
            baseURL: baseURL,
            apiKey: token,
            sessionId: SharedUserDefaults.shared.string(forKey: SharedUserDefaults.hermesSessionId),
            sessionKey: SharedUserDefaults.shared.string(forKey: SharedUserDefaults.hermesSessionKey)
        )
    }
}
#endif
