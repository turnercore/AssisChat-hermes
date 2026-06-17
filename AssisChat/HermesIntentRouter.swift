//
//  HermesIntentRouter.swift
//  AssisChat
//

import Foundation

enum HermesIntentRoute {
    case newTask(prompt: String?)
    case recentSession(HermesAPIClient.Session)
    case localChat(id: String)
    case continueLastChat
    case health
}

enum HermesIntentRouter {
    private enum Route: String {
        case newTask
        case recentSession
        case localChat
        case continueLastChat
        case health
    }

    static func requestNewTask(prompt: String? = nil) {
        setRoute(.newTask)
        if let prompt = prompt?.nilIfBlank {
            SharedUserDefaults.shared.set(prompt, forKey: SharedUserDefaults.hermesPendingIntentPrompt)
        }
    }

    static func requestRecentSession(_ session: HermesAPIClient.Session) {
        setRoute(.recentSession)
        SharedUserDefaults.shared.set(session.id, forKey: SharedUserDefaults.hermesPendingIntentSessionId)
        SharedUserDefaults.shared.set(session.title, forKey: SharedUserDefaults.hermesPendingIntentSessionTitle)
        SharedUserDefaults.shared.set(session.source, forKey: SharedUserDefaults.hermesPendingIntentSessionSource)
        SharedUserDefaults.shared.set(session.updatedAt, forKey: SharedUserDefaults.hermesPendingIntentSessionUpdatedAt)
    }

    static func requestLocalChat(id: String) {
        setRoute(.localChat)
        SharedUserDefaults.shared.set(id, forKey: SharedUserDefaults.hermesPendingIntentChatId)
    }

    static func requestContinueLastChat() {
        setRoute(.continueLastChat)
    }

    static func requestHealth() {
        setRoute(.health)
    }

    static func request(url: URL) -> Bool {
        guard url.scheme?.lowercased() == "daisychat" else { return false }

        let host = url.host?.lowercased()
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let prompt = queryItems.first(where: { $0.name == "prompt" })?.value

        switch host {
        case "new", "task":
            requestNewTask(prompt: prompt)
            return true
        case "health":
            requestHealth()
            return true
        case "session":
            guard let id = pathComponents.first?.nilIfBlank else { return false }
            requestRecentSession(
                HermesAPIClient.Session(
                    id: id,
                    title: queryItems.first(where: { $0.name == "title" })?.value,
                    source: queryItems.first(where: { $0.name == "source" })?.value,
                    updatedAt: nil
                )
            )
            return true
        case "chat":
            guard let id = pathComponents.first?.nilIfBlank else { return false }
            requestLocalChat(id: id)
            return true
        default:
            return false
        }
    }

    static func consume() -> HermesIntentRoute? {
        defer { clear() }

        guard
            let rawRoute = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.hermesPendingIntentRoute),
            let route = Route(rawValue: rawRoute)
        else {
            return nil
        }

        switch route {
        case .newTask:
            return .newTask(prompt: SharedUserDefaults.shared.string(forKey: SharedUserDefaults.hermesPendingIntentPrompt))
        case .recentSession:
            guard let id = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.hermesPendingIntentSessionId)?.nilIfBlank else {
                return .newTask(prompt: nil)
            }

            let session = HermesAPIClient.Session(
                id: id,
                title: SharedUserDefaults.shared.string(forKey: SharedUserDefaults.hermesPendingIntentSessionTitle),
                source: SharedUserDefaults.shared.string(forKey: SharedUserDefaults.hermesPendingIntentSessionSource),
                updatedAt: SharedUserDefaults.shared.string(forKey: SharedUserDefaults.hermesPendingIntentSessionUpdatedAt)
            )
            return .recentSession(session)
        case .localChat:
            guard let id = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.hermesPendingIntentChatId)?.nilIfBlank else {
                return .newTask(prompt: nil)
            }
            return .localChat(id: id)
        case .continueLastChat:
            return .continueLastChat
        case .health:
            return .health
        }
    }

    private static func setRoute(_ route: Route) {
        SharedUserDefaults.shared.set(route.rawValue, forKey: SharedUserDefaults.hermesPendingIntentRoute)
    }

    private static func clear() {
        SharedUserDefaults.shared.removeObject(forKey: SharedUserDefaults.hermesPendingIntentRoute)
        SharedUserDefaults.shared.removeObject(forKey: SharedUserDefaults.hermesPendingIntentSessionId)
        SharedUserDefaults.shared.removeObject(forKey: SharedUserDefaults.hermesPendingIntentSessionTitle)
        SharedUserDefaults.shared.removeObject(forKey: SharedUserDefaults.hermesPendingIntentSessionSource)
        SharedUserDefaults.shared.removeObject(forKey: SharedUserDefaults.hermesPendingIntentSessionUpdatedAt)
        SharedUserDefaults.shared.removeObject(forKey: SharedUserDefaults.hermesPendingIntentPrompt)
        SharedUserDefaults.shared.removeObject(forKey: SharedUserDefaults.hermesPendingIntentChatId)
    }
}
