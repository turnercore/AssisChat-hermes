//
//  HermesCache.swift
//  AssisChat
//
//

import Foundation

struct HermesCacheKey: Hashable, CustomStringConvertible {
    let baseURL: String
    let sessionId: String
    let sessionKey: String
    let apiKey: String

    init(baseURL: String?, sessionId: String?, sessionKey: String?, apiKey: String?) {
        self.baseURL = baseURL?.nilIfBlank ?? ""
        self.sessionId = sessionId?.nilIfBlank ?? ""
        self.sessionKey = sessionKey?.nilIfBlank ?? ""
        self.apiKey = apiKey?.nilIfBlank ?? ""
    }

    var description: String {
        "\(baseURL)|\(sessionId)|\(sessionKey)|\(apiKey.hashValue)"
    }
}

final class HermesCache {
    private struct Entry<Value> {
        let value: Value
        let key: HermesCacheKey
        let date: Date

        func usable(for key: HermesCacheKey, now: Date, maxAge: TimeInterval) -> Bool {
            self.key == key && now.timeIntervalSince(date) <= maxAge
        }
    }

    private var sessions: Entry<[HermesAPIClient.Session]>?
    private var messages: [String: Entry<[HermesAPIClient.SessionMessage]>] = [:]
    private var profileRefresh: Entry<Void>?
    private var now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func cachedSessions(for key: HermesCacheKey, maxAge: TimeInterval = 300) -> [HermesAPIClient.Session]? {
        guard let sessions, sessions.usable(for: key, now: now(), maxAge: maxAge) else { return nil }
        return sessions.value
    }

    func sessionsLastUpdated(for key: HermesCacheKey) -> Date? {
        guard let sessions, sessions.key == key else { return nil }
        return sessions.date
    }

    func storeSessions(_ sessions: [HermesAPIClient.Session], for key: HermesCacheKey) {
        self.sessions = Entry(value: sessions, key: key, date: now())
    }

    func cachedMessages(sessionId: String, key: HermesCacheKey, maxAge: TimeInterval = 300) -> [HermesAPIClient.SessionMessage]? {
        guard let entry = messages[sessionId], entry.usable(for: key, now: now(), maxAge: maxAge) else { return nil }
        return entry.value
    }

    func messagesLastUpdated(sessionId: String, key: HermesCacheKey) -> Date? {
        guard let entry = messages[sessionId], entry.key == key else { return nil }
        return entry.date
    }

    func storeMessages(_ messages: [HermesAPIClient.SessionMessage], sessionId: String, key: HermesCacheKey) {
        self.messages[sessionId] = Entry(value: messages, key: key, date: now())
    }

    func shouldRefreshProfiles(for key: HermesCacheKey, hasDiscoveredModels: Bool, maxAge: TimeInterval = 300) -> Bool {
        guard hasDiscoveredModels,
              let profileRefresh,
              profileRefresh.usable(for: key, now: now(), maxAge: maxAge)
        else {
            return true
        }

        return false
    }

    func markProfilesRefreshed(for key: HermesCacheKey) {
        profileRefresh = Entry(value: (), key: key, date: now())
    }
}
