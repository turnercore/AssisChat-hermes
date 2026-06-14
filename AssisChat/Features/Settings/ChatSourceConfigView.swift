//
//  ChatSourceConfigView.swift
//  AssisChat
//
//

import SwiftUI

struct ChatSourceConfigView: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature
    @Environment(\.hermesTheme) private var theme

    let successAlert: Bool
    let backWhenConfigured: Bool
    let onConfigured: ((_: ChattingAdapter) -> Void)?

    var body: some View {
        Group {
            let view = HermesContent(
                apiKey: settingsFeature.configuredHermesAPIKey ?? "",
                baseURL: settingsFeature.configuredHermesBaseURL ?? "",
                sessionId: settingsFeature.configuredHermesSessionId ?? "",
                sessionKey: settingsFeature.configuredHermesSessionKey ?? "",
                successAlert: successAlert,
                backWhenConfigured: backWhenConfigured,
                onConfigured: onConfigured
            )
            .ignoresSafeArea()

            if #available(iOS 16, macOS 13, *) {
                view.scrollDismissesKeyboard(.immediately)
            } else {
                view
            }
        }
#if os(iOS)
        .background(theme.background)
#endif
    }
}

private struct HermesContent: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var essentialFeature: EssentialFeature
    @EnvironmentObject private var settingsFeature: SettingsFeature
    @Environment(\.hermesTheme) private var theme

    @State var apiKey: String
    @State var baseURL: String
    @State var sessionId: String
    @State var sessionKey: String
    @State private var defaultProfileDisplayName = ""

    @State private var validating = false
    @State private var showAdvancedOptions = false

    let successAlert: Bool
    let backWhenConfigured: Bool
    let onConfigured: ((_: ChattingAdapter) -> Void)?

    var body: some View {
        Form {
#if os(iOS)
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.accentColor)

                    Text("DaisyChat")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
#endif

            Section {
#if os(iOS)
                TextField("http://host:8642", text: $baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
#else
                TextField("", text: $baseURL)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
#endif
            } header: {
                Text("Hermes API Server")
            } footer: {
                Text("Run `hermes gateway`, then use the reachable server URL. Leave blank for http://127.0.0.1:8642.")
            }

            Section {
#if os(iOS)
                SecureField("API_SERVER_KEY", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
#else
                SecureField("", text: $apiKey)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
#endif
            } header: {
                Text("Bearer Token")
            } footer: {
                Text("Stored in Keychain. This key controls Hermes and its tools; use a strong local secret.")
            }

            Section {
#if os(iOS)
                TextField("My Hermes", text: $defaultProfileDisplayName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
#else
                TextField("", text: $defaultProfileDisplayName)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
#endif
            } header: {
                Text("Default Profile Display Name")
            } footer: {
                Text("Local-only label for `hermes-agent`. Requests still use the real Hermes model id.")
            }

            Section {
                Toggle("Advanced Hermes Options", isOn: $showAdvancedOptions)
            } footer: {
                Text("Most setups do not need these. Use advanced options only when binding requests to a specific Hermes session.")
            }

            if showAdvancedOptions {
                Section {
#if os(iOS)
                    TextField("mobile", text: $sessionId)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    TextField("agent:main:ios", text: $sessionKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
#else
                    TextField("", text: $sessionId)
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)
                    TextField("", text: $sessionKey)
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)
#endif
                } header: {
                    Text("Session Scope")
                } footer: {
                    Text("Optional Hermes headers for stateful workflows. Newlines and control characters are rejected. Session key is capped at 256 characters.")
                }
            }

            Section {
                Button {
                    validateAndSave()
                } label: {
                    HStack {
                        if validating {
                            UniformProgressView()
                        }

                        Text("SETTINGS_CHAT_SOURCE_VALIDATE_AND_SAVE")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
#if os(iOS)
                    .padding()
#else
                    .padding(5)
#endif
                    .background(theme.primary)
                    .foregroundColor(theme.primaryForeground)
                    .cornerRadius(10)
                }
                .disabled(validating)
                .listRowInsets(EdgeInsets())
                .buttonStyle(.plain)
            } footer: {
                Text("This app will send prompts and selected history to your configured Hermes server.")
            }

            CopyrightView()
                .listRowBackground(Color.clear)
        }
#if os(macOS)
        .padding()
#endif
        .onAppear {
            defaultProfileDisplayName = settingsFeature.hermesDefaultProfileDisplayName
        }
    }

    func validateAndSave() {
        Task {
            if apiKey.isEmpty {
                essentialFeature.appendAlert(alert: ErrorAlert(message: "SETTINGS_CHAT_SOURCE_NO_API_KEY"))
                return
            }

            do {
                validating = true
                settingsFeature.hermesDefaultProfileDisplayName = defaultProfileDisplayName
                let adapter = try await settingsFeature.validateAndConfigHermes(
                    apiKey: apiKey,
                    baseURL: baseURL.nilIfBlank,
                    sessionId: sessionId.nilIfBlank,
                    sessionKey: sessionKey.nilIfBlank
                )

                if successAlert {
                    essentialFeature.appendAlert(alert: GeneralAlert(title: "SUCCESS", message: "SETTINGS_CHAT_SOURCE_VALIDATE_AND_SAVE_SUCCESS"))
                }

                onConfigured?(adapter)

                if backWhenConfigured {
                    dismiss()
                }
            } catch ChattingError.validating(let message) {
                essentialFeature.appendAlert(alert: ErrorAlert(message: message))
            } catch {
                essentialFeature.appendAlert(alert: ErrorAlert(message: LocalizedStringKey(error.localizedDescription)))
            }

            validating = false
        }
    }
}

struct ChatSourceConfigView_Previews: PreviewProvider {
    static var previews: some View {
        ChatSourceConfigView(successAlert: false, backWhenConfigured: false) { _ in

        }
    }
}
