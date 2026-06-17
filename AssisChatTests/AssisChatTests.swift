//
//  AssisChatTests.swift
//  AssisChatTests
//

import XCTest
@testable import AssisChat

final class AssisChatTests: XCTestCase {
    func testProviderEndpointNormalizesBaseURL() {
        let url = ProviderEndpoint.normalizedBaseURL(" http://example.local:8642/ ", defaultValue: "http://127.0.0.1:8642")

        XCTAssertEqual(url?.absoluteString, "http://example.local:8642")
    }

    func testProviderEndpointRejectsInvalidBaseURL() {
        XCTAssertNil(ProviderEndpoint.normalizedBaseURL("file:///tmp/hermes", defaultValue: "http://127.0.0.1:8642"))
        XCTAssertNil(ProviderEndpoint.normalizedBaseURL("http://example.com\nAuthorization: Bearer secret", defaultValue: "http://127.0.0.1:8642"))
    }

    func testHermesHeaderValidationRejectsControlCharacters() {
        XCTAssertTrue(ProviderEndpoint.validHeaderValue("agent:main:ios"))
        XCTAssertFalse(ProviderEndpoint.validHeaderValue("agent:main\nbad"))
        XCTAssertFalse(ProviderEndpoint.validHeaderValue("agent:main\rbad"))
        XCTAssertFalse(ProviderEndpoint.validHeaderValue("agent:main\0bad"))
    }

    func testHermesCapabilitiesDecoding() throws {
        let json = """
        {
          "object": "hermes.api_server.capabilities",
          "platform": "hermes-agent",
          "model": "hermes-agent",
          "features": {
            "chat_completions": true,
            "run_stop": true,
            "run_approval": false
          },
          "session_key_header": "X-Hermes-Session-Key"
        }
        """.data(using: .utf8)!

        let capabilities = try JSONDecoder().decode(HermesAPIClient.Capabilities.self, from: json)

        XCTAssertEqual(capabilities.model, "hermes-agent")
        XCTAssertEqual(capabilities.features?["chat_completions"], true)
        XCTAssertEqual(capabilities.features?["run_stop"], true)
        XCTAssertEqual(capabilities.features?["run_approval"], false)
        XCTAssertEqual(capabilities.sessionKeyHeader, "X-Hermes-Session-Key")
    }

    func testHermesCacheReturnsFreshSessionsForMatchingKey() throws {
        var now = Date(timeIntervalSince1970: 100)
        let key = HermesCacheKey(baseURL: "http://hermes.local", sessionId: nil, sessionKey: nil, apiKey: "secret")
        let cache = HermesCache(now: { now })
        let sessions = try decodeSessions()

        cache.storeSessions(sessions, for: key)

        now = Date(timeIntervalSince1970: 399)
        XCTAssertEqual(cache.cachedSessions(for: key)?.first?.id, "session-1")
        XCTAssertEqual(cache.sessionsLastUpdated(for: key), Date(timeIntervalSince1970: 100))
    }

    func testHermesCacheExpiresAndSeparatesKeys() throws {
        var now = Date(timeIntervalSince1970: 100)
        let key = HermesCacheKey(baseURL: "http://hermes.local", sessionId: nil, sessionKey: nil, apiKey: "secret")
        let otherKey = HermesCacheKey(baseURL: "http://other.local", sessionId: nil, sessionKey: nil, apiKey: "secret")
        let cache = HermesCache(now: { now })

        cache.storeSessions(try decodeSessions(), for: key)

        XCTAssertNil(cache.cachedSessions(for: otherKey))
        now = Date(timeIntervalSince1970: 401)
        XCTAssertNil(cache.cachedSessions(for: key, maxAge: 300))
    }

    func testHermesCacheProfileRefreshTTL() {
        var now = Date(timeIntervalSince1970: 100)
        let key = HermesCacheKey(baseURL: "http://hermes.local", sessionId: nil, sessionKey: nil, apiKey: "secret")
        let cache = HermesCache(now: { now })

        XCTAssertTrue(cache.shouldRefreshProfiles(for: key, hasDiscoveredModels: false))
        XCTAssertTrue(cache.shouldRefreshProfiles(for: key, hasDiscoveredModels: true))

        cache.markProfilesRefreshed(for: key)
        XCTAssertFalse(cache.shouldRefreshProfiles(for: key, hasDiscoveredModels: true))

        now = Date(timeIntervalSince1970: 401)
        XCTAssertTrue(cache.shouldRefreshProfiles(for: key, hasDiscoveredModels: true, maxAge: 300))
    }

    func testKeychainSecretRoundTrip() throws {
        let key = "test:secret:\(UUID().uuidString)"
        defer { try? KeychainSecrets.delete(key) }

        try KeychainSecrets.set("secret-value", for: key)
        XCTAssertEqual(KeychainSecrets.get(key), "secret-value")

        try KeychainSecrets.set(nil, for: key)
        XCTAssertNil(KeychainSecrets.get(key))
    }

    private func decodeSessions() throws -> [HermesAPIClient.Session] {
        let json = """
        {
          "sessions": [
            {
              "id": "session-1",
              "title": "Investigate cache",
              "source": "api",
              "updated_at": "2026-06-17T10:00:00Z"
            }
          ]
        }
        """.data(using: .utf8)!

        return try JSONDecoder().decode(HermesAPIClient.SessionsResponse.self, from: json).items
    }
}
