//
//  ChatGPTAdapter.swift
//  AssisChat
//
//

import Foundation
import LDSwiftEventSource
import Combine
import SwiftUI

enum OpenAICompatibleChat {
    struct RequestBody: Encodable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Float
        let stream: Bool
    }

    struct ResponseBody: Decodable {
        let id: String
        let object: String
        let created: Int
        let choices: [Choice]
        let usage: Usage

        struct Choice: Decodable {
            let index: Int
            let message: ChatMessage
            let finish_reason: String?
        }

        struct Usage: Decodable {
            let prompt_tokens: Int
            let completion_tokens: Int
            let total_tokens: Int
        }
    }

    struct ResponseError: Decodable {
        struct Error: Decodable {
            let message: String?
            let type: String
        }

        let error: Error;
    }

    struct ChatMessage: Codable {
        let role: Role
        let content: Content

        enum Role: String, Codable {
            case system = "system"
            case user = "user"
            case assistant = "assistant"
        }

        enum Content: Codable {
            case text(String)
            case parts([Part])

            struct Part: Codable {
                let type: String
                let text: String?
                let imageURL: ImageURL?

                enum CodingKeys: String, CodingKey {
                    case type
                    case text
                    case imageURL = "image_url"
                }

                static func text(_ value: String) -> Part {
                    Part(type: "text", text: value, imageURL: nil)
                }

                static func imageURL(_ url: String) -> Part {
                    Part(type: "image_url", text: nil, imageURL: ImageURL(url: url, detail: "high"))
                }

                struct ImageURL: Codable {
                    let url: String
                    let detail: String?
                }
            }

            init(from decoder: Swift.Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let value = try? container.decode(String.self) {
                    self = .text(value)
                } else {
                    self = .parts((try? container.decode([Part].self)) ?? [])
                }
            }

            func encode(to encoder: Swift.Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .text(let value):
                    try container.encode(value)
                case .parts(let parts):
                    try container.encode(parts)
                }
            }

            var textValue: String {
                switch self {
                case .text(let value):
                    return value
                case .parts(let parts):
                    return parts.compactMap(\.text).joined(separator: "\n\n")
                }
            }
        }

        init(role: Role, content: String) {
            self.role = role
            self.content = .text(content)
        }

        init(role: Role, content: Content) {
            self.role = role
            self.content = content
        }

        func toPlainMessage(for chat: Chat) -> PlainMessage {
            var role: Message.Role

            switch(self.role) {
            case .system: role = .system
            case .user: role = .user
            case .assistant: role = .assistant
            }

            return PlainMessage(chat: chat, role: role, content: content.textValue, processedContent: nil)
        }

        static func fromMessage(message: Message) -> ChatMessage {
            var role: Role

            switch(message.role) {
            case .system: role = .system
            case .user: role = .user
            case .assistant: role = .assistant
            }

            let content = message.processedContent ?? message.content ?? ""
            if role == .user {
                return ChatMessage(role: role, content: .fromPromptText(content))
            }

            return ChatMessage(role: role, content: content)
        }
    }
}

extension OpenAICompatibleChat.ChatMessage.Content {
    static func fromPromptText(_ value: String) -> OpenAICompatibleChat.ChatMessage.Content {
        let attachments = ImagePromptPartExtractor.extract(from: value)
        guard !attachments.images.isEmpty else {
            return .text(value)
        }

        var parts: [OpenAICompatibleChat.ChatMessage.Content.Part] = []
        if let text = attachments.text.nilIfBlank {
            parts.append(.text(text))
        }
        parts.append(contentsOf: attachments.images.map { .imageURL($0) })
        return .parts(parts)
    }
}

private enum ImagePromptPartExtractor {
    private static let openingFence = "```data:image/"
    private static let closingFence = "```"

    static func extract(from value: String) -> (text: String, images: [String]) {
        var remaining = value[...]
        var text = ""
        var images: [String] = []

        while let openingRange = remaining.range(of: openingFence) {
            text += remaining[..<openingRange.lowerBound]

            guard let newline = remaining[openingRange.upperBound...].firstIndex(of: "\n") else {
                break
            }

            let mimeSubtype = remaining[openingRange.upperBound..<newline]
            let contentStart = remaining.index(after: newline)
            guard let closingRange = remaining[contentStart...].range(of: closingFence) else {
                break
            }

            let base64 = remaining[contentStart..<closingRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !base64.isEmpty {
                images.append("data:image/\(mimeSubtype),\(base64)")
            }

            remaining = remaining[closingRange.upperBound...]
        }

        text += remaining
        let remoteExtraction = extractRemoteImageURLs(from: text)
        images.append(contentsOf: remoteExtraction.images)

        return (
            remoteExtraction.text
                .replacingOccurrences(of: "Image attachment:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines),
            images
        )
    }

    private static func extractRemoteImageURLs(from value: String) -> (text: String, images: [String]) {
        let lines = value.components(separatedBy: .newlines)
        var outputLines: [String] = []
        var images: [String] = []
        var expectingImageURL = false

        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Image URL:") == .orderedSame {
                expectingImageURL = true
                continue
            }

            if expectingImageURL {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if isSupportedRemoteImageURL(trimmed) {
                    images.append(trimmed)
                    expectingImageURL = false
                    continue
                }

                outputLines.append("Image URL:")
                expectingImageURL = false
            }

            outputLines.append(line)
        }

        if expectingImageURL {
            outputLines.append("Image URL:")
        }

        return (outputLines.joined(separator: "\n"), images)
    }

    private static func isSupportedRemoteImageURL(_ value: String) -> Bool {
        guard
            let url = URL(string: value),
            ["http", "https"].contains(url.scheme?.lowercased())
        else {
            return false
        }

        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}

private func estimatedTokenCount(text: String) -> Int {
    max(1, text.count / 4)
}

// MARK: - Hermes

class HermesAdapter {
    struct Config {
        let baseURL: String?
        let apiKey: String
        let model: String
        let discoveredModels: [String]
        let sessionId: String?
        let sessionKey: String?

        var normalizedBaseURL: URL? {
            ProviderEndpoint.normalizedBaseURL(baseURL, defaultValue: "http://127.0.0.1:8642")
        }
    }

    let essentialFeature: EssentialFeature
    let config: Config

    init(essentialFeature: EssentialFeature, config: Config) {
        self.essentialFeature = essentialFeature
        self.config = config
    }
}

extension HermesAdapter: ChattingAdapter {
    var priority: Int { 0 }
    var identifier: String { "hermes" }
    var models: [String] {
        let allModels = [config.model] + config.discoveredModels + [Chat.HermesModel.default.rawValue]
        return Array(Set(allModels.filter { !$0.isEmpty })).sorted()
    }
    var defaultModel: String { config.model.nilIfBlank ?? Chat.HermesModel.default.rawValue }

    func sendMessageWithStream(chat: Chat, receivingMessage: Message) async throws {
        do {
            try await requestStream(messages: retrieveMessages(chat: chat, receivingMessage: receivingMessage), for: receivingMessage)
        } catch {
            if let error = error as? UnsuccessfulResponseError {
                receivingMessage.failedReason = convertStatusCodeToFailedReason(statusCode: error.responseCode)
                essentialFeature.persistData()
            } else {
                let error = error as NSError
                receivingMessage.failedReason = error.domain == NSURLErrorDomain ? .network : .unknown
                essentialFeature.persistData()
                essentialFeature.appendAlert(alert: ErrorAlert(message: LocalizedStringKey(error.localizedDescription)))
            }
        }
    }

    func sendMessage(message: Message) async throws -> [PlainMessage] {
        guard let chat = message.chat else { return [] }
        return try await request(messages: retrieveMessages(chat: chat, receivingMessage: message)).map { response in
            response.toPlainMessage(for: chat)
        }
    }

    func validateConfig() async throws {
        guard let baseURL = config.normalizedBaseURL else {
            throw ChattingError.validating(message: "Invalid Hermes URL")
        }

        do {
            let client = HermesAPIClient(baseURL: baseURL, apiKey: config.apiKey)
            _ = try await client.health()
            try await client.validateAuthentication()
        } catch HermesAPIClient.ClientError.invalidHeader {
            throw ChattingError.validating(message: "Invalid Hermes session header")
        } catch HermesAPIClient.ClientError.httpStatus(let status, let message) where status == 401 || status == 403 {
            throw ChattingError.validating(message: LocalizedStringKey("Hermes rejected the bearer token: \(message)"))
        } catch GeneralError.badURL {
            throw ChattingError.validating(message: "Invalid Hermes URL")
        } catch {
            throw error
        }
    }

    private func requestStream(messages: [OpenAICompatibleChat.ChatMessage], for message: Message) async throws {
        guard let url = config.normalizedBaseURL?.appendingPathComponent("v1/chat/completions") else {
            throw GeneralError.badURL
        }

        let handler = HermesChatStreamHandler()
        var eventConfig = EventSource.Config(handler: handler, url: url)
        eventConfig.method = "POST"
        eventConfig.headers = try hermesHeaders()
        eventConfig.body = try? JSONEncoder().encode(OpenAICompatibleChat.RequestBody(
            model: defaultModel,
            messages: messages,
            temperature: message.chat?.temperature.rawValue ?? Chat.Temperature.balanced.rawValue,
            stream: true
        ))

        var cancelable: AnyCancellable?
        let eventSource = EventSource(config: eventConfig)

        try await withCheckedThrowingContinuation { continuation in
            cancelable = handler.publisher.sink { completion in
                eventSource.stop()

                switch completion {
                case .finished: continuation.resume()
                case .failure(let error): continuation.resume(with: .failure(error))
                }
            } receiveValue: { value in
                switch value {
                case .delta(let text):
                    message.appendReceivingSlice(slice: text)
                case .progress(let text):
                    message.rawProcessedContent = text
                }
                self.essentialFeature.persistData()
            }

            eventSource.start()
        }

        _ = cancelable
    }

    private func request(messages: [OpenAICompatibleChat.ChatMessage]) async throws -> [OpenAICompatibleChat.ChatMessage] {
        guard let url = config.normalizedBaseURL?.appendingPathComponent("v1/chat/completions") else {
            throw GeneralError.badURL
        }

        let response: EssentialFeature.Response<OpenAICompatibleChat.ResponseBody, OpenAICompatibleChat.ResponseError> = try await essentialFeature.requestURL(
            urlString: url.absoluteString,
            init: .init(
                method: .POST,
                body: .json(data: OpenAICompatibleChat.RequestBody(
                    model: defaultModel,
                    messages: messages,
                    temperature: Chat.Temperature.balanced.rawValue,
                    stream: false
                )),
                headers: try hermesHeaders()
            )
        )

        guard let responseData = response.data else {
            let errorMessage = response.error?.error.message ?? "Unknown Hermes error"
            if response.response?.statusCode == 401 {
                throw ChattingError.sending(message: LocalizedStringKey("Hermes rejected the bearer token"))
            }
            throw ChattingError.sending(message: LocalizedStringKey(errorMessage))
        }

        return responseData.choices.map(\.message)
    }

    private func hermesHeaders() throws -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(config.apiKey)"
        ]

        if let sessionId = config.sessionId?.nilIfBlank {
            guard ProviderEndpoint.validHeaderValue(sessionId) else { throw HermesAPIClient.ClientError.invalidHeader }
            headers["X-Hermes-Session-Id"] = sessionId
        }

        if let sessionKey = config.sessionKey?.nilIfBlank {
            guard ProviderEndpoint.validHeaderValue(sessionKey), sessionKey.count <= 256 else {
                throw HermesAPIClient.ClientError.invalidHeader
            }
            headers["X-Hermes-Session-Key"] = sessionKey
        }

        return headers
    }

    private func retrieveMessages(chat: Chat, receivingMessage: Message) -> [OpenAICompatibleChat.ChatMessage] {
        let maxTokens = 128000
        let systemMessages: [OpenAICompatibleChat.ChatMessage]
        var currentTokens: Int

        if let chatSystemMessage = chat.systemMessage {
            systemMessages = [.init(role: .system, content: chatSystemMessage)]
            currentTokens = estimatedTokenCount(text: chatSystemMessage)
        } else {
            systemMessages = []
            currentTokens = 0
        }

        let receivingMessageIndex = chat.messages.lastIndex(of: receivingMessage) ?? chat.messages.count
        let historyMessagesReadyToSend = Array(chat.messages.prefix(receivingMessageIndex).suffix(Int(chat.historyLengthToSend)))

        var historyMessagesToSend: [OpenAICompatibleChat.ChatMessage] = []
        for message in historyMessagesReadyToSend.reversed() {
            currentTokens += estimatedTokenCount(text: message.rawProcessedContent ?? message.content ?? "")
            guard currentTokens < maxTokens else { break }
            historyMessagesToSend.append(.fromMessage(message: message))
        }

        return systemMessages + historyMessagesToSend.reversed()
    }

    private func convertStatusCodeToFailedReason(statusCode: Int) -> Message.FailedReason {
        switch statusCode {
        case 401: return .authentication
        case 429: return .rateLimit
        case 400...499: return .client
        case 500...599: return .server
        default: return .unknown
        }
    }
}

enum HermesStreamValue {
    case delta(String)
    case progress(String)
}

private struct HermesChatStreamHandler: EventHandler {
    struct Chunk: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let delta: Delta?

            struct Delta: Decodable {
                let content: String?
            }
        }
    }

    struct ToolProgress: Decodable {
        let name: String?
        let label: String?
        let status: String?
        let message: String?

        var display: String {
            [label, name, status, message]
                .compactMap { $0?.nilIfBlank }
                .joined(separator: " · ")
        }
    }

    let publisher = PassthroughSubject<HermesStreamValue, Error>()

    func onOpened() {}
    func onClosed() { publisher.send(completion: .finished) }
    func onComment(comment: String) {}
    func onError(error: Error) { publisher.send(completion: .failure(error)) }

    func onMessage(eventType: String, messageEvent: MessageEvent) {
        guard messageEvent.data != "[DONE]" else {
            publisher.send(completion: .finished)
            return
        }

        guard let data = messageEvent.data.data(using: .utf8) else { return }

        if eventType == "hermes.tool.progress",
           let progress = try? JSONDecoder().decode(ToolProgress.self, from: data),
           !progress.display.isEmpty {
            publisher.send(.progress(progress.display))
            return
        }

        guard
            let decodedData = try? JSONDecoder().decode(Chunk.self, from: data),
            let content = decodedData.choices.first?.delta?.content
        else {
            return
        }

        publisher.send(.delta(content))
    }
}

struct HermesAPIClient {
    enum ClientError: LocalizedError {
        case invalidHeader
        case httpStatus(Int, String)
        case emptyResponse(String)

        var errorDescription: String? {
            switch self {
            case .invalidHeader:
                return "Invalid Hermes session header"
            case .httpStatus(let status, let message):
                return "Hermes returned HTTP \(status): \(message)"
            case .emptyResponse(let path):
                return "Hermes returned an unexpected response for \(path)"
            }
        }
    }

    let baseURL: URL
    let apiKey: String
    var sessionId: String?
    var sessionKey: String?

    func health() async throws -> Health {
        try await get(path: "health")
    }

    func detailedHealth() async throws -> DetailedHealth {
        try await get(path: "health/detailed")
    }

    func capabilities() async throws -> Capabilities {
        try await get(path: "v1/capabilities")
    }

    func models() async throws -> ModelsResponse {
        try await get(path: "v1/models")
    }

    func profileCandidates() async -> [String] {
        var candidates: [String] = []

        if let models = try? await models() {
            candidates.append(contentsOf: models.data.map(\.id))
        }

        if let capabilities = try? await capabilities() {
            candidates.append(contentsOf: capabilities.profileCandidates)
        }

        return Self.uniqueProfiles(candidates)
    }

    func validateAuthentication() async throws {
        do {
            _ = try await models()
        } catch ClientError.httpStatus(let status, _) where status == 404 {
            _ = try await capabilities()
        }
    }

    func sessions(limit: Int = 50, offset: Int = 0) async throws -> SessionsResponse {
        do {
            return try await get(path: "api/sessions", queryItems: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ])
        } catch ClientError.httpStatus(let status, _) where status == 404 {
            return try await get(path: "v1/sessions", queryItems: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ])
        }
    }

    func sessionMessages(sessionId: String, limit: Int = 80, offset: Int = 0) async throws -> SessionMessagesResponse {
        let queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]

        do {
            return try await get(path: "api/sessions/\(sessionId)/messages", queryItems: queryItems)
        } catch ClientError.httpStatus(let status, _) where status == 404 {
            return try await get(path: "v1/sessions/\(sessionId)/messages", queryItems: queryItems)
        }
    }

    func apiSessions(limit: Int = 50, offset: Int = 0) async throws -> SessionsResponse {
        try await get(path: "api/sessions", queryItems: [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ])
    }

    func run(input: String, sessionId: String?) async throws -> RunStart {
        try await post(path: "v1/runs", body: RunRequest(input: input, sessionId: sessionId))
    }

    func runStatus(runId: String) async throws -> RunStatus {
        try await get(path: "v1/runs/\(runId)")
    }

    func stopRun(runId: String) async throws -> ActionStatus {
        try await post(path: "v1/runs/\(runId)/stop", body: EmptyBody())
    }

    func approveRun(runId: String, approved: Bool) async throws -> ActionStatus {
        try await post(path: "v1/runs/\(runId)/approval", body: ApprovalRequest(approved: approved))
    }

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let response: EssentialFeature.Response<T, HermesErrorResponse> = try await EssentialFeature.ResponseRequest.shared.requestURL(
            urlString: try url(path: path, queryItems: queryItems).absoluteString,
            init: .init(method: .GET, body: nil, headers: try headers())
        )

        guard let data = response.data else {
            throw clientError(response: response, path: path)
        }

        return data
    }

    private func post<T: Decodable, Body: Encodable>(path: String, body: Body) async throws -> T {
        let response: EssentialFeature.Response<T, HermesErrorResponse> = try await EssentialFeature.ResponseRequest.shared.requestURL(
            urlString: try url(path: path).absoluteString,
            init: .init(method: .POST, body: .json(data: body), headers: try headers())
        )

        guard let data = response.data else {
            throw clientError(response: response, path: path)
        }

        return data
    }

    private func headers() throws -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]

        if let sessionId = sessionId?.nilIfBlank {
            guard ProviderEndpoint.validHeaderValue(sessionId) else { throw ClientError.invalidHeader }
            headers["X-Hermes-Session-Id"] = sessionId
        }

        if let sessionKey = sessionKey?.nilIfBlank {
            guard ProviderEndpoint.validHeaderValue(sessionKey), sessionKey.count <= 256 else { throw ClientError.invalidHeader }
            headers["X-Hermes-Session-Key"] = sessionKey
        }

        return headers
    }

    private func url(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var url = baseURL
        for component in trimmedPath.split(separator: "/") {
            url.appendPathComponent(String(component))
        }

        if !queryItems.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw GeneralError.badURL
            }
            components.queryItems = queryItems
            guard let resolvedURL = components.url else { throw GeneralError.badURL }
            url = resolvedURL
        }

        return url
    }

    private func clientError<T: Decodable>(response: EssentialFeature.Response<T, HermesErrorResponse>, path: String) -> ClientError {
        let message = response.error?.displayMessage ?? "Unexpected response"
        if let statusCode = response.response?.statusCode {
            return .httpStatus(statusCode, message)
        }

        return .emptyResponse(path)
    }

    private static func uniqueProfiles(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values
            .compactMap { $0.nilIfBlank }
            .filter { value in
                guard !seen.contains(value) else { return false }
                seen.insert(value)
                return true
            }
    }

    struct Health: Decodable {
        let status: String

        enum CodingKeys: String, CodingKey {
            case ok
            case status
        }

        init(status: String) {
            self.status = status
        }

        init(from decoder: Swift.Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let status = try? container.decode(String.self, forKey: .status), !status.isEmpty {
                self.status = status
                return
            }

            if let ok = try? container.decode(Bool.self, forKey: .ok) {
                self.status = ok ? "healthy" : "error"
                return
            }

            self.status = "unknown"
        }
    }

    struct DetailedHealth: Decodable {
        let status: String?
        let activeSessions: Int?
        let runningAgents: Int?

        enum CodingKeys: String, CodingKey {
            case status
            case activeSessions = "active_sessions"
            case runningAgents = "running_agents"
        }
    }

    struct Capabilities: Decodable {
        let model: String?
        let models: [String]
        let profiles: [String]
        let features: [String: Bool]?
        let endpoints: [String: String]?
        let sessionKeyHeader: String?

        var profileCandidates: [String] {
            HermesAPIClient.uniqueProfiles(([model].compactMap { $0 }) + models + profiles)
        }

        enum CodingKeys: String, CodingKey {
            case model
            case models
            case profiles
            case features
            case endpoints
            case sessionKeyHeader = "session_key_header"
        }

        init(from decoder: Swift.Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            model = try container.decodeIfPresent(String.self, forKey: .model)
            models = container.decodeFlexibleStringArrayIfPresent(forKey: .models)
            profiles = container.decodeFlexibleStringArrayIfPresent(forKey: .profiles)

            let rawFeatures = (try? container.decodeIfPresent([String: JSONValue].self, forKey: .features)) ?? [:]
            features = rawFeatures.compactMapValues(\.boolValue)

            let rawEndpoints = (try? container.decodeIfPresent([String: JSONValue].self, forKey: .endpoints)) ?? [:]
            endpoints = rawEndpoints.compactMapValues(\.endpointPath)

            sessionKeyHeader = try container.decodeIfPresent(String.self, forKey: .sessionKeyHeader)
                ?? rawFeatures["session_key_header"]?.stringValue
        }
    }

    struct ModelsResponse: Decodable {
        let data: [Model]

        enum CodingKeys: String, CodingKey {
            case data
            case models
            case profiles
        }

        init(from decoder: Swift.Decoder) throws {
            if let values = try? decoder.singleValueContainer().decode([Model].self) {
                data = values
                return
            }

            if let values = try? decoder.singleValueContainer().decode([String].self) {
                data = values.map(Model.init(id:))
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let values = try? container.decodeIfPresent([Model].self, forKey: .data) {
                data = values
            } else if let values = try? container.decodeIfPresent([Model].self, forKey: .models) {
                data = values
            } else if let values = try? container.decodeIfPresent([Model].self, forKey: .profiles) {
                data = values
            } else {
                data = (
                    container.decodeFlexibleStringArrayIfPresent(forKey: .data)
                    + container.decodeFlexibleStringArrayIfPresent(forKey: .models)
                    + container.decodeFlexibleStringArrayIfPresent(forKey: .profiles)
                ).map(Model.init(id:))
            }
        }

        struct Model: Decodable, Identifiable {
            let id: String

            enum CodingKeys: String, CodingKey {
                case id
                case name
                case model
                case profile
                case slug
            }

            init(id: String) {
                self.id = id
            }

            init(from decoder: Swift.Decoder) throws {
                if let value = try? decoder.singleValueContainer().decode(String.self) {
                    id = value
                    return
                }

                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = container.decodeFlexibleStringIfPresent(forKey: .id)
                    ?? container.decodeFlexibleStringIfPresent(forKey: .name)
                    ?? container.decodeFlexibleStringIfPresent(forKey: .model)
                    ?? container.decodeFlexibleStringIfPresent(forKey: .profile)
                    ?? container.decodeFlexibleStringIfPresent(forKey: .slug)
                    ?? ""
            }
        }
    }

    struct SessionsResponse: Decodable {
        let sessions: [Session]?
        let data: [Session]?

        var items: [Session] { sessions ?? data ?? [] }
    }

    struct Session: Decodable, Identifiable {
        private let rawId: String?
        private let sessionId: String?
        let title: String?
        let source: String?
        let updatedAt: String?

        init(id: String, title: String?, source: String?, updatedAt: String?) {
            rawId = id
            sessionId = nil
            self.title = title
            self.source = source
            self.updatedAt = updatedAt
        }

        var id: String {
            rawId?.nilIfBlank
                ?? sessionId?.nilIfBlank
                ?? [title, source, updatedAt].compactMap { $0?.nilIfBlank }.joined(separator: "|").nilIfBlank
                ?? "session"
        }

        var displayTitle: String {
            title?.nilIfBlank ?? source?.nilIfBlank ?? id
        }

        var sourceKind: HermesSessionSourceKind {
            HermesSessionSourceKind(rawValue: source)
        }

        enum CodingKeys: String, CodingKey {
            case rawId = "id"
            case sessionId = "session_id"
            case title
            case source
            case updatedAt = "updated_at"
        }
    }

    struct SessionMessagesResponse: Decodable {
        let messages: [SessionMessage]?
        let data: [SessionMessage]?

        var items: [SessionMessage] { messages ?? data ?? [] }
    }

    struct SessionMessage: Decodable, Identifiable {
        private let rawId: JSONValue?
        private let messageId: JSONValue?
        let role: String?
        private let rawContent: JSONValue?
        private let text: JSONValue?
        private let createdAt: JSONValue?

        var id: String {
            rawId?.description.nilIfBlank
                ?? messageId?.description.nilIfBlank
                ?? [role, createdAt?.description, content].compactMap { $0?.nilIfBlank }.joined(separator: "|").nilIfBlank
                ?? "message"
        }

        var content: String? {
            rawContent?.description.nilIfBlank ?? text?.description.nilIfBlank
        }

        enum CodingKeys: String, CodingKey {
            case rawId = "id"
            case messageId = "message_id"
            case role
            case rawContent = "content"
            case text
            case createdAt = "created_at"
        }
    }

    struct RunRequest: Encodable {
        let input: String
        let sessionId: String?

        enum CodingKeys: String, CodingKey {
            case input
            case sessionId = "session_id"
        }
    }

    struct RunStart: Decodable {
        let runId: String
        let status: String

        enum CodingKeys: String, CodingKey {
            case runId = "run_id"
            case status
        }
    }

    struct RunStatus: Decodable {
        let runId: String?
        let status: String
        let sessionId: String?
        let model: String?
        let output: String?

        enum CodingKeys: String, CodingKey {
            case runId = "run_id"
            case status
            case sessionId = "session_id"
            case model
            case output
        }
    }

    struct ActionStatus: Decodable {
        let status: String
    }

    struct ApprovalRequest: Encodable {
        let approved: Bool
    }

    struct EmptyBody: Encodable {}

    struct HermesErrorResponse: Decodable {
        let message: String?
        let detail: String?
        let error: OpenAIError?

        var displayMessage: String? {
            message ?? detail ?? error?.message
        }

        struct OpenAIError: Decodable {
            let message: String?
            let type: String?
            let code: String?
        }
    }
}

enum HermesSessionSourceKind {
    case api
    case cli
    case cron
    case discord
    case tui
    case web
    case archived
    case unknown

    init(rawValue: String?) {
        let value = rawValue?.lowercased() ?? ""
        if value.contains("cron") || value.contains("job") {
            self = .cron
        } else if value.contains("discord") {
            self = .discord
        } else if value.contains("api") || value.contains("server") {
            self = .api
        } else if value.contains("cli") || value.contains("terminal") {
            self = .cli
        } else if value.contains("tui") {
            self = .tui
        } else if value.contains("web") || value.contains("dashboard") {
            self = .web
        } else {
            self = .unknown
        }
    }

    var systemImage: String {
        switch self {
        case .api:
            return "point.3.connected.trianglepath.dotted"
        case .cli:
            return "terminal"
        case .cron:
            return "clock.badge.checkmark"
        case .discord:
            return "message.badge"
        case .tui:
            return "rectangle.inset.filled.and.person.filled"
        case .web:
            return "globe"
        case .archived:
            return "archivebox"
        case .unknown:
            return "sparkles"
        }
    }
}

enum ProviderEndpoint {
    static func normalizedBaseURL(_ value: String?, defaultValue: String) -> URL? {
        let rawValue = value?.nilIfBlank ?? defaultValue
        guard !rawValue.contains(where: \.isNewline), !rawValue.contains("\0") else { return nil }

        var trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }

        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased()), url.host != nil else {
            return nil
        }

        return url
    }

    static func validHeaderValue(_ value: String) -> Bool {
        !value.unicodeScalars.contains { scalar in
            scalar.value == 0 || scalar.value == 10 || scalar.value == 13
        }
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(JSONValue.self, forKey: key) {
            return value.description
        }
        return nil
    }

    func decodeFlexibleStringArrayIfPresent(forKey key: Key) -> [String] {
        if let values = try? decodeIfPresent([String].self, forKey: key) {
            return values
        }

        if let values = try? decodeIfPresent([JSONValue].self, forKey: key) {
            return values.compactMap { $0.profileName }
        }

        if let values = try? decodeIfPresent([String: JSONValue].self, forKey: key) {
            return values
                .flatMap { key, value in
                    [value.profileName, key].compactMap { $0 }
                }
                .compactMap { $0.nilIfBlank }
        }

        if let value = try? decodeIfPresent(JSONValue.self, forKey: key),
           let profileName = value.profileName {
            return [profileName]
        }

        return []
    }
}

private enum JSONValue: Decodable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Swift.Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    var description: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .object(let value):
            return value
                .map { "\($0.key): \($0.value.description)" }
                .sorted()
                .joined(separator: "\n")
        case .array(let value):
            return value.map(\.description).joined(separator: "\n")
        case .null:
            return ""
        }
    }

    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var endpointPath: String? {
        switch self {
        case .string(let value):
            return value
        case .object(let value):
            return value["path"]?.stringValue
        default:
            return nil
        }
    }

    var profileName: String? {
        switch self {
        case .string(let value):
            return value.nilIfBlank
        case .number, .bool:
            return description.nilIfBlank
        case .object(let value):
            return value["id"]?.profileName
                ?? value["name"]?.profileName
                ?? value["model"]?.profileName
                ?? value["profile"]?.profileName
                ?? value["slug"]?.profileName
        default:
            return nil
        }
    }
}

extension EssentialFeature {
    struct ResponseRequest {
        static let shared = ResponseRequest()

        func requestURL<ResponseData: Decodable, ResponseError: Decodable>(urlString: String, init requestInit: RequestInit) async throws -> Response<ResponseData, ResponseError> {
            guard let url = URL(string: urlString) else {
                throw GeneralError.badURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = requestInit.method.rawValue

            if let body = requestInit.body {
                request.httpBody = body.data
            }

            requestInit.headers?.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

            let (data, response) = try await URLSession.shared.data(for: request)
            return Response(
                response: response as? HTTPURLResponse,
                data: try? JSONDecoder().decode(ResponseData.self, from: data),
                error: try? JSONDecoder().decode(ResponseError.self, from: data)
            )
        }
    }
}
