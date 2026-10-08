import SwiftUI
import AppKit

@main
struct SweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var appState = AppState()
    @StateObject private var updateService = UpdateService()
    @Environment(\.openWindow) private var openWindow

    init() {
        // 尽早注册随包圆体，确保 SwiftUI 渲染前字体已可用
        SweepFont.registerBundledFont()
        SweepFont.prewarmBundledFont()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView(appState: appState, updateService: updateService)
                .fixedSize()
                .onAppear {
                    appState.bootstrapPermission()
                    // 启动静默检查更新（24h 节流；--selftest 不联网）
                    updateService.startupCheckIfNeeded()
                    // 把 openWindow 动作交给 AppDelegate，供状态项菜单唤起主窗口
                    delegate.openWindowAction = openWindow
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // 这是单窗口工具，不需要「新建」
            CommandGroup(replacing: .newItem) {}
        }
        // 注意：这里不放 MenuBarExtra 场景。它与 NSStatusItemScene 在刷新时
        // 互相触发失效（updateConfiguration ↔ makeMainMenu），在这个系统版本
        // 上会死循环把主线程整个卡死（hang 报告里 69s 无响应）。菜单栏图标
        // 改由 AppDelegate 用裸 NSStatusItem 管理，见 refreshStatusItem()。
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 主窗口唤起动作（由 WindowGroup 的 onAppear 注入）
    var openWindowAction: OpenWindowAction?

    /// 命令行自检：`Sweep --selftest` 以预览模式跑一遍引擎，
    /// 把解析结果打到 stdout 后退出。用来在真实 bundle 环境里
    /// 验证「资源定位 → 进程启动 → 流式解析」整条链路，不删任何东西。
    private var isSelfTest: Bool {
        CommandLine.arguments.contains("--selftest")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        SweepFont.registerBundledFont()
        SweepFont.prewarmBundledFont()

        // 启动时为 Dock 设置猫系图标
        applyDockIcon(name: "Sweep")

        refreshStatusItem()

        if isSelfTest { runSelfTest() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 常驻菜单栏开启时，关闭主窗口不退出应用（仍驻留菜单栏）
        !UserDefaults.standard.bool(forKey: "Sweep.showInMenuBar")
    }

    // MARK: - 菜单栏常驻

    /// 菜单栏图标用裸 NSStatusItem，不进 SwiftUI 场景图。
    /// 显示与否只由持久化键 "Sweep.showInMenuBar" 决定（默认隐藏）。
    private var statusItem: NSStatusItem?

    func refreshStatusItem() {
        let wantItem = UserDefaults.standard.bool(forKey: "Sweep.showInMenuBar")

        if !wantItem {
            statusItem?.isVisible = false
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkle",
                                     accessibilityDescription: "Sweep")
        let menu = NSMenu()
        menu.addItem(withTitle: "打开 Sweep",
                     action: #selector(openMainWindow), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let open = openWindowAction {
            open(id: "main")
        } else {
            NSApp.windows.first(where: { $0.canBecomeKey && !$0.isSheet })?
                .makeKeyAndOrderFront(nil)
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
