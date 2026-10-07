import SwiftUI
import AppKit
import CoreText

/// ============================================================================
/// QA UI 级验证（Edward）—— 驱动真实 AppState，验证工程师没覆盖的组合行为。
///
///   SRC=$(ls Sources/*.swift | grep -v SweepApp.swift)
///   swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos13.0 \
///          ${=SRC} Sources/Views/*.swift Tests/qa_ui/main.swift -o build/qa_ui
///   ./build/qa_ui          （二进制必须放在 build/ 下，Resources 才找得到）
///
/// 覆盖：
///   A4        unknown 在 UI 层的表现（会不会误弹 / 会不会误显示已授权）
///   B7/B8/B9  首启标记持久化 + 跳过/完成都置位 + 「看过后提示条常驻、不再自动弹」
///   D15       引导覆盖层的遮挡（渲染位图级证明：底层是否被完全盖住）
///   声明6     圆体文案字符是否 100% 落在随包字体子集内
/// ============================================================================

var failures = 0
var checks = 0
func check(_ name: String, _ passed: Bool) {
    checks += 1
    print("\(passed ? "✓" : "✗") \(name)")
    if !passed { failures += 1 }
}

/// 渲染成 PNG（屏幕外窗口 + NSHostingView，同 RenderMain 的做法）
@MainActor
func render(_ view: some View, to path: String) {
    let w: CGFloat = 420, h: CGFloat = 600
    let hosting = NSHostingView(rootView: view.frame(width: w, height: h))
    hosting.frame = NSRect(x: 0, y: 0, width: w, height: h)
    let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                          backing: .buffered, defer: false)
    window.contentView = hosting
    window.setFrameOrigin(NSPoint(x: -3000, y: -3000))
    window.orderFront(nil)
    for _ in 0..<16 { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * 2), pixelsHigh: Int(h * 2),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: w, height: h)
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    window.orderOut(nil)
}

@MainActor
func diffCount(_ a: String, _ b: String) -> Int {
    guard let ia = NSImage(contentsOfFile: a), let ta = ia.tiffRepresentation,
          let ra = NSBitmapImageRep(data: ta),
          let ib = NSImage(contentsOfFile: b), let tb = ib.tiffRepresentation,
          let rb = NSBitmapImageRep(data: tb) else { return -1 }
    var n = 0
    for y in 0..<min(ra.pixelsHigh, rb.pixelsHigh) {
        for x in 0..<min(ra.pixelsWide, rb.pixelsWide) {
            let p = ra.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)
            let q = rb.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)
            let pr = Int((p?.redComponent ?? 0) * 255), pg = Int((p?.greenComponent ?? 0) * 255),
                pb = Int((p?.blueComponent ?? 0) * 255)
            let qr = Int((q?.redComponent ?? 0) * 255), qg = Int((q?.greenComponent ?? 0) * 255),
                qb = Int((q?.blueComponent ?? 0) * 255)
            if abs(pr-qr) > 8 || abs(pg-qg) > 8 || abs(pb-qb) > 8 { n += 1 }
        }
    }
    return n
}

@MainActor
@main
struct QAUI {
    static func main() {
        _ = NSApplication.shared
        SweepFont.registerBundledFont()
        let key = FullDiskAccess.guideSeenKey
        let tmp = NSTemporaryDirectory()

        func clean() {
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults.standard.synchronize()
        }

        // ─────────────────────────────────────────────────────────────────
        // 0. 先钉住真实环境的判定（后面矩阵的期望值都以此为锚）
        // ─────────────────────────────────────────────────────────────────
        let realStatus = FullDiskAccess.detect()
        check("锚点：本机真实检测 = denied（未授权环境）", realStatus == .denied)

        // ─────────────────────────────────────────────────────────────────
        // A4 + B7/B9：四种组合的 UI 谓词（不触发重新探测，避免覆盖注入状态）
        //   needsGuide(given:) 是 bootstrapPermission 的决策函数
        //   showsPermissionBanner 是提示条的显示条件
        // ─────────────────────────────────────────────────────────────────
        print("── UI 谓词矩阵（needsGuide / showsPermissionBanner）")
        for (seen, status, label) in [
            (false, PermissionStatus.denied,  "denied+没看过"),
            (false, PermissionStatus.unknown, "unknown+没看过"),
            (true,  PermissionStatus.denied,  "denied+看过"),
            (true,  PermissionStatus.unknown, "unknown+看过"),
            (true,  PermissionStatus.granted, "granted+看过"),
            (false, PermissionStatus.granted, "granted+没看过"),
        ] {
            clean()
            FullDiskAccess.hasSeenGuide = seen
            let st = AppState()
            st.applyDetectedPermission(status)
            let autoPop = FullDiskAccess.needsGuide(given: status)
            let banner = st.showsPermissionBanner
            let expectPop = !status.isGranted && !seen
            let expectBanner = !status.isGranted && seen
            check("[\(label)] 自动弹引导判定=\(autoPop)（期望 \(expectPop)）", autoPop == expectPop)
            check("[\(label)] 提示条=\(banner)（期望 \(expectBanner)）", banner == expectBanner)
        }

        // bootstrapPermission 的真实链路：探测是异步的，最终状态=真实探测值
        clean()
        let bt = AppState()
        bt.bootstrapPermission()
        for _ in 0..<20 { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        check("bootstrapPermission 真实链路：permissionStatus == 真实探测值(denied)",
              bt.permissionStatus == .denied)
        check("bootstrapPermission 真实链路（没看过）：自动弹引导",
              bt.showOnboarding == true)

        // ─────────────────────────────────────────────────────────────────
        // A4 专项：unknown 会不会误显示「已授权」
        // ─────────────────────────────────────────────────────────────────
        clean()
        let u = AppState()
        u.applyDetectedPermission(.unknown)
        check("A4：unknown 时 permissionGranted == false（不会误显示已授权）",
              u.permissionGranted == false)

        // ─────────────────────────────────────────────────────────────────
        // B8：跳过 / 完成 都走 dismissOnboarding → 置位标记
        // ─────────────────────────────────────────────────────────────────
        clean()
        let d = AppState()
        d.applyDetectedPermission(.denied)
        d.showOnboarding = true
        check("B8 前置：展示引导时 showOnboarding==true", d.showOnboarding)
        d.dismissOnboarding()   // 「跳过」「完成设置」「开始使用」的同一落点
        check("B8 dismissOnboarding 后 showOnboarding==false", d.showOnboarding == false)
        check("B8 dismissOnboarding 后 hasSeenGuide==true", FullDiskAccess.hasSeenGuide)
        UserDefaults.standard.synchronize()
        check("B8 defaults 里键值确实为 true",
              UserDefaults.standard.bool(forKey: key) == true)

        // ─────────────────────────────────────────────────────────────────
        // B9：看过 + 未授权 → 不自动弹，但提示条常驻可召回
        // ─────────────────────────────────────────────────────────────────
        clean()
        FullDiskAccess.markGuideSeen()
        let r = AppState()
        r.applyDetectedPermission(.denied)
        r.bootstrapPermission()
        for _ in 0..<20 { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        check("B9 看过+未授权：不自动弹引导", r.showOnboarding == false)
        check("B9 看过+未授权：提示条常驻显示", r.showsPermissionBanner == true)
        r.presentOnboarding()   // 点提示条召回
        check("B9 点提示条可重新拉起引导", r.showOnboarding == true)
        check("B9 引导展示期间提示条隐藏（不重叠）", r.showsPermissionBanner == false)

        // ─────────────────────────────────────────────────────────────────
        // D15：引导覆盖层的遮挡（渲染位图级证明）
        //   若 MainView(引导开启) 与纯 OnboardingView 逐像素一致，
        //   说明底层主界面（含圆环、按钮、右下角猫娘）被完全不透明地盖住，
        //   点击不可能穿透（SwiftUI 命中测试与绘制同序：最上层不透明视图优先）。
        // ─────────────────────────────────────────────────────────────────
        clean()
        FullDiskAccess.markGuideSeen()
        let ov = AppState()
        ov.applyDetectedPermission(.denied)
        ov.showOnboarding = true
        let tm = ThemeManager()
        render(MainView(appState: ov, themeManager: tm), to: tmp + "/qa-overlay-on.png")
        render(OnboardingView(appState: ov, themeManager: tm, initialStep: 0), to: tmp + "/qa-onboard-only.png")
        ov.showOnboarding = false
        render(MainView(appState: ov, themeManager: tm), to: tmp + "/qa-overlay-off.png")

        let d1 = diffCount(tmp + "/qa-overlay-on.png", tmp + "/qa-onboard-only.png")
        check("D15 引导开启时主界面被完全盖住（与纯引导渲染 0 差异，差异=\(d1)）", d1 == 0)
        let d2 = diffCount(tmp + "/qa-overlay-on.png", tmp + "/qa-overlay-off.png")
        check("D15 引导开/关画面确实不同（差异=\(d2)）", d2 > 1000)

        // ─────────────────────────────────────────────────────────────────
        // 声明6：圆体文案字符是否都在随包子集内（缺字会字体回退混排）
        // ─────────────────────────────────────────────────────────────────
        print("── 圆体字体子集覆盖")
        let ps = SweepFont.roundFamilyName
        check("随包圆体已注册（PostScript 名 ZCOOLQingKeHuangYou-Regular）",
              ps == "ZCOOLQingKeHuangYou-Regular")
        if let font = NSFont(name: ps, size: 12) {
            let ct = font as CTFont
            let roundTexts = [
                "打扫猫娘来啦～", "打扫看不见的角落", "动手开一下", "清扫完成", "重启一下",
                "开始吧", "开启吧", "打开系统设置", "开始使用", "重启 Sweep",
                "开始", "完成", "0123456789", "123",
            ]
            var missing: [Character] = []
            for text in roundTexts {
                for ch in text {
                    var glyphs = [CGGlyph](repeating: 0, count: 1)
                    let utf = Array(String(ch).utf16)
                    let ok = CTFontGetGlyphsForCharacters(ct, utf, &glyphs, utf.count)
                    if !ok || glyphs[0] == 0 { missing.append(ch) }
                }
            }
            if missing.isEmpty {
                check("圆体文案 \(roundTexts.joined().count) 个字符全部命中子集（无缺字）", true)
            } else {
                check("圆体缺字：\(missing)", false)
            }
        } else {
            check("找不到圆体字体，无法校验子集", false)
        }

        // 还原：不把测试用的标记留在用户 defaults
        clean()
        try? FileManager.default.removeItem(atPath: tmp + "/qa-overlay-on.png")
        try? FileManager.default.removeItem(atPath: tmp + "/qa-onboard-only.png")
        try? FileManager.default.removeItem(atPath: tmp + "/qa-overlay-off.png")
        print("")
        print(failures == 0 ? "✓ QA UI 测试全部通过（\(checks) 项）"
                            : "✗ QA UI 测试 \(failures)/\(checks) 项失败")
        exit(failures == 0 ? 0 : 1)
    }
}
