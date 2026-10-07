import SwiftUI
import AppKit
import CoreText

// MARK: - 颜色工具

extension Color {
    /// 0xRRGGBB 形式构造
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - 主题颜色

struct ThemeColors {
    let bg: Color
    let panel: Color
    let elev: Color
    let elev2: Color
    let border: Color
    let borderSoft: Color
    let text0: Color
    let text1: Color
    let text2: Color
    let accent: Color
    let accent2: Color
    let track: Color
    let ok: Color
    let okGlow: Color
    let warn: Color
    let glow: Color

    let ringRun: LinearGradient
    let ringDone: LinearGradient
    let primaryBtn: LinearGradient
    let brand: LinearGradient
}

// MARK: - 主题字体

struct ThemeFonts {
    /// 圆环中心「开始 / 完成」
    let dialCenter: (CGFloat) -> Font
    /// 百分比数字
    let percent: (CGFloat) -> Font
    /// 百分比单位 %
    let percentUnit: (CGFloat) -> Font
    /// 正文 / 按钮
    let body: (CGFloat, Font.Weight) -> Font
}

// MARK: - Mascot 配置

struct MascotConfig {
    let isVisible: Bool
    let idleSize: CGSize
    let cheerSize: CGSize
    let doneSize: CGSize
}

// MARK: - 圆环风格

struct DialStyle {
    let showBreatheHalo: Bool
    let showRotatingDashedHalo: Bool
    let showSparkleHead: Bool
    let haloColor: Color
    let haloLineWidth: CGFloat
    let haloOpacity: CGFloat
    let shadowColor: Color
}

enum BrandStyle {
    case anime
    case minimal
}

// MARK: - 主题

struct Theme {
    let colors: ThemeColors
    let fonts: ThemeFonts
    let mascot: MascotConfig
    let dial: DialStyle
    let brand: BrandStyle
    let backgroundImageName: String?
    let dockIconName: String
    let effectiveColorScheme: ColorScheme
}

extension Theme {
    static let anime: Theme = {
        let c1 = Color(hex: 0xFF9EC4)
        let c2 = Color(hex: 0xB48CF2)
        let ok = Color(hex: 0x58CFA4)

        return Theme(
            colors: ThemeColors(
                bg:        Color(hex: 0xFFFFFF),
                panel:     Color(hex: 0xFFF7FB),
                elev:      Color(hex: 0xFDEDF5),
                elev2:     Color(hex: 0xFBE3EF),
                border:    Color(hex: 0xFFDCEB),
                borderSoft:Color(hex: 0xFFE9F3),
                text0:     Color(hex: 0x4A3F55),
                text1:     Color(hex: 0x9B8AA9),
                text2:     Color(hex: 0xC3B4CF),
                accent:    c1,
                accent2:   c2,
                track:     Color(hex: 0xF9EDF5),
                ok:        ok,
                okGlow:    Color(hex: 0x58CFA4, alpha: 0.55),
                warn:      Color(hex: 0xFFB067),
                glow:      Color(hex: 0xFF9EC4, alpha: 0.40),
                ringRun:   LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing),
                ringDone:  LinearGradient(colors: [Color(hex: 0x8FE8C6), Color(hex: 0xFFB3D1)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing),
                primaryBtn:LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing),
                brand:     LinearGradient(colors: [Color(hex: 0xFFD3EA), Color(hex: 0xFF9ECB), Color(hex: 0xF2549B)],
                                          startPoint: .top, endPoint: .bottom)
            ),
            fonts: ThemeFonts(
                dialCenter: { SweepFont.round($0) },
                percent:    { SweepFont.round($0) },
                percentUnit:{ SweepFont.body($0, weight: .bold) },
                body:       { SweepFont.body($0, weight: $1) }
            ),
            mascot: MascotConfig(
                isVisible: true,
                idleSize: CGSize(width: 94, height: 132),
                cheerSize: CGSize(width: 104, height: 146),
                doneSize: CGSize(width: 94, height: 132)
            ),
            dial: DialStyle(
                showBreatheHalo: true,
                showRotatingDashedHalo: true,
                showSparkleHead: true,
                haloColor: c1,
                haloLineWidth: 2,
                haloOpacity: 0.38,
                shadowColor: Color(hex: 0xFF9EC4, alpha: 0.40)
            ),
            brand: .anime,
            backgroundImageName: "bg-necogirl",
            dockIconName: "Sweep",
            effectiveColorScheme: .light
        )
    }()

    static func minimal(scheme: MinimalColorScheme, system: ColorScheme) -> Theme {
        let isDark = scheme == .dark || (scheme == .system && system == .dark)
        return isDark ? .minimalDark : .minimalLight
    }

    static let minimalLight: Theme = {
        let accent = Color(hex: 0x2563EB)
        let accent2 = Color(hex: 0x0EA5E9)
        let ok = Color(hex: 0x10B981)

        return Theme(
            colors: ThemeColors(
                bg:        Color(hex: 0xF4F6F9),
                panel:     Color(hex: 0xFFFFFF, alpha: 0.92),
                elev:      Color(hex: 0xF1F5F9),
                elev2:     Color(hex: 0xE2E8F0),
                border:    Color(hex: 0xE2E8F0),
                borderSoft:Color(hex: 0xF1F5F9),
                text0:     Color(hex: 0x111827),
                text1:     Color(hex: 0x6B7280),
                text2:     Color(hex: 0x9CA3AF),
                accent:    accent,
                accent2:   accent2,
                track:     Color(hex: 0xE2E8F0),
                ok:        ok,
                okGlow:    Color(hex: 0x10B981, alpha: 0.35),
                warn:      Color(hex: 0xF59E0B),
                glow:      accent.opacity(0.25),
                ringRun:   LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing),
                ringDone:  LinearGradient(colors: [Color(hex: 0x34D399), ok], startPoint: .topLeading, endPoint: .bottomTrailing),
                primaryBtn:LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing),
                brand:     LinearGradient(colors: [accent, accent2], startPoint: .top, endPoint: .bottom)
            ),
            fonts: ThemeFonts(
                dialCenter: { size in .system(size: size, weight: .semibold) },
                percent:    { size in .system(size: size, weight: .bold).monospacedDigit() },
                percentUnit: { size in .system(size: size, weight: .semibold) },
                body:       { size, weight in .system(size: size, weight: weight) }
            ),
            mascot: MascotConfig(
                isVisible: false,
                idleSize: .zero,
                cheerSize: .zero,
                doneSize: .zero
            ),
            dial: DialStyle(
                showBreatheHalo: false,
                showRotatingDashedHalo: true,
                showSparkleHead: false,
                haloColor: accent2,
                haloLineWidth: 1.5,
                haloOpacity: 0.30,
                shadowColor: accent.opacity(0.25)
            ),
            brand: .minimal,
            backgroundImageName: nil,
            dockIconName: "SweepMinimalLight",
            effectiveColorScheme: .light
        )
    }()

    static let minimalDark: Theme = {
        let accent = Color(hex: 0x3B82F6)
        let accent2 = Color(hex: 0x38BDF8)
        let ok = Color(hex: 0x22C55E)

        return Theme(
            colors: ThemeColors(
                bg:        Color(hex: 0x0F172A),
                panel:     Color(hex: 0x1E293B, alpha: 0.92),
                elev:      Color(hex: 0x1E293B),
                elev2:     Color(hex: 0x334155),
                border:    Color(hex: 0x334155),
                borderSoft:Color(hex: 0x1E293B),
                text0:     Color(hex: 0xF9FAFB),
                text1:     Color(hex: 0x9CA3AF),
                text2:     Color(hex: 0x6B7280),
                accent:    accent,
                accent2:   accent2,
                track:     Color(hex: 0x334155),
                ok:        ok,
                okGlow:    Color(hex: 0x22C55E, alpha: 0.35),
                warn:      Color(hex: 0xFBBF24),
                glow:      accent.opacity(0.25),
                ringRun:   LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing),
                ringDone:  LinearGradient(colors: [Color(hex: 0x4ADE80), ok], startPoint: .topLeading, endPoint: .bottomTrailing),
                primaryBtn:LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing),
                brand:     LinearGradient(colors: [accent, accent2], startPoint: .top, endPoint: .bottom)
            ),
            fonts: ThemeFonts(
                dialCenter: { size in .system(size: size, weight: .semibold) },
                percent:    { size in .system(size: size, weight: .bold).monospacedDigit() },
                percentUnit: { size in .system(size: size, weight: .semibold) },
                body:       { size, weight in .system(size: size, weight: weight) }
            ),
            mascot: MascotConfig(
                isVisible: false,
                idleSize: .zero,
                cheerSize: .zero,
                doneSize: .zero
            ),
            dial: DialStyle(
                showBreatheHalo: false,
                showRotatingDashedHalo: true,
                showSparkleHead: false,
                haloColor: accent2,
                haloLineWidth: 1.5,
                haloOpacity: 0.30,
                shadowColor: accent.opacity(0.25)
            ),
            brand: .minimal,
            backgroundImageName: nil,
            dockIconName: "SweepMinimalDark",
            effectiveColorScheme: .dark
        )
    }()
}

// MARK: - 字体注册（猫系圆体）

enum SweepFont {
    /// 圆体（庆科黄油体子集，随包分发）
    ///
    /// 用 NSFont 直接构造 SwiftUI Font，避免 Font.custom 的 lazy NamedProvider
    /// 在字体注册时机稍晚时解析失败并回退到系统字体。
    static func round(_ size: CGFloat) -> Font {
        if let nsFont = NSFont(name: roundFamilyName, size: size) {
            return Font(nsFont)
        }
        return Font.custom(roundFamilyName, size: size)
    }

    /// 圆体 PostScript 名；加载失败时回退 SF Pro Rounded
    private(set) static var roundFamilyName: String = roundFallback

    private static let roundFallback = "SF Pro Rounded"
    private static let embeddedPostScriptName = "ZCOOLQingKeHuangYou-Regular"
    private static let embeddedFamilyName = "ZCOOL QingKe HuangYou"

    /// 应用启动时调用：注册随包圆体，并校验是否真的可用
    static func registerBundledFont() {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "SweepRound", withExtension: "ttf", subdirectory: "fonts"),
            Bundle.main.url(forResource: "SweepRound", withExtension: "ttf"),
            Bundle.main.resourceURL?.appendingPathComponent("fonts/SweepRound.ttf"),
            URL(fileURLWithPath: "Resources/fonts/SweepRound.ttf"),
            URL(fileURLWithPath: "app/Resources/fonts/SweepRound.ttf"),
            URL(fileURLWithPath: "../Resources/fonts/SweepRound.ttf"),
            URL(fileURLWithPath: "../app/Resources/fonts/SweepRound.ttf"),
        ]
        guard let url = candidates.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            NSLog("[Sweep] 找不到内置圆体")
            return
        }

        var error: Unmanaged<CFError>?
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if let e = error?.takeRetainedValue() {
            let code = CFErrorGetCode(e)
            if code != 105 {
                NSLog("[Sweep] 圆体注册失败: %@", String(describing: e))
            }
        }

        // 用 PostScript 名和 family 名双重探测
        if NSFont(name: embeddedPostScriptName, size: 12) != nil {
            roundFamilyName = embeddedPostScriptName
            NSLog("[Sweep] 圆体已加载: %@", embeddedPostScriptName)
        } else if NSFont(name: embeddedFamilyName, size: 12) != nil {
            roundFamilyName = embeddedFamilyName
            NSLog("[Sweep] 圆体已加载(family): %@", embeddedFamilyName)
        } else {
            NSLog("[Sweep] 圆体加载失败，回退到 %@", roundFallback)
        }
    }

    /// 强制预热字体，避免 SwiftUI 首次渲染 lazy 解析失败
    static func prewarmBundledFont() {
        guard let nsFont = NSFont(name: roundFamilyName, size: 31) else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: nsFont]
        _ = ("开始" as NSString).size(withAttributes: attrs)
        _ = ("完成" as NSString).size(withAttributes: attrs)
    }

    /// 正文：苹方（系统栈）
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
