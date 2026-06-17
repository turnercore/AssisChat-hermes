//
//  ChattingView.swift
//  AssisChat
//
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ChattingView: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature
    @EnvironmentObject private var essentialFeature: EssentialFeature
    @EnvironmentObject private var chattingFeature: ChattingFeature
    @Environment(\.hermesTheme) private var theme

    @ObservedObject var chat: Chat
    @State var activeMessageId: ObjectIdentifier?

    @FetchRequest
    private var messages: FetchedResults<Message>

    init(chat: Chat) {
        _chat = ObservedObject(wrappedValue: chat)
        _messages = FetchRequest<Message>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Message.rawTimestamp, ascending: false)],
            predicate: chat.predicate
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                MessagesEmpty()
            } else {
                let scrollView = messagesListView()

                if #available(iOS 16, macOS 13, *) {
                    scrollView
                        .scrollDismissesKeyboard(.immediately)
                } else {
                    scrollView
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MessageInput(chat: chat)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !availableModels.isEmpty {
                HStack {
                    Spacer()
                    ChatModelBadge(
                        currentModel: chat.model,
                        availableModels: availableModels,
                        onSelectModel: setChatModel
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
            }
        }
        .background(HermesWorkspaceBackground(theme: theme).ignoresSafeArea())
    }

    private var availableModels: [String] {
        settingsFeature.availableHermesModels()
    }

    private func setChatModel(_ model: String) {
        chat.rawModel = model
        settingsFeature.configuredHermesModel = model
        settingsFeature.initiateHermesAdapter()
        essentialFeature.persistData()
    }

    @ViewBuilder
    private func messagesListView() -> some View {
        ScrollView {
            Rectangle()
                .fill(.clear)
                .frame(height: 10)

            ForEach(messages) { (message: Message) in
                MessageItem(message: message, activation: $activeMessageId)
            }
            .padding(.horizontal, 10)
            .scaleEffect(x: 1, y: -1, anchor: .center)

            Rectangle()
                .fill(.clear)
                .frame(height: 20)
        }
        .scaleEffect(x: 1, y: -1, anchor: .center)
        .animation(.easeOut, value: messages.count)
        .background(Color.clear)
    }
}

private struct ChatModelBadge: View {
    @EnvironmentObject private var settingsFeature: SettingsFeature
    @Environment(\.hermesTheme) private var theme

    let currentModel: String?
    let availableModels: [String]
    let onSelectModel: (String) -> Void

    var body: some View {
        Menu {
            ForEach(availableModels, id: \.self) { model in
                Button {
                    onSelectModel(model)
                } label: {
                    if model == currentModel {
                        Label(settingsFeature.displayName(forHermesModel: model), systemImage: "checkmark")
                    } else {
                        Text(settingsFeature.displayName(forHermesModel: model))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.caption.weight(.semibold))
                Text(settingsFeature.displayName(forHermesModel: currentModel))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundColor(theme.secondaryForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(theme.card.opacity(0.62))
            .overlay(
                Capsule()
                    .stroke(theme.border.opacity(0.58), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(availableModels.isEmpty)
    }
}

private struct MessagesEmpty: View {
    @Environment(\.hermesTheme) private var theme

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: "bubble.right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(Color.appGreen)

                    Text("Send a message to start this chat.")
                        .multilineTextAlignment(.leading)
                }
            }
            .foregroundColor(.secondary)
            .frame(alignment: .leading)
            .padding()
            .background(theme.card.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(theme.border.opacity(0.75), lineWidth: 1)
            )
            .cornerRadius(15)
            .padding()
        }
        .frame(maxHeight: .infinity)
    }
}

private struct MessageItem: View {
    @EnvironmentObject private var messageFeature: MessageFeature

    @ObservedObject var message: Message
    @Binding var activation: ObjectIdentifier?

    var active: Bool {
        activation == message.id
    }

    var body: some View {
        if message.role == .assistant {
            AssistantMessage(message: message, active: active) {
                toggleActive()
                Haptics.veryLight()
            }
        } else {
            UserMessage(message: message, active: active) {
                toggleActive()
                Haptics.veryLight()
            }
        }
    }

    func toggleActive() {
        withAnimation {
            if (active) {
                activation = nil
            } else {
                activation = message.id
            }
        }
    }
}

private struct AssistantMessage: View {
    @EnvironmentObject private var messageFeature: MessageFeature
    @EnvironmentObject private var chattingFeature: ChattingFeature
    @Environment(\.hermesTheme) private var theme

    let message: Message
    let active: Bool
    let toggleActive: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack {
                VStack(alignment: .trailing) {
                    if let content = message.content {
                        MessageContent(content: content)
                        if message.receiving, let progress = message.processedContent?.nilIfBlank {
                            ToolProgressPill(progress: progress)
                                .padding(.top, 4)
                        }
                    } else if message.receiving {
                        HStack(spacing: 8) {
                            UniformProgressView()
                            if let progress = message.processedContent?.nilIfBlank {
                                ToolProgressPill(progress: progress)
                            }
                        }
                    } else if let reason = message.failedReason {
                        Label(reason.localized, systemImage: "info.circle")
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 15)
                .foregroundColor(message.failed ? theme.destructiveForeground : theme.cardForeground)
                .background(message.failed ? theme.destructive : theme.card.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(message.failed ? theme.destructive.opacity(0.55) : theme.border.opacity(0.55), lineWidth: 1)
                )
                .cornerRadius(15)
                .onTapGesture {
                    toggleActive()
                }

                Spacer(minLength: 50)
            }
            .overlay(alignment: .bottomLeading) {
                if active && !message.receiving {
                    HStack {
                        Button(role: .destructive) {
                            withAnimation {
                                messageFeature.deleteMessages([message])
                            }
                        } label: {
                            Image(systemName: "trash")
                                .padding(6)
                                .foregroundColor(.appRed)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.vertical, 4)

                        Button {
                            withAnimation {
                                message.copyToPasteboard()
                                toggleActive()
                            }
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .padding(6)
                                .foregroundColor(.appBlue)
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation {
                                toggleActive()

                                Task {
                                    await chattingFeature.resendWithStream(receivingMessage: message)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .padding(6)
                                .foregroundColor(.appOrange)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background(theme.card.opacity(0.92))
                    .cornerRadius(.infinity)
                    .transition(.scale(scale: 0, anchor: .bottomLeading).animation(.spring().speed(2)))
                    .overlay(
                        RoundedRectangle(cornerRadius: .infinity)
                            .stroke(theme.composerRing.opacity(0.6), lineWidth: 1)
                    )
                    .padding(3)
                }
            }
        }
    }
}

private struct ToolProgressPill: View {
    @Environment(\.hermesTheme) private var theme

    let progress: String

    var body: some View {
        Label(trimmedProgress, systemImage: "wrench.and.screwdriver")
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .foregroundColor(theme.secondaryForeground)
            .background(theme.secondary.opacity(0.7))
            .clipShape(Capsule())
            .help(progress)
    }

    private var trimmedProgress: String {
        let value = progress.replacingOccurrences(of: "\n", with: " ")
        return value.count > 80 ? String(value.prefix(80)) + "..." : value
    }
}

private struct UserMessage: View {
    @EnvironmentObject private var messageFeature: MessageFeature
    @Environment(\.hermesTheme) private var theme

    let message: Message
    let active: Bool
    let toggleActive: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 50)
            MessageContent(content: message.content ?? "")
                .padding(.vertical, 8)
                .padding(.horizontal, 15)
                .background(theme.userBubble)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(theme.userBubbleBorder.opacity(0.7), lineWidth: 1)
                )
                .cornerRadius(15)
                .foregroundColor(theme.userBubbleForeground)
                .onTapGesture {
                    toggleActive()
                }
        }
        .overlay(alignment: .bottomTrailing) {
            if (active) {
                HStack {
                    Button {
                        withAnimation {
                            message.copyToPasteboard()
                            toggleActive()
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .padding(5)
                            .foregroundColor(.appBlue)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.vertical, 5)

                    Button(role: .destructive) {
                        withAnimation {
                            messageFeature.deleteMessages([message])
                        }
                    } label: {
                        Image(systemName: "trash")
                            .padding(5)
                            .foregroundColor(.appRed)

                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(theme.card.opacity(0.92))
                .cornerRadius(.infinity)
                .transition(.scale(scale: 0, anchor: .bottomTrailing).animation(.spring().speed(2)))
                .overlay(
                    RoundedRectangle(cornerRadius: .infinity)
                        .stroke(theme.composerRing.opacity(0.6), lineWidth: 1)
                )
                .padding(3)
            }
        }
    }
}

private struct MessageInput: View {
    @EnvironmentObject private var essentialFeature: EssentialFeature
    @EnvironmentObject private var settingsFeature: SettingsFeature
    @EnvironmentObject private var chattingFeature: ChattingFeature
    @EnvironmentObject private var messageFeature: MessageFeature
    @Environment(\.hermesTheme) private var theme

    @ObservedObject var chat: Chat
    @State private var text = ""
    @State private var handling = false
    #if os(iOS)
    @State private var imageAttachmentSource: ImageAttachmentSource?
    #endif

    var adapterReady: Bool {
        chat.model != nil && settingsFeature.modelToAdapter[chat.model!] != nil
    }

    var sendButtonAvailable: Bool {
        text.nilIfBlank != nil && !chat.receiving && adapterReady && !handling
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
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
                        appendInstruction("Use the appropriate Hermes tools for this request. Show concise progress and summarize only the useful result.")
                    } label: {
                        Label("Use tools", systemImage: "hammer")
                    }

                    Button {
                        appendInstruction("Inspect the relevant files or project context before answering. Keep the final response focused.")
                    } label: {
                        Label("Inspect context", systemImage: "folder.badge.gearshape")
                    }

                    Button {
                        appendInstruction("Run the necessary checks or commands, then report the outcome and any failures.")
                    } label: {
                        Label("Run checks", systemImage: "checkmark.seal")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.primary)
                        .frame(width: 41, height: 41)
                        .background(theme.card.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.border.opacity(0.7), lineWidth: 1)
                        )
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add context")

                if #available(iOS 16.0, macOS 13.0, *) {
                    TextField(adapterReady ? String(localized: "NEW_MESSAGE_HINT") : String(localized: "The model \"\(settingsFeature.displayName(forHermesModel: chat.model))\" is not available"), text: $text, axis: .vertical)
                        .padding(8)
                        .background(theme.input.opacity(0.72))
                        .cornerRadius(10)
                        .frame(minHeight: 45)
                        .lineLimit(1...3)
                        .submitLabel(.send)
                        .textFieldStyle(.plain)
                        .disabled(!adapterReady || handling)
                        .foregroundColor(handling ? .secondary : .primary)
#if os(macOS)
                        .onSubmit {
                            submit()
                        }
#endif
                } else {
                    TextField(adapterReady ? String(localized: "NEW_MESSAGE_HINT") : String(localized: "The model \"\(settingsFeature.displayName(forHermesModel: chat.model))\" is not available"), text: $text)
                        .padding(8)
                        .background(theme.input.opacity(0.72))
                        .frame(minHeight: 45)
                        .cornerRadius(10)
                        .submitLabel(.send)
                        .textFieldStyle(.plain)
                        .disabled(!adapterReady || handling)
                        .foregroundColor(handling ? .secondary : .primary)
#if os(macOS)
                        .onSubmit {
                            submit()
                        }
#endif
                }

                Button {
                    if chat.receiving {
                        messageFeature.stopReceivingMessage(for: chat)
                    } else {
                        submit()
                    }
                } label: {
                    if chat.receiving {
                        Image(systemName: "stop.fill")
                            .foregroundColor(theme.primary)
                    } else {
                        Image(systemName: "paperplane")
                            .foregroundColor(sendButtonAvailable ? theme.primaryForeground : theme.mutedForeground)
                    }
                }
                .buttonStyle(.plain)
#if os(iOS)
                .frame(width: 41, height: 41)
#else
                .frame(width: 31, height: 31)
#endif
                .background(sendButtonAvailable ? theme.primary : theme.card.opacity(0.92))
                .cornerRadius(.infinity)
                .padding(2)
#if os(macOS)
                .padding(.vertical, 5)
#endif
                .clipShape(Rectangle())
                .disabled(!chat.receiving && !sendButtonAvailable)
                .accessibilityLabel(chat.receiving ? "Stop response" : "Send message")
            }
#if os(iOS)
            .padding(10)
#else
            .padding(5)
#endif
            .background(theme.input.opacity(0.88))
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
        #if os(iOS)
        .sheet(item: $imageAttachmentSource) { source in
            ImageAttachmentPicker(source: source) { result in
                appendImageAttachment(result)
            }
        }
        #endif
    }

    func submit() {
        guard sendButtonAvailable, let content = text.nilIfBlank else { return }
        handling = true
        Task {
            defer { handling = false }
            _ = await chattingFeature.sendWithStream(content: content, to: chat)
            text = ""
        }
    }

    private func appendInstruction(_ instruction: String) {
        if text.nilIfBlank == nil {
            text = instruction
        } else {
            text += "\n\n\(instruction)"
        }
    }

    #if os(iOS)
    private func appendImageAttachment(_ result: Result<UIImage, Error>) {
        do {
            let image = try result.get()
            appendInstruction(try ImagePromptAttachment.block(from: image))
        } catch {
            essentialFeature.appendAlert(alert: ErrorAlert(message: LocalizedStringKey(error.localizedDescription)))
        }
    }
    #endif
}

struct ChattingView_Previews: PreviewProvider {
    static var previews: some View {
        ChattingView(chat: .init())
    }
}
