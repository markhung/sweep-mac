import Foundation

/// GUI 应用从 Finder 启动时继承的是精简 PATH（/usr/bin:/bin:/usr/sbin:/sbin），
/// 而 Mole 需要能找到 npm / pip / brew / uv 等工具。这里向用户的登录 shell
/// 问一次完整 PATH 并缓存。
enum ShellPath {
    static let shared: String = resolve()

    private static let fallbacks = [
        ".local/bin", ".cargo/bin", ".bun/bin", "go/bin", ".pyenv/shims",
    ]

    private static func resolve() -> String {
        if let p = askLoginShell() { return p }

        let home = NSHomeDirectory()
        var parts = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin"]
        parts += fallbacks.map { "\(home)/\($0)" }
        parts += ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        return parts.joined(separator: ":")
    }

    /// 用交互式登录 shell 取 PATH（dotfiles 常把 PATH 写在 .zshrc 里）
    private static func askLoginShell() -> String? {
        for flags in ["-ilc", "-lc"] {
            guard let out = run("/bin/zsh", [flags, #"printf %s "$PATH""#]) else { continue }
            // 交互式 shell 可能有额外输出，取最后一行非空内容
            let candidate = out
                .split(separator: "\n", omittingEmptySubsequences: true)
                .last
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let c = candidate, c.contains("/usr/bin"), c.contains("/bin") {
                // 兜底目录追加在最后，避免覆盖用户自定义优先级
                let extra = fallbacks
                    .map { "\(NSHomeDirectory())/\($0)" }
                    .filter { !c.contains($0) }
                return ([c] + extra).joined(separator: ":")
            }
        }
        return nil
    }

    private static func run(_ launchPath: String, _ args: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launchPath)
        task.arguments = args
        task.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do { try task.run() } catch { return nil }

        // 最多等 5 秒，避免某个卡住的 dotfile 拖死启动流程
        let deadline = Date().addingTimeInterval(5)
        while task.isRunning, Date() < deadline {
            usleep(20_000)
        }
        if task.isRunning {
            task.terminate()
            usleep(100_000)
            if task.isRunning { kill(task.processIdentifier, SIGKILL) }
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
