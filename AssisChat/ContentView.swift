//
//  ContentView.swift
//  AssisChat
//
//

import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
#if os(iOS)
        if #available(iOS 16, *) {
            if horizontalSizeClass == .compact {
                ContentCompactView()
            } else {
                ContentSplitView()
            }
        } else {
            NavigationView {
                ChatsView()
                    .navigationTitle("DaisyChat")
                    .inlineNavigationBar()
                NewHermesChatView { _ in }
                    .navigationBarHidden(true)
            }
        }
#else
        NavigationSplitView {
            ChatsView()
                .frame(width: 280)
                .navigationTitle("DaisyChat")
                .navigationSplitViewColumnWidth(280)
        } detail: {
            NewHermesChatView { _ in }
                .frame(minWidth: 600, minHeight: 500)
        }
#endif
    }
}

#if os(iOS)
@available(iOS 16.0, *)
private struct ContentCompactView: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature

    @State private var selectedChat: Chat?
    @State private var selectedHermesSession: HermesAPIClient.Session?
    @State private var showingSettings = false
    @State private var showingNewSession = false

    private var showingDetail: Bool {
        selectedChat != nil || selectedHermesSession != nil || showingSettings || showingNewSession
    }

    var body: some View {
        NavigationStack {
            Group {
                if showingSettings {
                    SettingsView()
                        .navigationTitle("DaisyChat")
                } else if let selectedChat {
                    ChattingView(chat: selectedChat)
                } else if let selectedHermesSession {
                    HermesSessionDetailView(session: selectedHermesSession)
                        .id(selectedHermesSession.id)
                        .navigationTitle(selectedHermesSession.displayTitle)
                } else if showingNewSession {
                    NewHermesChatView { chat in
                        selectedChat = chat
                        selectedHermesSession = nil
                        showingSettings = false
                        showingNewSession = false
                    }
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    ChatsView(
                        selectedChat: selectedChat,
                        isSettingsOpen: showingSettings,
                        selectedHermesSession: selectedHermesSession,
                        onSelectChat: { chat in
                            selectedChat = chat
                            selectedHermesSession = nil
                            showingSettings = false
                            showingNewSession = false
                        },
                        onSelectHermesSession: { session in
                            selectedHermesSession = session
                            selectedChat = nil
                            showingSettings = false
                            showingNewSession = false
                        },
                        onStartNewSession: {
                            selectedChat = nil
                            selectedHermesSession = nil
                            showingSettings = false
                            showingNewSession = true
                        },
                        onToggleSettings: {
                            selectedChat = nil
                            selectedHermesSession = nil
                            showingNewSession = false
                            showingSettings = true
                        }
                    )
                    .navigationTitle("DaisyChat")
                }
            }
            .toolbar {
                if showingDetail {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            selectedChat = nil
                            selectedHermesSession = nil
                            showingSettings = false
                            showingNewSession = false
                        } label: {
                            Label("Sessions", systemImage: "sidebar.leading")
                        }
                    }
                }
            }
        }
    }
}

@available(iOS 16.0, *)
private struct ContentSplitView: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature

    @State private var selectedChat: Chat?
    @State private var selectedHermesSession: HermesAPIClient.Session?
    @State private var showingSettings = false
    @State private var settingsViewID = UUID()
    @State private var detailViewID = UUID()
    @State private var splitVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $splitVisibility) {
            ChatsView(
                selectedChat: selectedChat,
                isSettingsOpen: showingSettings,
                selectedHermesSession: selectedHermesSession,
                onSelectChat: { chat in
                    selectedChat = chat
                    selectedHermesSession = nil
                    showingSettings = false
                    hideSidebarAndResetDetail()
                },
                onSelectHermesSession: { session in
                    selectedHermesSession = session
                    selectedChat = nil
                    showingSettings = false
                    hideSidebarAndResetDetail()
                },
                onStartNewSession: {
                    selectedChat = nil
                    selectedHermesSession = nil
                    showingSettings = false
                    hideSidebarAndResetDetail()
                },
                onToggleSettings: {
                    showingSettings.toggle()
                    hideSidebarAndResetDetail()
                }
            )
            .navigationTitle("DaisyChat")
            .navigationSplitViewColumnWidth(320)
        } detail: {
            NavigationStack {
                if showingSettings {
                    SettingsView()
                        .id(settingsViewID)
                        .navigationTitle("DaisyChat")
                } else if let selectedChat {
                    ChattingView(chat: selectedChat)
                } else if let selectedHermesSession {
                    HermesSessionDetailView(session: selectedHermesSession)
                        .id(selectedHermesSession.id)
                        .navigationTitle(selectedHermesSession.displayTitle)
                } else {
                    NewHermesChatView { chat in
                        selectedChat = chat
                        selectedHermesSession = nil
                        hideSidebarAndResetDetail()
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
            .id(detailViewID)
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    splitVisibility = .detailOnly
                }
            )
        }
    }

    private func hideSidebarAndResetDetail() {
        splitVisibility = .detailOnly
        settingsViewID = UUID()
        detailViewID = UUID()
    }
}
#endif

struct HermesWorkspaceBackground: View {
    let theme: HermesTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.sidebarBackground,
                    theme.background,
                    theme.input.opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    theme.primary.opacity(0.20),
                    .clear,
                    theme.accent.opacity(0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)

            HermesGridTexture(theme: theme, opacity: 0.16)
        }
    }
}

private struct HermesHomeCanvas: View {
    @Environment(\.hermesTheme) private var theme

    let profile: String
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 18 : 24) {
            Spacer(minLength: compact ? 24 : 60)

            VStack(spacing: 10) {
                Text("HERMES AGENT")
                    .font(.system(size: compact ? 34 : 56, weight: .black, design: .serif))
                    .foregroundColor(theme.foreground)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text("Send a task, attach context, or open a session.")
                    .font(.system(size: compact ? 15 : 18, weight: .medium))
                    .foregroundColor(theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 10) {
                StatusPill(title: "PROFILE", value: profile, systemImage: "person.crop.circle.badge.checkmark")
                StatusPill(title: "MODE", value: "API SERVER", systemImage: "bolt.horizontal")
            }
            .padding(.horizontal, 20)

            Spacer(minLength: compact ? 16 : 42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .center) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: compact ? 140 : 220, weight: .thin))
                .foregroundColor(theme.primary.opacity(0.055))
                .offset(y: compact ? -14 : -24)
                .allowsHitTesting(false)
        }
    }
}

private struct StatusPill: View {
    @Environment(\.hermesTheme) private var theme

    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(theme.mutedForeground)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.foreground)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(theme.card.opacity(0.54))
        .overlay(
            Capsule()
                .stroke(theme.border.opacity(0.7), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

struct NewHermesChatView: View {
    @EnvironmentObject private var essentialFeature: EssentialFeature
    @EnvironmentObject private var settingsFeature: SettingsFeature
    @EnvironmentObject private var chatFeature: ChatFeature
    @EnvironmentObject private var chattingFeature: ChattingFeature
    @Environment(\.hermesTheme) private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let onChatCreated: (Chat) -> Void

    @State private var prompt = ""
    @State private var handling = false
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var connecting = false
    @State private var profileError: String?
    @State private var showingURLPrompt = false
    @State private var urlAttachment = ""
    #if os(iOS)
    @State private var imageAttachmentSource: ImageAttachmentSource?
    #endif

    private var profiles: [String] {
        let configured = settingsFeature.configuredHermesModel.nilIfBlank
        let values = settingsFeature.discoveredHermesModels + settingsFeature.activeModels + [configured].compactMap { $0 }
        let unique = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, value in
                if !result.contains(value) {
                    result.append(value)
                }
            }
        return unique.isEmpty ? [Chat.HermesModel.default.rawValue] : unique
    }

    private var selectedProfile: String {
        settingsFeature.configuredHermesModel.nilIfBlank ?? Chat.HermesModel.default.rawValue
    }

    private var selectedProfileDisplayName: String {
        settingsFeature.displayName(forHermesModel: selectedProfile)
    }

    private var canSend: Bool {
        prompt.nilIfBlank != nil && settingsFeature.adapterReady && !handling
    }

    var body: some View {
        VStack(spacing: 0) {
            profilePicker

            if settingsFeature.adapterReady {
                HermesHomeCanvas(profile: selectedProfileDisplayName, compact: horizontalSizeClass == .compact)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                connectForm
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            composer
        }
        .background(HermesWorkspaceBackground(theme: theme).ignoresSafeArea())
        .onAppear {
            baseURL = settingsFeature.configuredHermesBaseURL ?? ""
            apiKey = settingsFeature.configuredHermesAPIKey ?? ""
        }
        .task {
            await refreshProfiles()
        }
        .alert("Attach URL", isPresented: $showingURLPrompt) {
            TextField("https://example.com", text: $urlAttachment)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            Button("Add") {
                appendURLAttachment()
            }
            Button("Cancel", role: .cancel) {
                urlAttachment = ""
            }
        }
        #if os(iOS)
        .sheet(item: $imageAttachmentSource) { source in
            ImageAttachmentPicker(source: source) { result in
                appendImageAttachment(result)
            }
        }
        #endif
    }

    private var profilePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(profiles, id: \.self) { profile in
                    Button {
                        settingsFeature.configuredHermesModel = profile
                        settingsFeature.initiateHermesAdapter()
                    } label: {
                        Text(settingsFeature.displayName(forHermesModel: profile))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundColor(profile == selectedProfile ? theme.primaryForeground : theme.secondaryForeground)
                            .background(profile == selectedProfile ? theme.primary : theme.card.opacity(0.58))
                            .overlay(
                                Capsule()
                                    .stroke(profile == selectedProfile ? theme.ring.opacity(0.55) : theme.border.opacity(0.45), lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.clear)
    }

    private var composer: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                Menu {
                    #if os(iOS)
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            imageAttachmentSource = .camera
                        } label: {
                            Label("Camera", systemImage: "camera")
                        }
                    }

                    Button {
                        imageAttachmentSource = .photoLibrary
                    } label: {
                        Label("Photos", systemImage: "photo.on.rectangle")
                    }

                    Divider()
                    #endif

                    Button {
                        showingURLPrompt = true
                    } label: {
                        Label("URL...", systemImage: "link")
                    }

                    Button {
                        appendToolInstruction("Use the appropriate Hermes tools for this request. Show concise progress and summarize only the useful result.")
                    } label: {
                        Label("Use tools", systemImage: "hammer")
                    }

                    Button {
                        appendToolInstruction("Inspect the relevant files or project context before answering. Keep the final response focused.")
                    } label: {
                        Label("Inspect context", systemImage: "folder.badge.gearshape")
                    }

                    Button {
                        appendToolInstruction("Run the necessary checks or commands, then report the outcome and any failures.")
                    } label: {
                        Label("Run checks", systemImage: "checkmark.seal")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.medium))
                        .frame(width: 42, height: 42)
                        .foregroundColor(theme.primary)
                        .background(theme.card.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.border.opacity(0.7), lineWidth: 1)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                if #available(iOS 16.0, macOS 13.0, *) {
                    TextField("What's on your mind?", text: $prompt, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 9)
                        .foregroundColor(theme.foreground)
                } else {
                    TextField("What's on your mind?", text: $prompt)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 9)
                        .foregroundColor(theme.foreground)
                }

                Button {
                    submit()
                } label: {
                    if handling {
                        UniformProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "waveform.path")
                            .font(.title3.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(canSend ? theme.primaryForeground : theme.mutedForeground)
                .frame(width: 42, height: 42)
                .background(canSend ? theme.primary : theme.card.opacity(0.72))
                .overlay(
                    Circle()
                        .stroke(canSend ? theme.ring.opacity(0.7) : theme.border.opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(.infinity)
                .disabled(!canSend)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(theme.input.opacity(0.86))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(theme.composerRing.opacity(0.55), lineWidth: 1)
            )
            .cornerRadius(18)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [theme.background.opacity(0.0), theme.background.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var connectForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect to Hermes")
                .font(.title2.weight(.semibold))
                .foregroundColor(theme.foreground)

            TextField("http://host:8642", text: $baseURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)

            SecureField("API_SERVER_KEY", text: $apiKey)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)

            Button {
                connect()
            } label: {
                HStack {
                    if connecting {
                        UniformProgressView()
                    }
                    Text("Connect")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(connecting || apiKey.nilIfBlank == nil)

            if let profileError {
                Text(profileError)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(theme.card.opacity(0.88))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.border.opacity(0.8), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private func submit() {
        guard canSend, let input = prompt.nilIfBlank else { return }

        let title = String(input.prefix(54))
        let chat = chatFeature.createChat(
            PlainChat(
                name: title,
                temperature: .balanced,
                systemMessage: "You are DaisyChat, a Hermes Agent mobile client.",
                historyLengthToSend: .defaultHistoryLengthToSend,
                messagePrefix: nil,
                autoCopy: false,
                icon: .default,
                color: .default,
                model: selectedProfile
            ),
            forModel: selectedProfile
        )

        guard let chat else { return }
        onChatCreated(chat)

        Task {
            handling = true
            _ = await chattingFeature.sendWithStream(content: input, to: chat)
            prompt = ""
            handling = false
        }
    }

    private func appendURLAttachment() {
        defer { urlAttachment = "" }

        guard
            let url = URL(string: urlAttachment.trimmingCharacters(in: .whitespacesAndNewlines)),
            ["http", "https"].contains(url.scheme?.lowercased()),
            url.host != nil
        else {
            essentialFeature.appendAlert(alert: ErrorAlert(message: "Invalid URL"))
            return
        }

        if ImagePromptAttachment.isSupportedRemoteImageURL(url) {
            appendToPrompt("\n\nImage URL:\n\(url.absoluteString)")
        } else {
            appendToPrompt("\n\nURL:\n\(url.absoluteString)")
        }
    }

    private func appendToolInstruction(_ instruction: String) {
        appendToPrompt(prompt.nilIfBlank == nil ? instruction : "\n\n\(instruction)")
    }

    #if os(iOS)
    private func appendImageAttachment(_ result: Result<UIImage, Error>) {
        do {
            let image = try result.get()
            appendToPrompt(try ImagePromptAttachment.block(from: image))
        } catch {
            essentialFeature.appendAlert(alert: ErrorAlert(message: LocalizedStringKey(error.localizedDescription)))
        }
    }
    #endif

    private func appendToPrompt(_ text: String) {
        if prompt.nilIfBlank == nil {
            prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            prompt += text
        }
    }

    private func connect() {
        guard let token = apiKey.nilIfBlank else { return }

        Task {
            connecting = true
            defer { connecting = false }

            do {
                _ = try await settingsFeature.validateAndConfigHermes(
                    apiKey: token,
                    baseURL: baseURL.nilIfBlank,
                    sessionId: nil,
                    sessionKey: nil
                )
                await refreshProfiles()
            } catch ChattingError.validating(let message) {
                essentialFeature.appendAlert(alert: ErrorAlert(message: message))
            } catch {
                essentialFeature.appendAlert(alert: ErrorAlert(message: LocalizedStringKey(error.localizedDescription)))
            }
        }
    }

    @MainActor
    private func refreshProfiles() async {
        guard
            let token = settingsFeature.configuredHermesAPIKey?.nilIfBlank,
            let url = ProviderEndpoint.normalizedBaseURL(settingsFeature.configuredHermesBaseURL, defaultValue: "http://127.0.0.1:8642")
        else {
            return
        }

        let client = HermesAPIClient(baseURL: url, apiKey: token)
        let ids = await client.profileCandidates()
        settingsFeature.updateHermesModels(ids)
        profileError = ids.isEmpty ? "Connected, but profiles could not be refreshed." : nil
    }
}

struct HermesSessionDetailView: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature
    @Environment(\.hermesTheme) private var theme

    let session: HermesAPIClient.Session

    @State private var messages: [HermesAPIClient.SessionMessage] = []
    @State private var loading = false
    @State private var errorText: String?

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
                        ForEach(messages) { message in
                            HermesSessionMessageRow(message: message)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: 860)
                    .frame(maxWidth: .infinity)
                }
                .refreshable {
                    await loadMessages()
                }
            }
        }
        .background(HermesWorkspaceBackground(theme: theme).ignoresSafeArea())
        .task {
            await loadMessages()
        }
        .toolbar {
            Button {
                Task { await loadMessages() }
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
    private func loadMessages() async {
        guard let client else {
            errorText = "Configure Hermes first."
            return
        }

        loading = true
        defer { loading = false }

        do {
            messages = try await client.sessionMessages(sessionId: session.id).items
            errorText = nil
        } catch {
            errorText = error.localizedDescription
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
}

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
            Text(message.content ?? "")
                .font(.body)
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
                .foregroundColor(theme.cardForeground)
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
                Text(content.output)
                    .font(theme.monoFont(size: 12, relativeTo: .caption))
                    .foregroundColor(theme.cardForeground)
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
        return normalized.count > 700 ? String(normalized.prefix(700)) + "..." : normalized
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

#if os(iOS)
enum ImageAttachmentSource: String, Identifiable {
    case camera
    case photoLibrary

    var id: String { rawValue }

    var pickerSourceType: UIImagePickerController.SourceType {
        switch self {
        case .camera:
            return .camera
        case .photoLibrary:
            return .photoLibrary
        }
    }
}

struct ImageAttachmentPicker: UIViewControllerRepresentable {
    let source: ImageAttachmentSource
    let onComplete: (Result<UIImage, Error>) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source.pickerSourceType
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onComplete: (Result<UIImage, Error>) -> Void

        init(onComplete: @escaping (Result<UIImage, Error>) -> Void) {
            self.onComplete = onComplete
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)

            guard let image = info[.originalImage] as? UIImage else {
                onComplete(.failure(ImagePromptAttachment.Error.noImage))
                return
            }

            onComplete(.success(image))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

enum ImagePromptAttachment {
    enum Error: LocalizedError {
        case noImage
        case couldNotEncode
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .noImage:
                return "No image was selected."
            case .couldNotEncode:
                return "The selected image could not be encoded."
            case .tooLarge:
                return "The selected image is too large to attach inline."
            }
        }
    }

    static func block(from image: UIImage) throws -> String {
        let resized = image.resizedForPromptAttachment(maxDimension: 768)
        let qualities: [CGFloat] = [0.62, 0.48, 0.36]

        for quality in qualities {
            guard let data = resized.jpegData(compressionQuality: quality) else {
                throw Error.couldNotEncode
            }

            guard data.count <= 650_000 else { continue }

            let base64 = data.base64EncodedString()
            return """

            Image attachment:
            ```data:image/jpeg;base64
            \(base64)
            ```
            """
        }

        throw Error.tooLarge
    }

    static func isSupportedRemoteImageURL(_ url: URL) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased()) else { return false }
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}

private extension UIImage {
    func resizedForPromptAttachment(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
#endif

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
