import SwiftUI
import AppKit
import Combine

// MARK: - 主题枚举

enum AppTheme: String, CaseIterable, Identifiable {
    case anime   = "anime"    // 猫系主题
    case minimal = "minimal"  // 极简科技

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anime:   return "猫系主题"
        case .minimal: return "极简科技"
        }
    }

    static var defaultForCurrentUser: AppTheme {
        let guideSeen = UserDefaults.standard.object(forKey: FullDiskAccess.guideSeenKey) != nil
        return guideSeen ? .anime : .minimal
    }
}

enum MinimalColorScheme: String, CaseIterable, Identifiable {
    case light  = "light"
    case dark   = "dark"
    case system = "system"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light:  return "浅色"
        case .dark:   return "深色"
        case .system: return "自动"
        }
    }
}

extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

extension Notification.Name {
    static let sweepThemeDidChange = Notification.Name("com.sweep.themeDidChange")
}
