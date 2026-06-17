//
//  AssisChatWidgets.swift
//  AssisChatWidgets
//

import AppIntents
import SwiftUI
import WidgetKit

private enum WidgetSharedDefaults {
    static let suiteName = "group.com.turnercore.AssisChatHermes"
    static let baseURLKey = "settings:hermes:baseURL"
    static let modelKey = "settings:hermes:model"
    static let discoveredModelsKey = "settings:hermes:discoveredModels"
    static let defaultModel = "hermes-agent"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

private struct HermesWidgetEntry: TimelineEntry {
    let date: Date
    let baseURL: String?
    let model: String
    let latestStatus: String?

    var isConfigured: Bool {
        baseURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

private struct HermesWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HermesWidgetEntry {
        HermesWidgetEntry(date: Date(), baseURL: "Hermes", model: WidgetSharedDefaults.defaultModel, latestStatus: "Ready")
    }

    func getSnapshot(in context: Context, completion: @escaping (HermesWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HermesWidgetEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func currentEntry() -> HermesWidgetEntry {
        let defaults = WidgetSharedDefaults.defaults
        let model = defaults?.string(forKey: WidgetSharedDefaults.modelKey)
            ?? (defaults?.stringArray(forKey: WidgetSharedDefaults.discoveredModelsKey)?.first)
            ?? WidgetSharedDefaults.defaultModel

        return HermesWidgetEntry(
            date: Date(),
            baseURL: defaults?.string(forKey: WidgetSharedDefaults.baseURLKey),
            model: model,
            latestStatus: defaults?.string(forKey: "widget:hermes:lastStatus")
        )
    }
}

private struct HermesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HermesWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 12) {
            HStack {
                Image(systemName: entry.isConfigured ? "bolt.horizontal.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(entry.isConfigured ? .green : .orange)
                Text("Hermes")
                    .font(.headline)
                Spacer(minLength: 0)
            }

            Text(entry.isConfigured ? entry.model : "Not configured")
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(entry.latestStatus ?? (entry.isConfigured ? "Ready for a new task" : "Open DaisyChat to connect"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(family == .systemSmall ? 2 : 3)

            Spacer(minLength: 0)

            if family != .systemSmall {
                HStack(spacing: 10) {
                    Link(destination: URL(string: "daisychat://new")!) {
                        Label("New", systemImage: "square.and.pencil")
                    }
                    Link(destination: URL(string: "daisychat://health")!) {
                        Label("Health", systemImage: "heart.text.square")
                    }
                }
                .font(.caption.weight(.semibold))
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.18, blue: 0.55), Color(red: 0.02, green: 0.04, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(URL(string: "daisychat://new"))
    }
}

struct HermesStatusWidget: Widget {
    let kind = "com.turnercore.AssisChatHermes.widgets.status"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HermesWidgetProvider()) { entry in
            HermesWidgetView(entry: entry)
        }
        .configurationDisplayName("Hermes")
        .description("Start a task and check your Hermes configuration.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(iOSApplicationExtension 18.0, *)
struct OpenHermesTaskControlIntent: AppIntent {
    static var title: LocalizedStringResource = "New Hermes Task"
    static var description = IntentDescription("Open DaisyChat ready for a new Hermes task.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "daisychat://new")!))
    }
}

@available(iOSApplicationExtension 18.0, *)
struct CheckHermesHealthControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Hermes Health"
    static var description = IntentDescription("Open DaisyChat to the Hermes health surface.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "daisychat://health")!))
    }
}

@available(iOSApplicationExtension 18.0, *)
struct HermesNewTaskControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.turnercore.AssisChatHermes.controls.newTask") {
            ControlWidgetButton(action: OpenHermesTaskControlIntent()) {
                Label("New Task", systemImage: "square.and.pencil")
            }
        }
        .displayName("New Hermes Task")
        .description("Open DaisyChat ready for a new Hermes task.")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct HermesHealthControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.turnercore.AssisChatHermes.controls.health") {
            ControlWidgetButton(action: CheckHermesHealthControlIntent()) {
                Label("Hermes Health", systemImage: "heart.text.square")
            }
        }
        .displayName("Hermes Health")
        .description("Open DaisyChat to check Hermes health.")
    }
}

@main
struct AssisChatWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        HermesStatusWidget()
        if #available(iOSApplicationExtension 18.0, *) {
            HermesNewTaskControl()
            HermesHealthControl()
        }
    }
}
