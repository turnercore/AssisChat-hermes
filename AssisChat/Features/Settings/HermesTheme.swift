//
//  HermesTheme.swift
//  AssisChat
//

import CoreText
import SwiftUI

struct HermesTheme {
    let name: String
    let label: String
    let description: String

    let background: Color
    let foreground: Color
    let card: Color
    let cardForeground: Color
    let muted: Color
    let mutedForeground: Color
    let popover: Color
    let popoverForeground: Color
    let primary: Color
    let primaryForeground: Color
    let secondary: Color
    let secondaryForeground: Color
    let accent: Color
    let accentForeground: Color
    let border: Color
    let input: Color
    let ring: Color
    let midground: Color
    let midgroundForeground: Color
    let composerRing: Color
    let destructive: Color
    let destructiveForeground: Color
    let sidebarBackground: Color
    let sidebarBorder: Color
    let userBubble: Color
    let userBubbleForeground: Color
    let userBubbleBorder: Color
    let fontMonoFamily: String

    func monoFont(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        Font.custom(fontMonoFamily, size: size, relativeTo: textStyle)
    }
}

private func hermesColor(_ hex: String) -> Color {
    Color(hex: hex) ?? .black
}

private extension HermesTheme {
    static let jetBrainsMono = "JetBrains Mono"

    static func modern() -> HermesTheme {
        HermesTheme(
            name: "modern",
            label: "Modern",
            description: "Legacy neutral glass theme",
            background: Color.background,
            foreground: .primary,
            card: Color.secondaryBackground,
            cardForeground: .primary,
            muted: Color.tertiaryBackground,
            mutedForeground: .secondary,
            popover: Color.secondaryGroupedBackground,
            popoverForeground: .primary,
            primary: .accentColor,
            primaryForeground: .white,
            secondary: Color.secondaryBackground,
            secondaryForeground: .primary,
            accent: .accentColor,
            accentForeground: .white,
            border: Color.secondaryGroupedBackground,
            input: Color.tertiaryBackground,
            ring: .accentColor,
            midground: .accentColor,
            midgroundForeground: .white,
            composerRing: .accentColor,
            destructive: .appRed,
            destructiveForeground: .white,
            sidebarBackground: Color.groupedBackground,
            sidebarBorder: Color.secondaryGroupedBackground,
            userBubble: .accentColor,
            userBubbleForeground: .white,
            userBubbleBorder: .accentColor,
            fontMonoFamily: Self.jetBrainsMono
        )
    }

    static func nous(light: Bool) -> HermesTheme {
        HermesTheme(
            name: "nous",
            label: "Nous",
            description: "Glass neutrals with Nous blue accents",
            background: light ? hermesColor("#F8FAFF") : hermesColor("#0D2F86"),
            foreground: light ? hermesColor("#17171A") : hermesColor("#FFE6CB"),
            card: light ? hermesColor("#FFFFFF") : hermesColor("#12378F"),
            cardForeground: light ? hermesColor("#17171A") : hermesColor("#FFE6CB"),
            muted: light ? hermesColor("#EEF4FF") : hermesColor("#183F9A"),
            mutedForeground: light ? hermesColor("#666678") : hermesColor("#B5C7F3"),
            popover: light ? hermesColor("#FFFFFF") : hermesColor("#123A96"),
            popoverForeground: light ? hermesColor("#17171A") : hermesColor("#FFE6CB"),
            primary: light ? hermesColor("#0053FD") : hermesColor("#FFE6CB"),
            primaryForeground: light ? hermesColor("#FCFCFC") : hermesColor("#0D2F86"),
            secondary: light ? hermesColor("#EDF4FF") : hermesColor("#1B45A4"),
            secondaryForeground: light ? hermesColor("#242432") : hermesColor("#E0E8FF"),
            accent: light ? hermesColor("#E6EEFF") : hermesColor("#1540B1"),
            accentForeground: light ? hermesColor("#202030") : hermesColor("#F0F4FF"),
            border: light ? hermesColor("#C9D9FF") : hermesColor("#3158AD"),
            input: light ? hermesColor("#D6E3FF") : hermesColor("#0B2566"),
            ring: light ? hermesColor("#0053FD") : hermesColor("#FFE6CB"),
            midground: light ? hermesColor("#0053FD") : hermesColor("#0053FD"),
            midgroundForeground: light ? hermesColor("#FFFFFF") : hermesColor("#FFE6CB"),
            composerRing: light ? hermesColor("#0053FD") : hermesColor("#FFE6CB"),
            destructive: light ? hermesColor("#C72E4D") : hermesColor("#C0473A"),
            destructiveForeground: light ? hermesColor("#FFFFFF") : hermesColor("#FEF2F2"),
            sidebarBackground: light ? hermesColor("#F3F7FF") : hermesColor("#09286F"),
            sidebarBorder: light ? hermesColor("#D9E5FF") : hermesColor("#234A9C"),
            userBubble: light ? hermesColor("#ECF3FF") : hermesColor("#143B91"),
            userBubbleForeground: light ? hermesColor("#17171A") : hermesColor("#FFE6CB"),
            userBubbleBorder: light ? hermesColor("#CFE0FF") : hermesColor("#3A63BD"),
            fontMonoFamily: Self.jetBrainsMono
        )
    }

    static func midnight() -> HermesTheme {
        HermesTheme(
            name: "midnight",
            label: "Midnight",
            description: "Deep blue-violet with cool accents",
            background: hermesColor("#08081c"),
            foreground: hermesColor("#ddd6ff"),
            card: hermesColor("#0d0d28"),
            cardForeground: hermesColor("#ddd6ff"),
            muted: hermesColor("#13133a"),
            mutedForeground: hermesColor("#7c7ab0"),
            popover: hermesColor("#0f0f2e"),
            popoverForeground: hermesColor("#ddd6ff"),
            primary: hermesColor("#ddd6ff"),
            primaryForeground: hermesColor("#08081c"),
            secondary: hermesColor("#1a1a4a"),
            secondaryForeground: hermesColor("#c4bff0"),
            accent: hermesColor("#1a1a44"),
            accentForeground: hermesColor("#d0c8ff"),
            border: hermesColor("#1e1e52"),
            input: hermesColor("#1e1e52"),
            ring: hermesColor("#8b80e8"),
            midground: hermesColor("#8b80e8"),
            midgroundForeground: hermesColor("#ddd6ff"),
            composerRing: hermesColor("#8b80e8"),
            destructive: hermesColor("#b03060"),
            destructiveForeground: hermesColor("#fef2f2"),
            sidebarBackground: hermesColor("#06061a"),
            sidebarBorder: hermesColor("#12123a"),
            userBubble: hermesColor("#14143a"),
            userBubbleForeground: hermesColor("#ddd6ff"),
            userBubbleBorder: hermesColor("#242466"),
            fontMonoFamily: Self.jetBrainsMono
        )
    }

    static func ember() -> HermesTheme {
        HermesTheme(
            name: "ember",
            label: "Ember",
            description: "Warm crimson and bronze - forge vibes",
            background: hermesColor("#160800"),
            foreground: hermesColor("#ffd8b0"),
            card: hermesColor("#1e0e04"),
            cardForeground: hermesColor("#ffd8b0"),
            muted: hermesColor("#2a1408"),
            mutedForeground: hermesColor("#aa7a56"),
            popover: hermesColor("#221008"),
            popoverForeground: hermesColor("#ffd8b0"),
            primary: hermesColor("#ffd8b0"),
            primaryForeground: hermesColor("#160800"),
            secondary: hermesColor("#341800"),
            secondaryForeground: hermesColor("#f0c090"),
            accent: hermesColor("#301600"),
            accentForeground: hermesColor("#e8c080"),
            border: hermesColor("#3a1c08"),
            input: hermesColor("#3a1c08"),
            ring: hermesColor("#d97316"),
            midground: hermesColor("#d97316"),
            midgroundForeground: hermesColor("#ffd8b0"),
            composerRing: hermesColor("#d97316"),
            destructive: hermesColor("#c43010"),
            destructiveForeground: hermesColor("#fef2f2"),
            sidebarBackground: hermesColor("#100600"),
            sidebarBorder: hermesColor("#2a1004"),
            userBubble: hermesColor("#2a1000"),
            userBubbleForeground: hermesColor("#ffd8b0"),
            userBubbleBorder: hermesColor("#4a2010"),
            fontMonoFamily: Self.jetBrainsMono
        )
    }

    static func mono() -> HermesTheme {
        HermesTheme(
            name: "mono",
            label: "Mono",
            description: "Clean grayscale - minimal and focused",
            background: hermesColor("#0e0e0e"),
            foreground: hermesColor("#eaeaea"),
            card: hermesColor("#141414"),
            cardForeground: hermesColor("#eaeaea"),
            muted: hermesColor("#1e1e1e"),
            mutedForeground: hermesColor("#808080"),
            popover: hermesColor("#181818"),
            popoverForeground: hermesColor("#eaeaea"),
            primary: hermesColor("#eaeaea"),
            primaryForeground: hermesColor("#0e0e0e"),
            secondary: hermesColor("#262626"),
            secondaryForeground: hermesColor("#c8c8c8"),
            accent: hermesColor("#222222"),
            accentForeground: hermesColor("#d8d8d8"),
            border: hermesColor("#2a2a2a"),
            input: hermesColor("#2a2a2a"),
            ring: hermesColor("#9a9a9a"),
            midground: hermesColor("#9a9a9a"),
            midgroundForeground: hermesColor("#eaeaea"),
            composerRing: hermesColor("#9a9a9a"),
            destructive: hermesColor("#a84040"),
            destructiveForeground: hermesColor("#fef2f2"),
            sidebarBackground: hermesColor("#0a0a0a"),
            sidebarBorder: hermesColor("#202020"),
            userBubble: hermesColor("#1a1a1a"),
            userBubbleForeground: hermesColor("#eaeaea"),
            userBubbleBorder: hermesColor("#363636"),
            fontMonoFamily: Self.jetBrainsMono
        )
    }

    static func cyberpunk() -> HermesTheme {
        HermesTheme(
            name: "cyberpunk",
            label: "Cyberpunk",
            description: "Neon green on black - matrix terminal",
            background: hermesColor("#000a00"),
            foreground: hermesColor("#00ff41"),
            card: hermesColor("#001200"),
            cardForeground: hermesColor("#00ff41"),
            muted: hermesColor("#001a00"),
            mutedForeground: hermesColor("#1a8a30"),
            popover: hermesColor("#001000"),
            popoverForeground: hermesColor("#00ff41"),
            primary: hermesColor("#00ff41"),
            primaryForeground: hermesColor("#000a00"),
            secondary: hermesColor("#002800"),
            secondaryForeground: hermesColor("#00cc34"),
            accent: hermesColor("#002000"),
            accentForeground: hermesColor("#00e038"),
            border: hermesColor("#003000"),
            input: hermesColor("#003000"),
            ring: hermesColor("#00ff41"),
            midground: hermesColor("#00ff41"),
            midgroundForeground: hermesColor("#000a00"),
            composerRing: hermesColor("#00ff41"),
            destructive: hermesColor("#ff003c"),
            destructiveForeground: hermesColor("#000a00"),
            sidebarBackground: hermesColor("#000600"),
            sidebarBorder: hermesColor("#001800"),
            userBubble: hermesColor("#001400"),
            userBubbleForeground: hermesColor("#00ff41"),
            userBubbleBorder: hermesColor("#004800"),
            fontMonoFamily: "Courier New"
        )
    }

    static func slate() -> HermesTheme {
        HermesTheme(
            name: "slate",
            label: "Slate",
            description: "Cool slate blue - focused developer theme",
            background: hermesColor("#0d1117"),
            foreground: hermesColor("#c9d1d9"),
            card: hermesColor("#161b22"),
            cardForeground: hermesColor("#c9d1d9"),
            muted: hermesColor("#21262d"),
            mutedForeground: hermesColor("#8b949e"),
            popover: hermesColor("#1c2128"),
            popoverForeground: hermesColor("#c9d1d9"),
            primary: hermesColor("#c9d1d9"),
            primaryForeground: hermesColor("#0d1117"),
            secondary: hermesColor("#2a3038"),
            secondaryForeground: hermesColor("#adb5bf"),
            accent: hermesColor("#1e2530"),
            accentForeground: hermesColor("#c0c8d0"),
            border: hermesColor("#30363d"),
            input: hermesColor("#30363d"),
            ring: hermesColor("#58a6ff"),
            midground: hermesColor("#58a6ff"),
            midgroundForeground: hermesColor("#c9d1d9"),
            composerRing: hermesColor("#58a6ff"),
            destructive: hermesColor("#cf4848"),
            destructiveForeground: hermesColor("#fef2f2"),
            sidebarBackground: hermesColor("#090d13"),
            sidebarBorder: hermesColor("#1c2228"),
            userBubble: hermesColor("#1e2a38"),
            userBubbleForeground: hermesColor("#c9d1d9"),
            userBubbleBorder: hermesColor("#2e4060"),
            fontMonoFamily: Self.jetBrainsMono
        )
    }
}

private struct HermesThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = HermesTheme.modern()
}

extension EnvironmentValues {
    var hermesTheme: HermesTheme {
        get { self[HermesThemeEnvironmentKey.self] }
        set { self[HermesThemeEnvironmentKey.self] = newValue }
    }
}

struct HermesThemeHost<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settingsFeature: SettingsFeature

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let effectiveColorScheme = settingsFeature.selectedAppTheme.preferredColorScheme
        let theme = settingsFeature.selectedAppTheme.theme(for: effectiveColorScheme)

        ZStack {
            HermesThemeBackdrop(theme: theme)
            content
        }
        .environment(\.hermesTheme, theme)
    }
}

private struct HermesThemeBackdrop: View {
    let theme: HermesTheme

    var body: some View {
        ZStack {
            theme.background

            LinearGradient(
                colors: [
                    theme.sidebarBackground,
                    theme.background,
                    theme.input.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HermesGridTexture(theme: theme, opacity: 0.13)
        }
        .ignoresSafeArea()
    }
}

struct HermesGridTexture: View {
    let theme: HermesTheme
    var opacity: Double

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                var path = Path()
                let spacing: CGFloat = 38
                var x: CGFloat = -size.height
                while x < size.width + size.height {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    x += spacing
                }

                context.stroke(
                    path,
                    with: .color(theme.border.opacity(opacity)),
                    lineWidth: 0.75
                )

                var horizontal = Path()
                var y: CGFloat = 0
                while y < size.height {
                    horizontal.move(to: CGPoint(x: 0, y: y))
                    horizontal.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing * 1.8
                }

                context.stroke(
                    horizontal,
                    with: .color(theme.primary.opacity(opacity * 0.7)),
                    lineWidth: 0.5
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }
}

extension SettingsFeature.AppTheme {
    func theme(for colorScheme: SwiftUI.ColorScheme) -> HermesTheme {
        switch self {
        case .modern:
            return HermesTheme.modern()
        case .nous:
            return HermesTheme.nous(light: colorScheme != .dark)
        case .hermesNous:
            return HermesTheme.nous(light: colorScheme != .dark)
        case .midnight:
            return HermesTheme.midnight()
        case .ember:
            return HermesTheme.ember()
        case .mono:
            return HermesTheme.mono()
        case .cyberpunk:
            return HermesTheme.cyberpunk()
        case .slate:
            return HermesTheme.slate()
        }
    }
}

enum HermesFontLoader {
    private static var didRegister = false

    static func registerBundledFonts() {
        guard !didRegister else { return }
        didRegister = true

        let urls = Bundle.main.urls(forResourcesWithExtension: "woff2", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
