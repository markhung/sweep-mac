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

/// 樱花主题（与已确认原型一致）
enum Palette {
    static let win        = Color(hex: 0xFFFFFF)
    static let panel      = Color(hex: 0xFFF7FB)
    static let elev       = Color(hex: 0xFDEDF5)
    static let elev2      = Color(hex: 0xFBE3EF)
    static let border     = Color(hex: 0xFFDCEB)
    static let borderSoft = Color(hex: 0xFFE9F3)
    static let text0      = Color(hex: 0x4A3F55)
    static let text1      = Color(hex: 0x9B8AA9)
    static let text2      = Color(hex: 0xC3B4CF)
    static let c1         = Color(hex: 0xFF9EC4)
    static let c2         = Color(hex: 0xB48CF2)
    static let track      = Color(hex: 0xF9EDF5)
    static let ok         = Color(hex: 0x58CFA4)
    static let okGlow     = Color(hex: 0x58CFA4, alpha: 0.55)
    static let warn       = Color(hex: 0xFFB067)
    static let glow       = Color(hex: 0xFF9EC4, alpha: 0.40)

    /// SWEEP 字标粉色渐变（与图标一致）
    static let brandTop   = Color(hex: 0xFFD3EA)
    static let brandMid   = Color(hex: 0xFF9ECB)
    static let brandDeep  = Color(hex: 0xF2549B)

    static let ringRun   = LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let ringDone  = LinearGradient(colors: [Color(hex: 0x8FE8C6), Color(hex: 0xFFB3D1)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
    static let brand     = LinearGradient(colors: [brandTop, brandMid, brandDeep],
                                          startPoint: .top, endPoint: .bottom)
    static let primaryBtn = LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - 字体

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
        guard let url = Bundle.main.url(forResource: "SweepRound", withExtension: "ttf", subdirectory: "fonts")
            ?? Bundle.main.url(forResource: "SweepRound", withExtension: "ttf")
        else {
            NSLog("[Sweep] 找不到内置圆体")
            return
        }

        var error: Unmanaged<CFError>?
        // 已注册过会返回 false，不视为失败
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if let e = error?.takeRetainedValue() {
            let code = CFErrorGetCode(e)
            if code != 105 {  // kCTFontManagerErrorAlreadyRegistered
                NSLog("[Sweep] 圆体注册失败: %@", String(describing: e))
            }
        }

        // 用 PostScript 名和 family 名双重探测，确认 CoreText 真的认到了这个字体
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

    /// 正文：苹方（系统栈）
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
