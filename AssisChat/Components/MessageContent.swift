//
//  MessageContent.swift
//  AssisChat
//
//

import SwiftUI
import MarkdownUI
import Splash

struct MessageContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hermesTheme) private var theme

    @EnvironmentObject private var settingsFeature: SettingsFeature

    let content: String

    var body: some View {
        Markdown(content.trimmingCharacters(in: .whitespacesAndNewlines))
            .markdownTextStyle(textStyle: {
                FontSize(settingsFeature.selectedFontSize.value)
            })
            .markdownTextStyle(\.link, textStyle: {
                UnderlineStyle(.single)
                ForegroundColor(.primary.opacity(0.8))
            })
            .markdownBlockStyle(\.codeBlock) { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .font(theme.monoFont(size: settingsFeature.selectedFontSize.value * CGFloat(0.85)))
                        .padding(10)
                        .padding(.trailing, 20)
                }
                .background(theme.card.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.border.opacity(0.7), lineWidth: 1)
                )
                .cornerRadius(8)
                .padding(.bottom)
                .overlay(alignment: .topTrailing) {
                    Button {
                        Clipboard.copyToClipboard(text: configuration.content)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .padding(10)
                }
            }
            .markdownCodeSyntaxHighlighter(
                .splash(theme: colorScheme == .dark ? .wwdc17(withFont: .init(size: 16)) : .sunset(withFont: .init(size: 16)))
            )
            .textSelection(.enabled)
    }
}
struct MessageContent_Previews: PreviewProvider {
    static var previews: some View {
        MessageContent(content: "Hello")
    }
}
