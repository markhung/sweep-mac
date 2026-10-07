import SwiftUI
import AppKit

@main
struct SweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    init() {
        // 尽早注册随包圆体，确保 SwiftUI 渲染前字体已可用
        SweepFont.registerBundledFont()
        SweepFont.prewarmBundledFont()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView(appState: appState)
                .fixedSize()
                .onAppear { appState.bootstrapPermission() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // 这是单窗口工具，不需要「新建」
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("Sweep", systemImage: "sparkle", isInserted: $appState.showInMenuBar) {
            Button("打开 Sweep") { openWindow(id: "main") }
            Divider()
            Button("退出") { NSApp.terminate(nil) }
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

        // 启动时为 Dock 设置猫系图标
        applyDockIcon(name: "Sweep")

        if isSelfTest { runSelfTest() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 常驻菜单栏开启时，关闭主窗口不退出应用（仍驻留菜单栏）
        !UserDefaults.standard.bool(forKey: "Sweep.showInMenuBar")
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
