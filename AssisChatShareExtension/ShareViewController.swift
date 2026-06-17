//
//  ShareViewController.swift
//  AssisChatShareExtension
//

import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        Task { await handleShare() }
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        statusLabel.text = "Sending to DaisyChat..."
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @MainActor
    private func handleShare() async {
        let prompt = await sharedPrompt()
        storePendingPrompt(prompt.nilIfBlank ?? "Shared from iOS")

        statusLabel.text = "Opening DaisyChat..."
        _ = await extensionContext?.open(URL(string: "daisychat://new")!)
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func sharedPrompt() async -> String {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        var fragments: [String] = []

        for item in items {
            for provider in item.attachments ?? [] {
                if let text = await loadText(from: provider) {
                    fragments.append(text)
                } else if let url = await loadURL(from: provider) {
                    fragments.append(url.absoluteString)
                } else if let file = await loadFileURL(from: provider) {
                    fragments.append("Shared file: \(file.lastPathComponent)")
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    fragments.append("Shared image")
                }
            }
        }

        return fragments.joined(separator: "\n\n")
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        await loadItem(from: provider, typeIdentifier: UTType.text.identifier) as? String
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await loadItem(from: provider, typeIdentifier: UTType.url.identifier) as? URL
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await loadItem(from: provider, typeIdentifier: UTType.fileURL.identifier) as? URL
    }

    private func loadItem(from provider: NSItemProvider, typeIdentifier: String) async -> NSSecureCoding? {
        guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { return nil }

        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                continuation.resume(returning: item)
            }
        }
    }

    private func storePendingPrompt(_ prompt: String) {
        guard let defaults = UserDefaults(suiteName: "group.com.turnercore.AssisChatHermes") else { return }
        defaults.set("newTask", forKey: "intent:hermes:route")
        defaults.set(prompt, forKey: "intent:hermes:prompt")
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
