import Foundation

/// 内嵌 Mole 清理引擎的进程封装。
///
/// 依赖三条已验证的事实：
/// 1. `bin/clean.sh` 可独立调用（自解析 SCRIPT_DIR，相对 `../lib` 加载）；
/// 2. stdin 不是 tty 时脚本走非交互分支：`adopt_sudo_session` 失败即
///    `SYSTEM_CLEAN=false`，只清用户级目录，**不会向用户索要密码**；
/// 3. 输出是稳定纯文本，文法见 `MoleStreamParser`。
final class CleanEngine {

    enum Event {
        case stream(EngineEvent)
        case finished(summary: EngineSummary, code: Int32, cancelled: Bool)
    }

    private let scriptURL: URL
    private var task: Process?
    /// 解析状态与缓冲只在这条串行队列上访问
    private let queue = DispatchQueue(label: "com.sweep.engine")
    private var parser = MoleStreamParser()
    private(set) var isCancelled = false

    /// 结束判定用：EOF 与进程退出是两个独立信号，都到齐才算真正结束
    private var sawEOF = false
    private var sawTerminate = false
    private var finalized = false

    init() {
        let base = Bundle.main.resourceURL ?? URL(fileURLWithPath: ".")
        scriptURL = base.appendingPathComponent("mole/bin/clean.sh")
    }

    var scriptExists: Bool { FileManager.default.isExecutableFile(atPath: scriptURL.path) }

    // MARK: - 启动

    func start(dryRun: Bool = false, deleteMode: String = "permanent", onEvent: @escaping (Event) -> Void) {
        stop()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path] + (dryRun ? ["--dry-run"] : [])

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = ShellPath.shared
        env["HOME"] = NSHomeDirectory()
        // 清掉可能来自父进程的痕迹，保证「真实清理」不会被误变成预览
        env.removeValue(forKey: "MOLE_DRY_RUN")
        env["MOLE_DELETE_MODE"] = deleteMode
        process.environment = env
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())

        // 关键：stdin 指向 /dev/null → 脚本判定为非交互 → 跳过 sudo 询问
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe   // 诊断信息一并进日志，顺序不乱

        let handle = pipe.fileHandleForReading
        task = process
        isCancelled = false
        queue.sync {
            parser.reset()
            sawEOF = false
            sawTerminate = false
            finalized = false
        }

        // 事件统一在主线程交付
        let deliver: (Event) -> Void = { event in
            DispatchQueue.main.async { onEvent(event) }
        }

        // 流式读取放独立线程：readabilityHandler 与阻塞读在「进程已退出但
        // 孙进程仍占着管道写端」时会互相卡死，这里用线程 + 两个结束信号兜底
        let reader = Thread { [weak self] in
            guard let self else { return }
            Thread.current.name = "Sweep.engine.read"
            while true {
                let data = handle.availableData
                if data.isEmpty {
                    self.queue.async {
                        self.sawEOF = true
                        self.tryFinalize(deliver: deliver)
                    }
                    return
                }
                self.queue.async { self.consume(data, deliver: deliver) }
            }
        }
        reader.stackSize = 1 << 20
        reader.start()

        process.terminationHandler = { [weak self] proc in
            guard let self else { return }
            let code = proc.terminationStatus
            self.queue.async {
                self.sawTerminate = true
                self.tryFinalize(deliver: deliver, exitCode: code)
            }
            // 兜底：万一孙进程一直占着写端，EOF 永远不来，
            // 1.2 秒后强制收尾（极端情况下可能丢掉最后几行日志，可接受）
            self.queue.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self else { return }
                self.sawEOF = true
                self.tryFinalize(deliver: deliver, exitCode: code, force: true)
            }
        }

        do {
            try process.run()
        } catch {
            let message = error.localizedDescription
            DispatchQueue.main.async {
                onEvent(.stream(.info("无法启动清理引擎：\(message)")))
                onEvent(.finished(summary: EngineSummary(), code: -1, cancelled: false))
            }
        }
    }

    // MARK: - 结束判定

    /// EOF 与进程退出都到齐才收尾；force 用于孙进程占住写端时的兜底
    private func tryFinalize(deliver: @escaping (Event) -> Void,
                             exitCode: Int32 = 0,
                             force: Bool = false) {
        guard !finalized else { return }
        guard sawEOF, sawTerminate else { return }
        finalized = true

        for event in parser.flush() { deliver(.stream(event)) }
        let summary = parser.summary
        let cancelled = isCancelled
        DispatchQueue.main.async {
            deliver(.finished(summary: summary, code: exitCode, cancelled: cancelled))
        }
    }

    // MARK: - 取消

    func stop() {
        guard let process = task else { return }
        task = nil
        guard process.isRunning else { return }
        isCancelled = true
        let pid = process.processIdentifier
        process.terminate()
        // 子进程（du/rm）可能仍持有句柄，2 秒后强杀兜底
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if process.isRunning { kill(pid, SIGKILL) }
        }
    }

    // MARK: - 读取

    private func consume(_ data: Data, deliver: @escaping (Event) -> Void) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        for event in parser.feed(text) { deliver(.stream(event)) }
    }
}
