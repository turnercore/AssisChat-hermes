//
//  HermesSessionDetailView.swift
//  AssisChat
//

import SwiftUI

struct HermesSessionDetailView: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature
    @Environment(\.hermesTheme) private var theme

    let session: HermesAPIClient.Session

    @State private var messages: [HermesAPIClient.SessionMessage] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var loadedCacheKey: HermesCacheKey?
    @State private var hasMoreMessages = false

    private let messagePageSize = 80

    var body: some View {
        VStack(spacing: 0) {
            header

            if loading && messages.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorText, messages.isEmpty {
                HermesSessionPlaceholder(title: "Could not load session", systemImage: "exclamationmark.triangle", description: errorText)
            } else if messages.isEmpty {
                HermesSessionPlaceholder(title: "No Messages", systemImage: "bubble.left.and.bubble.right", description: "Hermes returned no messages for this session.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if hasMoreMessages {
                            Button {
                                Task { await loadMoreMessages() }
                            } label: {
                                Label(loading ? "Loading more" : "Load more messages", systemImage: "arrow.up.circle")
                            }
                            .font(.footnote.weight(.semibold))
                            .disabled(loading)
                        }

                        if let updatedAt = settingsFeature.cachedHermesMessagesLastUpdated(sessionId: session.id) {
                            Label("Last updated \(updatedAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ForEach(messages) { message in
                            HermesSessionMessageRow(message: message)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    await loadMessages(force: true)
                }
            }
        }
        .background(HermesWorkspaceBackground(theme: theme).ignoresSafeArea())
        .task(id: "\(session.id)|\(settingsFeature.hermesCacheKey)") {
            await loadMessages()
        }
        .toolbar {
            Button {
                Task { await loadMessages(force: true) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(loading)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: session.sourceKind.systemImage)
                .font(.title3)
                .foregroundColor(theme.primary)
                .frame(width: 36, height: 36)
                .background(theme.primary.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.primary.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let source = session.source?.nilIfBlank {
                        Text(source)
                    }
                    if let updatedAt = session.updatedAt?.nilIfBlank {
                        Text(updatedAt)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    @MainActor
    private func loadMessages(force: Bool = false) async {
        guard let client else {
            errorText = "Configure Hermes first."
            loadedCacheKey = settingsFeature.hermesCacheKey
            return
        }

        let cacheKey = settingsFeature.hermesCacheKey
        if let cached = settingsFeature.cachedHermesMessagesIfUsable(sessionId: session.id), !force {
            messages = cached
            hasMoreMessages = cached.count >= messagePageSize
            errorText = nil
            loadedCacheKey = cacheKey
            return
        }

        if !force, loadedCacheKey == cacheKey, !messages.isEmpty {
            return
        }

        if messages.isEmpty,
           let cached = settingsFeature.cachedHermesMessagesIfUsable(sessionId: session.id, maxAge: 1_800) {
            messages = cached
            hasMoreMessages = cached.count >= messagePageSize
        }

        guard !loading else { return }

        loading = true
        defer { loading = false }

        do {
            let loadedMessages = try await client.sessionMessages(sessionId: session.id, limit: messagePageSize, offset: 0).items
            messages = loadedMessages
            hasMoreMessages = loadedMessages.count == messagePageSize
            settingsFeature.storeHermesMessages(loadedMessages, for: session.id)
            errorText = nil
            loadedCacheKey = cacheKey
        } catch is CancellationError {
            return
        } catch {
            errorText = error.localizedDescription
            loadedCacheKey = cacheKey
        }
    }

    private var client: HermesAPIClient? {
        guard
            let token = settingsFeature.configuredHermesAPIKey?.nilIfBlank,
            let baseURL = ProviderEndpoint.normalizedBaseURL(settingsFeature.configuredHermesBaseURL, defaultValue: "http://127.0.0.1:8642")
        else {
            return nil
        }

        return HermesAPIClient(
            baseURL: baseURL,
            apiKey: token,
            sessionId: settingsFeature.configuredHermesSessionId,
            sessionKey: settingsFeature.configuredHermesSessionKey
        )
    }

    @MainActor
    private func loadMoreMessages() async {
        guard !loading, let client, hasMoreMessages else { return }

        loading = true
        defer { loading = false }

        do {
            let nextMessages = try await client.sessionMessages(
                sessionId: session.id,
                limit: messagePageSize,
                offset: messages.count
            ).items
            messages = mergeMessages(messages + nextMessages)
            hasMoreMessages = nextMessages.count == messagePageSize
            settingsFeature.storeHermesMessages(messages, for: session.id)
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func mergeMessages(_ messages: [HermesAPIClient.SessionMessage]) -> [HermesAPIClient.SessionMessage] {
        var seen = Set<String>()
        return messages.filter { message in
            guard !seen.contains(message.id) else { return false }
            seen.insert(message.id)
            return true
        }
    }
}

#if DEBUG
private struct HermesSessionDetailPreviewGallery: View {
    @Environment(\.hermesTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                previewSection("cached messages shown immediately") {
                    HermesSessionMessageRow(message: Self.message(role: "user", content: "Summarize the failing iOS session refresh path."))
                    HermesSessionMessageRow(message: Self.message(role: "assistant", content: "Using cached messages while the refresh runs in the background."))
                }

                previewSection("refresh failure with stale messages preserved") {
                    Label("Could not refresh: network connection lost", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    HermesSessionMessageRow(message: Self.message(role: "assistant", content: "Stale content remains readable after a refresh error."))
                }

                previewSection("empty messages") {
                    HermesSessionPlaceholder(title: "No Messages", systemImage: "bubble.left.and.bubble.right", description: "Hermes returned no messages for this session.")
                        .frame(height: 220)
                }

                previewSection("selected session removed") {
                    HermesSessionPlaceholder(title: "Session Removed", systemImage: "arrow.uturn.backward.circle", description: "After refresh, the app returns to the new-session pane instead of showing a stale detail.")
                        .frame(height: 220)
                }
            }
            .padding()
        }
        .background(HermesWorkspaceBackground(theme: theme).ignoresSafeArea())
    }

    private func previewSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
            content()
        }
    }

    private static func message(role: String, content: String) -> HermesAPIClient.SessionMessage {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "role": "\(role)",
          "content": "\(content)"
        }
        """.data(using: .utf8)!

        return try! JSONDecoder().decode(HermesAPIClient.SessionMessage.self, from: json)
    }
}

struct HermesSessionDetailPreviewGallery_Previews: PreviewProvider {
    static var previews: some View {
        HermesSessionDetailPreviewGallery()
    }
}
#endif

private struct HermesSessionPlaceholder: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HermesSessionMessageRow: View {
    @Environment(\.hermesTheme) private var theme

    let message: HermesAPIClient.SessionMessage
    @State private var expanded = false

    private var isUser: Bool {
        message.role?.lowercased() == "user"
    }

    private var isTool: Bool {
        let role = message.role?.lowercased() ?? ""
        return role.contains("tool") || role.contains("function")
    }

    private var toolContent: ToolMessageContent? {
        ToolMessageContent(rawContent: message.content ?? "")
    }

    private var compactUserContent: CompactSessionContent? {
        guard isUser else { return nil }
        return CompactSessionContent.userInjection(rawContent: message.content ?? "")
    }

    var body: some View {
        HStack {
            if isUser && compactUserContent == nil {
                Spacer(minLength: 44)
            }

            if isTool {
                toolCard
            } else if compactUserContent != nil {
                compactUserCard
            } else {
                messageBubble
            }

            if !isUser || compactUserContent != nil {
                Spacer(minLength: 44)
            }
        }
    }

    private var messageBubble: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role?.uppercased() ?? "MESSAGE")
                .font(.caption2.weight(.semibold))
                .foregroundColor(theme.mutedForeground)
            Text(message.content?.nilIfBlank ?? "No content")
                .font(.body)
                .foregroundColor(message.content?.nilIfBlank == nil ? theme.mutedForeground : (isUser ? theme.userBubbleForeground : theme.cardForeground))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(isUser ? theme.userBubble : theme.card)
        .foregroundColor(isUser ? theme.userBubbleForeground : theme.cardForeground)
        .cornerRadius(12)
    }

    private var compactUserCard: some View {
        let content = compactUserContent ?? CompactSessionContent(label: "User context", detail: "Long injected user context", output: message.content ?? "")

        return VStack(alignment: .leading, spacing: 8) {
            compactHeader(
                systemImage: "text.badge.checkmark",
                title: content.label,
                subtitle: expanded ? content.detail : content.previewLabel
            )

            Text(expanded ? content.output : content.preview)
                .font(theme.monoFont(size: 12, relativeTo: .caption))
                .foregroundColor(content.output.nilIfBlank == nil ? theme.mutedForeground : theme.cardForeground)
                .lineLimit(expanded ? nil : 5)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: 620, alignment: .leading)
        .background(theme.userBubble.opacity(0.58))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.userBubbleBorder.opacity(0.7), lineWidth: 1)
        )
        .cornerRadius(12)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            toggleExpanded()
        }
    }

    private var toolCard: some View {
        let content = toolContent ?? ToolMessageContent(label: "Tool", output: message.content ?? "")

        return VStack(alignment: .leading, spacing: 8) {
            toolHeader(content: content)

            if expanded {
                Text(content.output.nilIfBlank ?? "No output")
                    .font(theme.monoFont(size: 12, relativeTo: .caption))
                    .foregroundColor(content.output.nilIfBlank == nil ? theme.mutedForeground : theme.cardForeground)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, expanded ? 10 : 7)
        .frame(maxWidth: expanded ? 620 : 520, alignment: .leading)
        .background(theme.card.opacity(expanded ? 0.72 : 0.48))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.border.opacity(expanded ? 0.7 : 0.42), lineWidth: 1)
        )
        .cornerRadius(10)
        .opacity(expanded ? 1 : 0.86)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            toggleExpanded()
        }
    }

    private func toolHeader(content: ToolMessageContent) -> some View {
        HStack(spacing: 7) {
            Image(systemName: content.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.primary)
                .frame(width: 16)

            Text(content.label)
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.foreground)
                .lineLimit(1)

            if !expanded {
                Text(content.inlinePreview)
                    .font(theme.monoFont(size: 11, relativeTo: .caption2))
                    .foregroundColor(theme.mutedForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundColor(theme.mutedForeground)
        }
    }

    private func compactHeader(systemImage: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.foreground)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(theme.mutedForeground)
            }
            Spacer()
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundColor(theme.mutedForeground)
        }
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.16)) {
            expanded.toggle()
        }
    }
}

private struct CompactSessionContent {
    let label: String
    let detail: String
    let output: String

    var previewLabel: String {
        "\(detail) preview"
    }

    var preview: String {
        let normalized = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(8)
            .joined(separator: "\n")
        let preview = normalized.count > 700 ? String(normalized.prefix(700)) + "..." : normalized
        return preview.nilIfBlank ?? "No content"
    }

    static func userInjection(rawContent: String) -> CompactSessionContent? {
        guard let content = rawContent.nilIfBlank else { return nil }
        let lowercased = content.lowercased()
        let isContextCompaction = lowercased.contains("context compaction") || lowercased.contains("reference only")
        let isLongInjectedContext = content.count > 1_200 && (
            lowercased.contains("historical task snapshot")
            || lowercased.contains("system prompt")
            || lowercased.contains("persistent memory")
        )

        guard isContextCompaction || isLongInjectedContext else { return nil }

        return CompactSessionContent(
            label: "User context",
            detail: isContextCompaction ? "Context compaction" : "Injected context",
            output: content
        )
    }
}

private struct ToolMessageContent {
    let label: String
    let output: String

    var systemImage: String {
        let value = label.lowercased()
        if value.contains("terminal") || value.contains("shell") || value.contains("bash") {
            return "terminal"
        }
        if value.contains("file") || value.contains("read") || value.contains("write") {
            return "doc.text"
        }
        if value.contains("web") || value.contains("browser") || value.contains("search") {
            return "globe"
        }
        if value.contains("git") {
            return "point.3.connected.trianglepath.dotted"
        }
        return "wrench.and.screwdriver"
    }

    var inlinePreview: String {
        let value = output
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.count > 140 ? String(value.prefix(140)) + "..." : value
    }

    var preview: String {
        let normalized = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(12)
            .joined(separator: "\n")
        return normalized.count > 900 ? String(normalized.prefix(900)) + "..." : normalized
    }

    init(label: String, output: String) {
        self.label = label.nilIfBlank ?? "Tool"
        self.output = output.nilIfBlank ?? "No output"
    }

    init?(rawContent: String) {
        guard let content = rawContent.nilIfBlank else { return nil }

        if
            let data = content.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(JSONToolOutput.self, from: data)
        {
            let decodedOutput = decoded.output.nilIfBlank ?? content
            label = decoded.label.nilIfBlank ?? Self.inferredLabel(from: decodedOutput)
            output = decodedOutput
            return
        }

        label = Self.inferredLabel(from: content)
        output = content
    }

    private static func inferredLabel(from output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("["),
           let closeIndex = trimmed.firstIndex(of: "]") {
            let name = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeIndex])
            if let name = name.nilIfBlank {
                return name
            }
        }

        let lowercased = trimmed.lowercased()
        if lowercased.contains("terminal") || lowercased.contains(" ran `") {
            return "terminal"
        }
        if lowercased.contains("git ") {
            return "git"
        }
        if lowercased.contains("http") || lowercased.contains("web") {
            return "web"
        }
        return "tool"
    }

    private struct JSONToolOutput: Decodable {
        let output: String
        let name: String?
        let toolName: String?
        let tool: String?

        var label: String {
            toolName?.nilIfBlank ?? name?.nilIfBlank ?? tool?.nilIfBlank ?? "Tool"
        }

        enum CodingKeys: String, CodingKey {
            case output
            case name
            case toolName = "tool_name"
            case tool
        }
    }
}
