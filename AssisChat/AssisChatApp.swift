//
//  AssisChatApp.swift
//  AssisChat
//
//

import SwiftUI

@main
struct AssisChatApp: App {
    let persistenceController = PersistenceController.shared

    @StateObject var essentialFeature: EssentialFeature
    @StateObject var proFeature: ProFeature
    @StateObject var settingsFeature: SettingsFeature
    let chatFeature: ChatFeature
    let messageFeature: MessageFeature
    let chattingFeature: ChattingFeature

    init() {
        SharedUserDefaults.migrateIfNeeded()
        Self.applyDebugHermesLaunchConfiguration()
        HermesFontLoader.registerBundledFonts()

        let essentialFeature = EssentialFeature(persistenceController: persistenceController)
        let proFeature = ProFeature()
        let settingsFeature = SettingsFeature(essentialFeature: essentialFeature)

        _essentialFeature = StateObject(wrappedValue: essentialFeature)
        _proFeature = StateObject(wrappedValue: proFeature)
        _settingsFeature = StateObject(wrappedValue: settingsFeature)
        chatFeature = ChatFeature(essentialFeature: essentialFeature)
        messageFeature = MessageFeature(essentialFeature: essentialFeature)
        chattingFeature = ChattingFeature(
            essentialFeature: essentialFeature,
            settingsFeature: settingsFeature,
            chatFeature: chatFeature,
            messageFeature: messageFeature)

        #if os(iOS)
        UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            let resolvedColorScheme = settingsFeature.selectedAppTheme.preferredColorScheme
            let theme = settingsFeature.selectedAppTheme.theme(for: resolvedColorScheme)

            HermesThemeHost {
                ContentView()
            }
//            #if os(macOS)
//                .frame(minWidth: 800, minHeight: 500)
//            #endif

                .environment(\.managedObjectContext, persistenceController.container.viewContext)

                .environmentObject(essentialFeature)
                .environmentObject(proFeature)
                .environmentObject(settingsFeature)
                .environmentObject(chatFeature)
                .environmentObject(messageFeature)
                .environmentObject(chattingFeature)
                .environment(\.hermesTheme, theme)

                // Initiations
            .preferredColorScheme(resolvedColorScheme)
            .tint(theme.primary)
            .symbolVariant(.fill)

                // Error showing
                .alert(
                    essentialFeature.currentAlert?.title ?? "",
                    isPresented: Binding(get: {
                        return essentialFeature.currentAlert != nil
                    }, set: { value in
                        if !value {
                            essentialFeature.dismissCurrentAlert()
                        }
                    }), actions: {

                    }, message: {
                        Text(essentialFeature.currentAlert?.message ?? "")
                    })
        }

        #if os(macOS)
        Settings {
            let resolvedColorScheme = settingsFeature.selectedAppTheme.preferredColorScheme
            let theme = settingsFeature.selectedAppTheme.theme(for: resolvedColorScheme)

            HermesThemeHost {
                MacOSSettingsView()
            }
                .environmentObject(essentialFeature)
                .environmentObject(settingsFeature)
                .environmentObject(proFeature)
                .environment(\.hermesTheme, theme)

                // Initiations
            .preferredColorScheme(resolvedColorScheme)
            .tint(theme.primary)
            .symbolVariant(.fill)
        }
        #endif
    }

    private static func applyDebugHermesLaunchConfiguration() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard
            let baseURL = environment["HERMES_TEST_BASE_URL"]?.nilIfBlank,
            let apiKey = environment["HERMES_TEST_API_KEY"]?.nilIfBlank
        else {
            return
        }

        SharedUserDefaults.shared.set(baseURL, forKey: SharedUserDefaults.hermesBaseURL)
        try? KeychainSecrets.set(apiKey, for: SharedUserDefaults.hermesAPIKey)

        if let model = environment["HERMES_TEST_MODEL"]?.nilIfBlank {
            SharedUserDefaults.shared.set(model, forKey: SharedUserDefaults.hermesModel)
            SharedUserDefaults.shared.set([model], forKey: SharedUserDefaults.hermesDiscoveredModels)
        }
        #endif
    }
}
