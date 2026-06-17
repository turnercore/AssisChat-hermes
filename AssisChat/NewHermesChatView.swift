//
//  NewHermesChatView.swift
//  AssisChat
//

import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

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

    let initialPrompt: String?
    let onChatCreated: (Chat) -> Void

    @State private var prompt = ""
    @State private var handling = false
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var connecting = false
    @State private var profileError: String?
    @State private var showingURLPrompt = false
    @State private var showingFileImporter = false
    @State private var urlAttachment = ""
    #if os(iOS)
    @State private var imageAttachmentSource: ImageAttachmentSource?
    #endif

    private var profiles: [String] {
        settingsFeature.availableHermesModels()
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

    init(initialPrompt: String? = nil, onChatCreated: @escaping (Chat) -> Void) {
        self.initialPrompt = initialPrompt
        self.onChatCreated = onChatCreated
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
            if baseURL.isEmpty {
                baseURL = settingsFeature.configuredHermesBaseURL ?? ""
            }
            if apiKey.isEmpty {
                apiKey = settingsFeature.configuredHermesAPIKey ?? ""
            }
            if let initialPrompt = initialPrompt?.nilIfBlank, prompt.nilIfBlank == nil {
                prompt = initialPrompt
            }
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
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.plainText, .text, .utf8PlainText, .data, .pdf, .image],
            allowsMultipleSelection: true
        ) { result in
            appendImportedFiles(result)
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

                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Files...", systemImage: "doc.badge.plus")
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
                .accessibilityLabel("Add context")

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
                .accessibilityLabel(handling ? "Sending task" : "Send task")
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
                .submitLabel(.done)
                .textFieldStyle(.roundedBorder)

            SecureField("API_SERVER_KEY", text: $apiKey)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.go)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    connect()
                }

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
        handling = true

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

        guard let chat else {
            handling = false
            essentialFeature.appendAlert(alert: ErrorAlert(message: "Could not create chat"))
            return
        }
        onChatCreated(chat)

        Task {
            defer { handling = false }
            _ = await chattingFeature.sendWithStream(content: input, to: chat)
            prompt = ""
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

    private func appendImportedFiles(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            for url in urls {
                appendImportedFile(url)
            }
        } catch {
            essentialFeature.appendAlert(alert: ErrorAlert(message: LocalizedStringKey(error.localizedDescription)))
        }
    }

    private func appendImportedFile(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let name = url.lastPathComponent.nilIfBlank ?? "Imported file"
        do {
            let values = try url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
            let type = values.contentType
            if type?.conforms(to: .text) == true || type?.conforms(to: .plainText) == true {
                let data = try Data(contentsOf: url)
                let limitedData = data.prefix(120_000)
                guard let text = String(data: Data(limitedData), encoding: .utf8)?.nilIfBlank else {
                    appendToPrompt("\n\nAttached file: \(name)")
                    return
                }
                appendToPrompt("\n\nFile: \(name)\n```text\n\(text)\n```")
            } else {
                let size = values.fileSize.map { " (\($0) bytes)" } ?? ""
                appendToPrompt("\n\nAttached file: \(name)\(size)")
            }
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
        guard !connecting, let token = apiKey.nilIfBlank else { return }
        if ProviderEndpoint.normalizedBaseURL(baseURL.nilIfBlank, defaultValue: "http://127.0.0.1:8642") == nil {
            essentialFeature.appendAlert(alert: ErrorAlert(message: "Invalid Hermes server URL"))
            return
        }

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
        guard settingsFeature.shouldRefreshHermesProfiles() else {
            profileError = nil
            return
        }

        guard
            let token = settingsFeature.configuredHermesAPIKey?.nilIfBlank,
            let url = ProviderEndpoint.normalizedBaseURL(settingsFeature.configuredHermesBaseURL, defaultValue: "http://127.0.0.1:8642")
        else {
            return
        }

        let client = HermesAPIClient(baseURL: url, apiKey: token)
        let ids = await client.profileCandidates()
        settingsFeature.updateHermesModels(ids)
        settingsFeature.markHermesProfilesRefreshed()
        profileError = ids.isEmpty ? "Connected, but profiles could not be refreshed." : nil
    }
}
