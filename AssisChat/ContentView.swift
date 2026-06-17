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
    @State private var newSessionPrompt: String?

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.rawUpdatedAt, order: .reverse)]
    ) private var chats: FetchedResults<Chat>

    private var showingDetail: Bool {
        selectedChat != nil || selectedHermesSession != nil || showingSettings || showingNewSession
    }

    private var latestChat: Chat? {
        chats.first { !settingsFeature.isChatArchived($0) }
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
                    NewHermesChatView(initialPrompt: newSessionPrompt) { chat in
                        selectedChat = chat
                        selectedHermesSession = nil
                        showingSettings = false
                        showingNewSession = false
                        newSessionPrompt = nil
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
                            newSessionPrompt = nil
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
                    newSessionPrompt = nil
                } label: {
                            Label("Sessions", systemImage: "sidebar.leading")
                        }
                    }
                }
            }
        }
        .onAppear {
            consumePendingIntentRoute()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            consumePendingIntentRoute()
        }
        .onOpenURL { url in
            if HermesIntentRouter.request(url: url) {
                consumePendingIntentRoute()
            }
        }
    }

    private func consumePendingIntentRoute() {
        guard let route = HermesIntentRouter.consume() else { return }

        selectedChat = nil
        selectedHermesSession = nil
        showingSettings = false
        showingNewSession = false
        newSessionPrompt = nil

        switch route {
        case .newTask(let prompt):
            newSessionPrompt = prompt
            showingNewSession = true
        case .recentSession(let session):
            selectedHermesSession = session
        case .localChat(let id):
            if let chat = chat(for: id) {
                selectedChat = chat
            } else {
                showingNewSession = true
            }
        case .continueLastChat:
            if let latestChat {
                selectedChat = latestChat
            } else {
                showingNewSession = true
            }
        case .health:
            showingSettings = true
        }
    }

    private func chat(for id: String) -> Chat? {
        chats.first { chat in
            chat.objectID.uriRepresentation().absoluteString == id
        }
    }
}

@available(iOS 16.0, *)
private struct ContentSplitView: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature

    @State private var selectedChat: Chat?
    @State private var selectedHermesSession: HermesAPIClient.Session?
    @State private var showingSettings = false
    @State private var splitVisibility: NavigationSplitViewVisibility = .all
    @State private var newSessionPrompt: String?

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.rawUpdatedAt, order: .reverse)]
    ) private var chats: FetchedResults<Chat>

    private var latestChat: Chat? {
        chats.first { !settingsFeature.isChatArchived($0) }
    }

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
                    newSessionPrompt = nil
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
                        .navigationTitle("DaisyChat")
                } else if let selectedChat {
                    ChattingView(chat: selectedChat)
                } else if let selectedHermesSession {
                    HermesSessionDetailView(session: selectedHermesSession)
                        .id(selectedHermesSession.id)
                        .navigationTitle(selectedHermesSession.displayTitle)
                } else {
                    NewHermesChatView(initialPrompt: newSessionPrompt) { chat in
                        selectedChat = chat
                        selectedHermesSession = nil
                        newSessionPrompt = nil
                        hideSidebarAndResetDetail()
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    splitVisibility = .detailOnly
                }
            )
        }
        .onAppear {
            consumePendingIntentRoute()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            consumePendingIntentRoute()
        }
        .onOpenURL { url in
            if HermesIntentRouter.request(url: url) {
                consumePendingIntentRoute()
            }
        }
    }

    private func hideSidebarAndResetDetail() {
        splitVisibility = .detailOnly
    }

    private func consumePendingIntentRoute() {
        guard let route = HermesIntentRouter.consume() else { return }

        selectedChat = nil
        selectedHermesSession = nil
        showingSettings = false
        newSessionPrompt = nil

        switch route {
        case .newTask(let prompt):
            newSessionPrompt = prompt
            break
        case .recentSession(let session):
            selectedHermesSession = session
        case .localChat(let id):
            selectedChat = chat(for: id)
        case .continueLastChat:
            selectedChat = latestChat
        case .health:
            showingSettings = true
        }

        hideSidebarAndResetDetail()
    }

    private func chat(for id: String) -> Chat? {
        chats.first { chat in
            chat.objectID.uriRepresentation().absoluteString == id
        }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
