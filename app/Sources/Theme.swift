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

// MARK: - 主题

/// 应用目前只有猫系（anime）一套主题，所有视图直接使用 `Theme.anime`。
struct Theme {
    let colors: ThemeColors
    let fonts: ThemeFonts
    let mascot: MascotConfig
    let dial: DialStyle
    let backgroundImageName: String?
    /// 字标是否用猫系镂空描边（true=猫系粉；false=设计系统琥珀实心）
    let cutoutBrand: Bool
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
            backgroundImageName: "bg-necogirl",
            cutoutBrand: true
        )
    }()

    // MARK: - 设计系统主题（琥珀深色科技风，基于 Sweep 设计系统 v1.0）
    ///
    /// 该主题代码已就绪，但默认不启用、且前端不暴露任何切换入口（隐藏）。
    /// 后续如需启用，将 `Theme.selected` 改为 `.designSystem` 即可全量切换。
    static let designSystem: Theme = {
        let amberHi = Color(hex: 0xFFC24D)
        let amber    = Color(hex: 0xFFB224)
        let amberLo  = Color(hex: 0xFF7A18)
        let mint     = Color(hex: 0x68E0A4)

        return Theme(
            colors: ThemeColors(
                bg:         Color(hex: 0x0F0F12),
                panel:      Color(hex: 0x141418),
                elev:       Color(hex: 0x1B1B20),
                elev2:      Color(hex: 0x1B1B20),
                border:     Color(hex: 0x26262D),
                borderSoft: Color(hex: 0x1E1E24),
                text0:      Color(hex: 0xF5F4F1),
                text1:      Color(hex: 0xF5F4F1, alpha: 0.68),
                text2:      Color(hex: 0xF5F4F1, alpha: 0.50),
                accent:     amber,
                accent2:    amberLo,
                track:      Color(hex: 0x26262D),
                ok:         mint,
                okGlow:     Color(hex: 0x68E0A4, alpha: 0.55),
                warn:       amberHi,
                glow:       Color(hex: 0xFFB224, alpha: 0.40),
                ringRun:    LinearGradient(colors: [amberHi, Color(hex: 0xFF9A1F)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing),
                ringDone:   LinearGradient(colors: [mint, Color(hex: 0x9CF0C8)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing),
                primaryBtn: LinearGradient(colors: [amberHi, Color(hex: 0xFF9A1F)],
                                          startPoint: .top, endPoint: .bottom),
                brand:      LinearGradient(colors: [amberHi, Color(hex: 0xFF9A1F)],
                                          startPoint: .top, endPoint: .bottom)
            ),
            fonts: ThemeFonts(
                dialCenter:  { SweepFont.body($0, weight: .medium) },
                percent:     { SweepFont.body($0, weight: .medium) },
                percentUnit: { SweepFont.body($0, weight: .bold) },
                body:        { SweepFont.body($0, weight: $1) }
            ),
            mascot: MascotConfig(
                isVisible: false,
                idleSize: CGSize(width: 94, height: 132),
                cheerSize: CGSize(width: 104, height: 146),
                doneSize: CGSize(width: 94, height: 132)
            ),
            dial: DialStyle(
                showBreatheHalo: false,
                showRotatingDashedHalo: true,
                showSparkleHead: false,
                haloColor: amber,
                haloLineWidth: 2.5,
                haloOpacity: 0.30,
                shadowColor: Color(hex: 0xFFB224, alpha: 0.30)
            ),
            backgroundImageName: nil,
            cutoutBrand: false
        )
    }()

    // MARK: - 轻量主题选择（前端不暴露切换入口）

    /// 可用主题。注意：UI 层不提供任何切换控件，当前始终为猫系。
    enum AppTheme: String, CaseIterable {
        case anime
        case designSystem
    }

    /// 当前生效主题。默认猫系；设计系统主题已就绪但隐藏，不提供切换 UI。
    static var selected: AppTheme = .anime

    /// 所有视图统一通过这里取主题，未来启用设计系统只需改 `selected`。
    static var current: Theme {
        switch selected {
        case .anime:        return .anime
        case .designSystem: return .designSystem
        }
    }
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
