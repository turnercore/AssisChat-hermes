//
//  ChatsView.swift
//  AssisChat
//
//

import SwiftUI

struct ChatsView: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature

    var selectedChat: Chat?
    var isSettingsOpen = false
    var selectedHermesSession: HermesAPIClient.Session?
    var onSelectChat: ((Chat) -> Void)?
    var onSelectHermesSession: ((HermesAPIClient.Session) -> Void)?
    var onStartNewSession: (() -> Void)?
    var onToggleSettings: (() -> Void)?

    var body: some View {
        ChatList(
            selectedChat: selectedChat,
            selectedHermesSession: selectedHermesSession,
            onSelectChat: onSelectChat,
            onSelectHermesSession: onSelectHermesSession,
            onStartNewSession: onStartNewSession
        )
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .principal) {
                Text("DaisyChat")
                    .font(.headline)
                    .lineLimit(1)
            }
            #endif

            ToolbarItem {
                #if os(iOS)
                if let onToggleSettings {
                    Button {
                        onToggleSettings()
                    } label: {
                        Label("SETTINGS", systemImage: isSettingsOpen ? "gearshape.fill" : "gearshape")
                    }
                } else {
                    NavigationLink {
                        SettingsView()
                            .navigationTitle("DaisyChat")
                    } label: {
                        Label("SETTINGS", systemImage: "gearshape")
                    }
                }
                #else
                if #available(macOS 14, *) {
                    SettingsLink(label: {
                        Label("SETTINGS", systemImage: "gearshape")
                    })
                } else {
                    Button {
                        MacOSSettingsView.open()
                    } label: {
                        Label("SETTINGS", systemImage: "gearshape")
                    }
                }
                #endif
            }
        }
    }
}

private struct ChatList: View {
    @EnvironmentObject var settingsFeature: SettingsFeature
    @EnvironmentObject var chatFeature: ChatFeature
    @Environment(\.hermesTheme) private var theme

    var selectedChat: Chat?
    var selectedHermesSession: HermesAPIClient.Session?
    var onSelectChat: ((Chat) -> Void)?
    var onSelectHermesSession: ((HermesAPIClient.Session) -> Void)?
    var onStartNewSession: (() -> Void)?

    @State private var hermesSessions: [HermesAPIClient.Session] = []
    @State private var loadingSessions = false
    @State private var sessionError: String?
    @State private var loadedCacheKey: HermesCacheKey?
    @State private var hasMoreHermesSessions = false

    private let sessionPageSize = 40

    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\.rawPinOrder, order: .reverse),
            SortDescriptor(\.rawUpdatedAt, order: .reverse)
        ]
    ) var chats: FetchedResults<Chat>

    private var activeChats: [Chat] {
        chats.filter { !settingsFeature.isChatArchived($0) }
    }

    private var archivedChats: [Chat] {
        chats.filter { settingsFeature.isChatArchived($0) }
    }

    private var activeHermesSessions: [HermesAPIClient.Session] {
        hermesSessions.filter { !settingsFeature.isHermesSessionArchived($0) }
    }

    private var visibleActiveHermesSessions: [HermesAPIClient.Session] {
        activeHermesSessions
    }

    private var archivedHermesSessions: [HermesAPIClient.Session] {
        hermesSessions.filter { settingsFeature.isHermesSessionArchived($0) }
    }

    var body: some View {
        if settingsFeature.adapterReady || !chats.isEmpty {
            chatList
        } else {
            configIncorrect
        }
    }

    var configIncorrect: some View {
        VStack {
            VStack {
                Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                    .symbolVariant(.square)
                    .foregroundColor(theme.secondaryForeground)

                Text("Connect to your Hermes server to continue.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding()

                #if os(iOS)
                NavigationLink {
                    ChatSourceConfigView(successAlert: false, backWhenConfigured: true) { _ in
                    }
                } label: {
                    Text("Connect to Hermes")
                }
                #else
                if #available(macOS 14, *) {
                    SettingsLink(label: {
                        Text("Connect to Hermes")
                    })
                } else {
                    Button {
                        MacOSSettingsView.open()
                    } label: {
                        Text("Connect to Hermes")
                    }
                }
                #endif
            }
            .padding(10)
            .padding(.vertical)
            .background(theme.card.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.border.opacity(0.75), lineWidth: 1)
            )
            .cornerRadius(8)
            .padding(15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var chatList: some View {
        List {
            if let onStartNewSession {
                Button {
                    onStartNewSession()
                } label: {
                    Label("New Session", systemImage: "square.and.pencil")
                }
                #if os(iOS)
                .listRowBackground(selectedChat == nil && selectedHermesSession == nil ? Color.secondaryBackground : Color.clear)
                #endif
            }

            if !settingsFeature.adapterReady {
                NavigationLink {
                    ChatSourceConfigView(successAlert: false, backWhenConfigured: true) { _ in
                    }
                } label: {
                    Label("Connect to Hermes", systemImage: "exclamationmark.triangle")
                }
                .listRowBackground(Color.secondaryBackground)
            }

            if settingsFeature.adapterReady {
                Section("HERMES SESSIONS") {
                    if let updatedAt = settingsFeature.cachedHermesSessionsLastUpdated(), !hermesSessions.isEmpty {
                        Label("Last updated \(updatedAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if loadingSessions && hermesSessions.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Loading sessions")
                                .foregroundColor(.secondary)
                        }
                    } else if let sessionError, hermesSessions.isEmpty {
                        Text(sessionError)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else if activeHermesSessions.isEmpty {
                        Text("No active Hermes sessions.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(visibleActiveHermesSessions) { session in
                            hermesSessionRow(session)
                        }

                        if hasMoreHermesSessions {
                            Button {
                                Task { await loadMoreHermesSessions() }
                            } label: {
                                Label(loadingSessions ? "Loading more" : "Load more sessions", systemImage: "ellipsis.circle")
                            }
                            .font(.footnote.weight(.semibold))
                            .disabled(loadingSessions)
                        }

                        if loadingSessions {
                            Label("Updating sessions", systemImage: "arrow.triangle.2.circlepath")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else if let sessionError {
                            Label("Could not refresh: \(sessionError)", systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if !activeChats.isEmpty {
                Section("LOCAL CHATS") {
                    ForEach(activeChats) { chat in
                        localChatRow(chat)
                    }
                    .onDelete(perform: archiveLocalChats)
                }
            }

            if !archivedHermesSessions.isEmpty || !archivedChats.isEmpty {
                Section("ARCHIVED") {
                    ForEach(archivedHermesSessions) { session in
                        Button {
                            settingsFeature.unarchiveHermesSession(session)
                        } label: {
                            HermesSessionItem(session: session, archived: true)
                        }
                    }

                    ForEach(archivedChats) { chat in
                        Button {
                            settingsFeature.unarchiveChat(chat)
                        } label: {
                            ChatItem(chat: chat, archived: true)
                        }
                    }
                }
            }

            CopyrightView()
                .padding(.vertical, 30)
                .listRowSeparator(.hidden)
        }
        #if os(iOS)
        .listStyle(.plain)
        #endif
        .background(theme.background)
        .scrollContentBackgroundIfAvailable(.hidden)
        .environment(\.defaultMinListRowHeight, 54)
        .animation(.easeOut, value: chats.count)
        .task(id: settingsFeature.hermesCacheKey) {
            await loadHermesSessions()
        }
        .refreshable {
            await loadHermesSessions(force: true)
        }
    }

    private func hermesSessionRow(_ session: HermesAPIClient.Session) -> some View {
        Button {
            onSelectHermesSession?(session)
        } label: {
            HermesSessionItem(session: session)
        }
        .buttonStyle(.plain)
        #if os(iOS)
        .listRowBackground(session.id == selectedHermesSession?.id ? theme.accent.opacity(0.82) : theme.sidebarBackground.opacity(0.92))
        #endif
        .swipeActions(edge: .trailing) {
            Button {
                settingsFeature.archiveHermesSession(session)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.appOrange)
        }
        .contextMenu {
            Button {
                settingsFeature.archiveHermesSession(session)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }

    private func localChatRow(_ chat: Chat) -> some View {
        Group {
            if let onSelectChat {
                Button {
                    onSelectChat(chat)
                } label: {
                    ChatItem(chat: chat)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    ChattingView(chat: chat)
                } label: {
                    ChatItem(chat: chat)
                }
            }
        }
        #if os(iOS)
        .listRowBackground(chat.id == selectedChat?.id || chat.pinned ? theme.accent.opacity(0.82) : theme.sidebarBackground.opacity(0.92))
        #endif
        .swipeActions(edge: .trailing) {
            Button {
                settingsFeature.archiveChat(chat)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(.appOrange)
        }
        .swipeActions(edge: .leading) {
            Button {
                chatFeature.clearMessages(for: chat)
            } label: {
                Label("CHAT_CLEAR_MESSAGE", systemImage: "eraser.line.dashed")
            }
            .tint(.appOrange)

            if chat.pinned {
                Button {
                    chatFeature.unpinChat(chat: chat)
                } label: {
                    Label("Unpin Chat", systemImage: "pin.slash")
                }
            } else {
                Button {
                    chatFeature.pinChat(chat: chat)
                } label: {
                    Label("Pin Chat", systemImage: "pin")
                }
            }
        }
        .contextMenu {
            if chat.pinned {
                Button {
                    chatFeature.unpinChat(chat: chat)
                } label: {
                    Label("Unpin Chat", systemImage: "pin.slash")
                }
            } else {
                Button {
                    chatFeature.pinChat(chat: chat)
                } label: {
                    Label("Pin Chat", systemImage: "pin")
                }
            }

            Button {
                settingsFeature.archiveChat(chat)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }

            Button {
                chatFeature.clearMessages(for: chat)
            } label: {
                Label("CHAT_CLEAR_MESSAGE", systemImage: "eraser.line.dashed")
            }

            Divider()

            Button(role: .destructive) {
                chatFeature.deleteChats([chat])
            } label: {
                Label("CHAT_DELETE", systemImage: "trash")
            }
        }
    }

    @MainActor
    private func loadHermesSessions(force: Bool = false) async {
        guard settingsFeature.adapterReady else {
            hermesSessions = []
            sessionError = "Configure DaisyChat first."
            loadedCacheKey = settingsFeature.hermesCacheKey
            return
        }
        guard let client else {
            hermesSessions = []
            sessionError = "DaisyChat is missing a local API key or server URL."
            loadedCacheKey = settingsFeature.hermesCacheKey
            return
        }

        let cacheKey = settingsFeature.hermesCacheKey
        if let cached = settingsFeature.cachedHermesSessionsIfUsable(), !force {
            hermesSessions = cached
            hasMoreHermesSessions = cached.count >= sessionPageSize
            sessionError = nil
            loadedCacheKey = cacheKey
            return
        }

        if !force, loadedCacheKey == cacheKey, !hermesSessions.isEmpty {
            return
        }

        if hermesSessions.isEmpty,
           let cached = settingsFeature.cachedHermesSessionsIfUsable(maxAge: 1_800) {
            hermesSessions = cached
            hasMoreHermesSessions = cached.count >= sessionPageSize
        }

        guard !loadingSessions else { return }

        loadingSessions = true
        defer { loadingSessions = false }

        do {
            let sessions = try await client.sessions(limit: sessionPageSize, offset: 0).items
            hermesSessions = sessions
            hasMoreHermesSessions = sessions.count == sessionPageSize
            reconcileSelectedSession(with: sessions)
            settingsFeature.storeHermesSessions(sessions)
            sessionError = nil
            loadedCacheKey = cacheKey
        } catch is CancellationError {
            return
        } catch {
            sessionError = error.localizedDescription
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

    private func archiveLocalChats(_ indices: IndexSet) {
        indices.map { activeChats[$0] }.forEach(settingsFeature.archiveChat)
    }

    @MainActor
    private func loadMoreHermesSessions() async {
        guard !loadingSessions, let client, hasMoreHermesSessions else { return }

        loadingSessions = true
        defer { loadingSessions = false }

        do {
            let nextSessions = try await client.sessions(limit: sessionPageSize, offset: hermesSessions.count).items
            hermesSessions = mergeSessions(hermesSessions + nextSessions)
            hasMoreHermesSessions = nextSessions.count == sessionPageSize
            settingsFeature.storeHermesSessions(hermesSessions)
            sessionError = nil
        } catch {
            sessionError = error.localizedDescription
        }
    }

    private func reconcileSelectedSession(with sessions: [HermesAPIClient.Session]) {
        guard
            let selectedHermesSession,
            sessions.contains(where: { $0.id == selectedHermesSession.id }) == false
        else {
            return
        }

        onStartNewSession?()
    }

    private func mergeSessions(_ sessions: [HermesAPIClient.Session]) -> [HermesAPIClient.Session] {
        var seen = Set<String>()
        return sessions.filter { session in
            guard !seen.contains(session.id) else { return false }
            seen.insert(session.id)
            return true
        }
    }
}

private struct HermesSessionItem: View {
    @Environment(\.hermesTheme) private var theme

    let session: HermesAPIClient.Session
    var archived = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sourceKind.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 42, height: 42)
                .background(sourceKind.badgeBackground(theme: theme))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(sourceKind.badgeForeground(theme: theme).opacity(0.32), lineWidth: 1)
                )
                .cornerRadius(8)
                .foregroundColor(sourceKind.badgeForeground(theme: theme))

            VStack(alignment: .leading, spacing: 5) {
                Text(session.displayTitle)
                    .foregroundColor(theme.foreground)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let source = session.source?.nilIfBlank {
                        Text(source)
                    }
                    if let updatedAt = session.updatedAt?.nilIfBlank {
                        Text(updatedAt)
                    }
                }
                .font(.footnote)
                .foregroundColor(theme.mutedForeground)
                .lineLimit(1)
            }
        }
        #if os(macOS)
        .padding(.vertical, 2)
        #endif
    }

    private var sourceKind: HermesSessionSourceKind {
        archived ? .archived : session.sourceKind
    }
}

private extension HermesSessionSourceKind {
    func badgeForeground(theme: HermesTheme) -> Color {
        switch self {
        case .api:
            return theme.primary
        case .cli:
            return theme.secondaryForeground
        case .cron:
            return theme.composerRing
        case .discord:
            return theme.midground
        case .tui:
            return theme.accentForeground
        case .web:
            return theme.ring
        case .archived:
            return theme.mutedForeground
        case .unknown:
            return theme.foreground
        }
    }

    func badgeBackground(theme: HermesTheme) -> Color {
        switch self {
        case .api:
            return theme.primary.opacity(0.16)
        case .cli:
            return theme.secondary.opacity(0.72)
        case .cron:
            return theme.composerRing.opacity(0.16)
        case .discord:
            return theme.midground.opacity(0.18)
        case .tui:
            return theme.accent.opacity(0.74)
        case .web:
            return theme.ring.opacity(0.16)
        case .archived:
            return theme.card.opacity(0.58)
        case .unknown:
            return theme.card.opacity(0.72)
        }
    }
}

private struct ChatItem: View {
    @Environment(\.hermesTheme) private var theme

    @ObservedObject var chat: Chat
    var archived = false

    var body: some View {
        HStack {
            chat.icon.image
                .font(.title2)
                .frame(width: 24, height: 24)
                #if os(iOS)
                .padding(13)
                #else
                .padding(8)
                #endif
                .background(archived ? theme.card.opacity(0.58) : chat.uiColor)
                .cornerRadius(8)
                .colorScheme(.dark)

            VStack(alignment: .leading, spacing: 5) {
                Text(chat.name)
                    .foregroundColor(theme.foreground)
                Text(archived ? "Archived" : (chat.systemMessage ?? String(localized: "CHAT_ROLE_PROMPT_BLANK_HINT")))
                    .font(.footnote)
                    .foregroundColor(theme.mutedForeground)
                    .lineLimit(1)
            }

            #if os(macOS)
            if chat.pinned {
                Spacer()
                Image(systemName: "pin")
                    .foregroundColor(.secondary)
            }
            #endif
        }
        #if os(macOS)
        .padding(.vertical, 2)
        #endif
    }
}

struct ChatsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatsView()
    }
}
