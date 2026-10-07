import SwiftUI
import AppKit

@main
struct SweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()

    init() {
        // 尽早注册随包圆体，确保 SwiftUI 渲染前字体已可用
        SweepFont.registerBundledFont()
        SweepFont.prewarmBundledFont()
    }

    var body: some Scene {
        WindowGroup("Sweep") {
            MainView(appState: appState, themeManager: themeManager)
                .fixedSize()
                .onAppear { appState.bootstrapPermission() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // 这是单窗口工具，不需要「新建」
            CommandGroup(replacing: .newItem) {}

            CommandMenu("主题") {
                Picker("主题", selection: Binding(
                    get: { themeManager.selectedTheme },
                    set: { themeManager.selectTheme($0) }
                )) {
                    Text("猫系主题").tag(AppTheme.anime)
                    Text("极简科技").tag(AppTheme.minimal)
                }
                .pickerStyle(.inline)

                Menu("极简科技外观") {
                    Picker("外观", selection: Binding(
                        get: { themeManager.minimalColorScheme },
                        set: { themeManager.setMinimalColorScheme($0) }
                    )) {
                        Text("浅色").tag(MinimalColorScheme.light)
                        Text("深色").tag(MinimalColorScheme.dark)
                        Text("自动").tag(MinimalColorScheme.system)
                    }
                    .pickerStyle(.inline)
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 命令行自检：`Sweep --selftest` 以预览模式跑一遍引擎，
    /// 把解析结果打到 stdout 后退出。用来在真实 bundle 环境里
    /// 验证「资源定位 → 进程启动 → 流式解析」整条链路，不删任何东西。
    private var isSelfTest: Bool {
        CommandLine.arguments.contains("--selftest")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        SweepFont.registerBundledFont()
        SweepFont.prewarmBundledFont()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange(_:)),
            name: .sweepThemeDidChange,
            object: nil
        )

        // 启动时按已保存主题设置 Dock 图标
        let tm = ThemeManager()
        applyDockIcon(name: tm.currentTheme.dockIconName)

        if isSelfTest { runSelfTest() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func themeDidChange(_ notification: Notification) {
        if let name = notification.object as? String {
            applyDockIcon(name: name)
        }
    }

    private func applyDockIcon(name: String) {
        if let img = NSImage(named: name) {
            NSApp.applicationIconImage = img
        }
    }

    @MainActor
    private func runSelfTest() {
        setvbuf(stdout, nil, _IONBF, 0)   // 自检要实时看输出
        let state = AppState()
        guard state.engineReady else {
            print("✗ 找不到内置引擎")
            exit(1)
        }
        print("✓ 引擎就位")

        let engine = CleanEngine()
        var sawModule = 0, sawEntry = 0
        engine.start(dryRun: true) { event in
            switch event {
            case let .stream(inner):
                switch inner {
                case .moduleStarted:
                    sawModule += 1
                case let .entry(e):
                    sawEntry += 1
                    let size = e.size.map { " \($0)" } ?? ""
                    let note = e.note.map { " (\($0))" } ?? ""
                    print("  [\(e.kind == .item ? "项" : e.kind == .skip ? "跳" : e.kind == .empty ? "空" : "人")] \(e.text)\(size)\(note)")
                case let .diskInfo(text, _):
                    print("  [盘] \(text)")
                case let .freeSpaceAfter(bytes):
                    print("  [末] 可用 \(SizeFormat.human(bytes))")
                case let .info(text):
                    print("  [注] \(text)")
                }
            case let .finished(summary, code, cancelled):
                print("── 退出码 \(code) 取消=\(cancelled) "
                      + "模块=\(sawModule) 条目=\(sawEntry) "
                      + "释放=\(SizeFormat.human(summary.reclaimedBytes)) "
                      + "文件=\(summary.itemsCleaned) 分类=\(summary.categories)")
                DispatchQueue.main.async { exit(code == 0 ? 0 : 2) }
            }
        }
    }
}
