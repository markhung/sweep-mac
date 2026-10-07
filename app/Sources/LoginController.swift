import Foundation

/// 开机自启控制：通过用户级 LaunchAgents plist 实现，
/// 不依赖 Helper / 废弃 API，裸 swiftc 亦可编译。
enum LoginController {
    private static var plistURL: URL {
        let id = Bundle.main.bundleIdentifier ?? "com.sweep.app"
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(id).plist")
    }

    /// 设置是否开机自启
    static func setLaunchAtLogin(_ enabled: Bool) {
        let url = plistURL
        if enabled {
            let exe = Bundle.main.bundleURL
                .appendingPathComponent("Contents/MacOS/Sweep")
            let dict: [String: Any] = [
                "Label": Bundle.main.bundleIdentifier ?? "com.sweep.app",
                "ProgramArguments": [exe.path],
                "RunAtLoad": true,
                "LimitLoadToSessionType": "Aqua",
            ]
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                      withIntermediateDirectories: true)
            try? (dict as NSDictionary).write(to: url)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
