//
//  SettingsView.swift
//  AssisChat
//
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature

    @Environment(\.openURL) private var openURL
    @Environment(\.hermesTheme) private var theme

    var body: some View {
        List {
            Section("SETTINGS_CHAT") {
                NavigationLink {
                    HermesSettingsView()
                        .navigationTitle("DaisyChat")
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("DaisyChat")

                            Text("Configure Hermes, check health, view sessions, and run controls.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                        }
                    } icon: {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .listRowBackground(theme.card.opacity(0.86))

            Section("SETTINGS_THEME") {
                SettingsThemeContent()
            }
            .listRowBackground(theme.card.opacity(0.86))

            Section("SETTINGS_ABOUT") {
                SettingsAboutContent()
            }
            .listRowBackground(theme.card.opacity(0.86))

            CopyrightView(detailed: true)
                .listRowBackground(Color.clear)
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackgroundIfAvailable(.hidden)
        .background(HermesWorkspaceBackground(theme: theme).ignoresSafeArea())
        .inlineNavigationBar()
    }
}

struct HermesSettingsView: View {
    @Environment(\.hermesTheme) private var theme

    var body: some View {
        List {
            Section("Connection") {
                NavigationLink {
                    ChatSourceConfigView(successAlert: true, backWhenConfigured: false) { _ in }
                        .navigationTitle("DaisyChat Connection")
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Server & API Key")
                            Text("Configure your Hermes API server. Secrets are stored in Keychain.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "globe.asia.australia")
                    }
                }
            }
            .listRowBackground(theme.card.opacity(0.86))

            HermesDashboardContent()
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackgroundIfAvailable(.hidden)
        .background(HermesWorkspaceBackground(theme: theme).ignoresSafeArea())
    }
}

struct SettingsThemeContent: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature
    @Environment(\.hermesTheme) private var theme

    var body: some View {
        Picker(selection: $settingsFeature.selectedAppTheme) {
            ForEach(SettingsFeature.appThemes, id: \.self) { theme in
                Text(theme.localizedKey)
                    .tag(theme)
            }
        } label: {
            Label {
                Text("App Theme")
                    .foregroundColor(.primary)
            } icon: {
                Image(systemName: "circle.hexagongrid")
                    .foregroundColor(theme.primary)
            }
        }

        Picker(selection: $settingsFeature.selectedFontSize) {
            ForEach(SettingsFeature.fontSizes, id: \.self) { fontSize in
                Text(verbatim: fontSize.localizedLabel)
                    .tag(fontSize)
            }
        } label: {
            Label {
                Text("Message Font Size", comment: "The label of the setting of message font size")
                    .foregroundColor(.primary)
            } icon: {
                Image(systemName: "textformat.size")
                    .foregroundColor(theme.primary)
            }
        }
    }
}

struct HermesDashboardView: View {
    @Environment(\.hermesTheme) private var theme

    var body: some View {
        List {
            HermesDashboardContent()
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackgroundIfAvailable(.hidden)
        .background(HermesWorkspaceBackground(theme: theme).ignoresSafeArea())
    }
}

private struct HermesDashboardContent: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature
    @EnvironmentObject private var essentialFeature: EssentialFeature
    @Environment(\.hermesTheme) private var theme

    @State private var health: String = "Not checked"
    @State private var model: String = "hermes-agent"
    @State private var discoveredModels: [String] = []
    @State private var capabilities: [String: Bool] = [:]
    @State private var sessions: [HermesAPIClient.Session] = []
    @State private var selectedSession: HermesAPIClient.Session?
    @State private var messages: [HermesAPIClient.SessionMessage] = []
    @State private var runInput = ""
    @State private var activeRun: HermesAPIClient.RunStatus?
    @State private var connectionError: String?
    @State private var capabilitiesError: String?
    @State private var sessionsError: String?
    @State private var messagesError: String?
    @State private var runError: String?
    @State private var loading = false

    var body: some View {
        Group {
            Section("Status") {
                HStack {
                    Label(health, systemImage: health == "ok" ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundColor(health == "ok" ? .appGreen : .secondary)
                    Spacer()
                    Button("Refresh") {
                        Task { await refresh() }
                    }
                    .disabled(loading)
                }

                if !discoveredModels.isEmpty {
                    Picker("Profile / Model", selection: $settingsFeature.configuredHermesModel) {
                        ForEach(discoveredModels, id: \.self) { model in
                            Text(settingsFeature.displayName(forHermesModel: model)).tag(model)
                        }
                    }
                    .onChange(of: settingsFeature.configuredHermesModel) { _ in
                        settingsFeature.initiateHermesAdapter()
                    }
                } else {
                    HStack {
                        Text("Profile / Model")
                        Spacer()
                        Text(settingsFeature.displayName(forHermesModel: model))
                            .foregroundColor(.secondary)
                    }
                }

                if let connectionError {
                    Text(connectionError)
                        .font(.footnote)
                        .foregroundColor(.appRed)
                }

                if let capabilitiesError {
                    Text("Capabilities: \(capabilitiesError)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                if !capabilities.isEmpty {
                    FlowTags(values: capabilities.filter { $0.value }.map { $0.key }.sorted())
                }
            }
            .listRowBackground(theme.card.opacity(0.86))

            Section("Sessions") {
                if sessions.isEmpty {
                    Text(sessionsError ?? "No sessions returned by Hermes.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sessions) { session in
                        Button {
                            selectedSession = session
                            Task { await loadMessages(for: session) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(session.title?.nilIfBlank ?? session.id)
                                    if let source = session.source {
                                        Text(source)
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedSession?.id == session.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .listRowBackground(theme.card.opacity(0.86))

            if selectedSession != nil {
                Section("Messages") {
                    if messages.isEmpty {
                        Text(messagesError ?? "No messages returned for this session.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(messages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.role ?? "message")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(message.content ?? "")
                            }
                        }
                    }
                }
                .listRowBackground(theme.card.opacity(0.86))
            }

            Section("Run") {
                TextEditor(text: $runInput)
                    .frame(minHeight: 80)
                    .overlay(alignment: .topLeading) {
                        if runInput.isEmpty {
                            Text("Ask Hermes to do something")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }

                HStack {
                    Button("Start Run") {
                        Task { await startRun() }
                    }
                    .disabled(runInput.nilIfBlank == nil || loading)

                    Spacer()

                    if let run = activeRun, let runId = run.runId {
                        Button("Stop") {
                            Task { await stopRun(runId: runId) }
                        }
                        .disabled(!capabilities["run_stop", default: false])
                    }
                }

                if let run = activeRun {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(run.status)
                            .font(.headline)
                        if let output = run.output, !output.isEmpty {
                            Text(output)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let runError {
                    Text(runError)
                        .font(.footnote)
                        .foregroundColor(.appRed)
                }
            }
            .listRowBackground(theme.card.opacity(0.86))
        }
        .task {
            await refresh()
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
    private func refresh() async {
        guard let client else {
            health = "Configure Hermes first"
            connectionError = nil
            return
        }

        loading = true
        defer { loading = false }

        connectionError = nil
        capabilitiesError = nil
        sessionsError = nil

        do {
            health = try await client.health().status
        } catch {
            health = "Error"
            connectionError = error.localizedDescription
            return
        }

        do {
            let caps = try await client.capabilities()
            model = caps.model ?? model
            capabilities = caps.features ?? [:]
        } catch {
            capabilities = [:]
            capabilitiesError = error.localizedDescription
        }

        let profileCandidates = await client.profileCandidates()
        if !profileCandidates.isEmpty {
            discoveredModels = profileCandidates
            settingsFeature.updateHermesModels(profileCandidates)
            model = settingsFeature.configuredHermesModel
        } else if discoveredModels.isEmpty {
            discoveredModels = settingsFeature.discoveredHermesModels
        }

        do {
            sessions = try await client.sessions().items
        } catch {
            sessions = []
            sessionsError = error.localizedDescription
        }
    }

    @MainActor
    private func loadMessages(for session: HermesAPIClient.Session) async {
        guard let client else { return }

        messagesError = nil
        do {
            messages = try await client.sessionMessages(sessionId: session.id).items
        } catch {
            messages = []
            messagesError = error.localizedDescription
        }
    }

    @MainActor
    private func startRun() async {
        guard let client, let input = runInput.nilIfBlank else { return }

        loading = true
        defer { loading = false }

        runError = nil
        do {
            let run = try await client.run(input: input, sessionId: selectedSession?.id)
            activeRun = try await client.runStatus(runId: run.runId)
            runInput = ""
        } catch {
            runError = error.localizedDescription
        }
    }

    @MainActor
    private func stopRun(runId: String) async {
        guard let client else { return }

        do {
            _ = try await client.stopRun(runId: runId)
            activeRun = try await client.runStatus(runId: runId)
        } catch {
            runError = error.localizedDescription
        }
    }
}

private struct FlowTags: View {
    @Environment(\.hermesTheme) private var theme

    let values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(values.prefix(12), id: \.self) { value in
                Text(value)
                    .font(.caption)
                    .foregroundColor(theme.secondaryForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.secondary.opacity(0.68))
                    .cornerRadius(6)
            }
        }
    }
}

struct SettingsAboutContent: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(URL(string: "https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server")!)
        } label: {
            Label {
                Text("Hermes API Docs")
                    .foregroundColor(.primary)
            } icon: {
                Image(systemName: "book")
                    .foregroundColor(.appBlue)
            }
        }

        Button {
            openURL(URL(string: "https://nousresearch.com")!)
        } label: {
            Label {
                Text("Nous Research")
                    .foregroundColor(.primary)
            } icon: {
                Image(systemName: "network")
                    .foregroundColor(.appBlue)
            }
        }

    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
