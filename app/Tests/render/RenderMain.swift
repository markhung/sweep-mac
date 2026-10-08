import SwiftUI
import AppKit

/// 离屏快照自检：把真实引擎输出喂进 AppState，再用 ImageRenderer 渲染成 PNG。
/// 不弹窗口、不需要录屏权限，用来核对「解析 → 状态 → 布局」整条链路。
///
/// 编译（注意要排除 SweepApp.swift，@main 会冲突）：
///     SRC=$(ls Sources/*.swift | grep -v SweepApp.swift)
///     swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos13.0 \
///            ${=SRC} Sources/Views/*.swift Tests/render/RenderMain.swift -o build/render_check
///     ./build/render_check /tmp/sweep-dryrun.txt build/snapshots
@main
struct RenderCheck {

    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let sourcePath = arguments.first ?? "/tmp/sweep-dryrun.txt"
        let outDir = arguments.count > 1 ? arguments[1] : "build/snapshots"

        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        _ = NSApplication.shared          // 先把 AppKit 起起来，ImageRenderer 才有得用
        SweepFont.registerBundledFont()

        // 【QA 修复：状态隔离】`hasSeenGuide` 是持久化默认值，上次运行（或别的
        // 二进制）留下的值会决定 01~05 号快照要不要画「未授权提示条」——
        // 之前就出现过 01-idle 与 14-main-banner 完全相同的假象。
        // 这里先记住原值并清成 false，让前段快照确定性地无提示条；
        // 跑完再按「原本是否存在」如实还原，不往用户 defaults 里留垃圾。
        let savedGuideSeen = FullDiskAccess.hasSeenGuide
        let guideKeyExisted =
            UserDefaults.standard.object(forKey: FullDiskAccess.guideSeenKey) != nil
        FullDiskAccess.hasSeenGuide = false

        let text = (try? String(contentsOfFile: sourcePath, encoding: .utf8)) ?? ""
        var parser = MoleStreamParser()
        let events = parser.feed(text) + parser.flush()
        print("解析到 \(events.count) 个事件，来源 \(sourcePath)")

        // ── 1. 待机态
        snapshot(MainView(appState: AppState(), updateService: UpdateService()), "01-idle", outDir: outDir)

        // ── 2. 运行中：喂真实事件，停在「开发者工具」模块之前
        let running = AppState()
        for event in events {
            if case let .moduleStarted(name) = event, name == "Developer tools" { break }
            running.handleStream(event)
        }
        running.enterRunningVisual(percent: 0.42)
        snapshot(MainView(appState: running, updateService: UpdateService()), "02-running", outDir: outDir)

        // ── 3. 完成态：喂完全部事件 + 汇总
        let done = AppState()
        for event in events { done.handleStream(event) }
        done.finish(summary: parser.summary, code: 0, cancelled: false)
        snapshot(MainView(appState: done, updateService: UpdateService()), "03-done", outDir: outDir)

        // ── 4. 详情态（按模块分组的日志）
        done.showDetail = true
        snapshot(MainView(appState: done, updateService: UpdateService()), "04-detail", outDir: outDir)

        // ── 5. 诊断：日志行在无滚动容器时能否渲染
        let plain = VStack(alignment: .leading, spacing: 4) {
            ForEach(running.entries) { e in
                Text(e.text)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.current.colors.text2)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(width: 380, height: 202, alignment: .topLeading)
        .background(Theme.current.colors.panel)
        snapshot(plain, "05-log-plain", outDir: outDir)

        // ── 6. 权限引导四屏（③ 用未授权态，④ 用已授权态）
        let onboardSteps: [Int] = [0, 1, 2, 3]
        let onboardNames = ["10-onboard-1", "11-onboard-2",
                            "12-onboard-3", "13-onboard-4"]
        for (i, s) in onboardSteps.enumerated() {
            let st = AppState()
            st.applyDetectedPermission(s == 3 ? .granted : .denied)
            st.showOnboarding = true
            snapshot(OnboardingView(appState: st),
                     onboardNames[i], outDir: outDir)
        }

        // ── 6b. 完成屏的「需要重启」分支（未授权但用户点过「完成设置」）
        let restartState = AppState()
        restartState.applyDetectedPermission(.denied)
        restartState.showOnboarding = true
        snapshot(OnboardingView(appState: restartState),
                 "15-onboard-4-restart", outDir: outDir)

        // ── 7. 未授权时的主界面常驻提示条（引导已看过、不再自动弹）
        FullDiskAccess.markGuideSeen()
        let bannerState = AppState()
        bannerState.applyDetectedPermission(.denied)
        bannerState.showOnboarding = false
        snapshot(MainView(appState: bannerState, updateService: UpdateService()), "14-main-banner", outDir: outDir)

        // ── 8. 设置视图（含未授权态的「去授权」行）
        let settingsState = AppState()
        settingsState.showSettings = true
        snapshot(SettingsView(appState: settingsState,
                              isPresented: .constant(true)),
                 "20-settings", outDir: outDir)

        // 还原引导标记（存在过 → 写回原值；原本没有 → 不留键）
        if guideKeyExisted {
            FullDiskAccess.hasSeenGuide = savedGuideSeen
        } else {
            UserDefaults.standard.removeObject(forKey: FullDiskAccess.guideSeenKey)
        }

        print("输出目录：\(outDir)")
    }

    /// ImageRenderer 渲染不出 ScrollView 的内容，所以用「真实窗口 + 位图」：
    /// 窗口摆在屏幕外，让 SwiftUI 正常完成布局（含滚动容器），再抓位图。
    @MainActor
    private static func snapshot(_ view: some View, _ name: String,
                                 outDir: String, scale: CGFloat = 2) {
        let w: CGFloat = 468, h: CGFloat = 740
        let hosting = NSHostingView(rootView: view.frame(width: w, height: h))
        hosting.frame = NSRect(x: 0, y: 0, width: w, height: h)

        let window = NSWindow(contentRect: hosting.frame,
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.setFrameOrigin(NSPoint(x: -3000, y: -3000))   // 屏幕外
        window.orderFront(nil)

        // 跑一会儿 runloop，让布局、滚动容器、onAppear 动画以及自定义字体
        //（通过 CTFontManagerRegisterFontsForURL 注册）都就位
        for _ in 0..<120 { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(w * scale), pixelsHigh: Int(h * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { print("✗ \(name) 位图创建失败"); return }
        rep.size = NSSize(width: w, height: h)
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [:]) else {
            print("✗ \(name) PNG 编码失败"); return
        }
        let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png")
        try? png.write(to: url)
        print("✓ \(name).png  \(rep.pixelsWide)×\(rep.pixelsHigh)")
        window.orderOut(nil)
    }
}
