import SwiftUI
import AppKit
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let selectedThemeKey = "sweep.selectedTheme"
    static let minimalSchemeKey = "sweep.minimalColorScheme"

    /// 持久化：当前顶层主题
    var selectedThemeRaw: String {
        get { UserDefaults.standard.string(forKey: Self.selectedThemeKey) ?? AppTheme.defaultForCurrentUser.rawValue }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.selectedThemeKey)
            objectWillChange.send()
            resolveTheme()
        }
    }

    /// 持久化：极简科技变体
    var minimalColorSchemeRaw: String {
        get { UserDefaults.standard.string(forKey: Self.minimalSchemeKey) ?? MinimalColorScheme.system.rawValue }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.minimalSchemeKey)
            objectWillChange.send()
            resolveTheme()
        }
    }

    /// 系统当前外观
    @Published private(set) var systemColorScheme: ColorScheme = .light
    /// 当前生效的主题
    @Published private(set) var currentTheme: Theme = .minimalLight
    /// 当前极简科技实际使用的是 light 还是 dark
    @Published private(set) var effectiveColorScheme: ColorScheme = .light

    private var appearanceObservation: NSKeyValueObservation?

    init() {
        resolveTheme()
        setupAppearanceObserver()
    }

    var selectedTheme: AppTheme {
        AppTheme(rawValue: selectedThemeRaw) ?? .minimal
    }

    var minimalColorScheme: MinimalColorScheme {
        MinimalColorScheme(rawValue: minimalColorSchemeRaw) ?? .system
    }

    func selectTheme(_ theme: AppTheme) {
        selectedThemeRaw = theme.rawValue
        applyDockIcon()
    }

    func setMinimalColorScheme(_ scheme: MinimalColorScheme) {
        minimalColorSchemeRaw = scheme.rawValue
    }

    private func resolveTheme() {
        systemColorScheme = NSApp.effectiveAppearance.isDarkMode ? .dark : .light
        let theme: Theme
        let effective: ColorScheme
        switch selectedTheme {
        case .anime:
            theme = .anime
            effective = systemColorScheme
        case .minimal:
            theme = Theme.minimal(scheme: minimalColorScheme, system: systemColorScheme)
            effective = (minimalColorScheme == .system)
                ? systemColorScheme
                : (minimalColorScheme == .dark ? .dark : .light)
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentTheme = theme
            effectiveColorScheme = effective
        }
    }

    private func setupAppearanceObserver() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.resolveTheme()
            }
        }
    }

    private func applyDockIcon() {
        NotificationCenter.default.post(
            name: .sweepThemeDidChange,
            object: currentTheme.dockIconName
        )
    }
}
