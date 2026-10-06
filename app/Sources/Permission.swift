import Foundation
import AppKit
import Darwin

/// 完全磁盘访问权限（Full Disk Access, FDA）的检测结果。
///
/// - `granted`：所有*存在的*探测点都可读 → 已授权
/// - `denied` ：任一存在的探测点读取被拒（EPERM/EACCES）→ 未授权
/// - `unknown`：所有探测点都不存在，无法判定（降级情形，例如全新机器上
///              Mail/Messages 目录尚未生成）
enum PermissionStatus: Equatable {
    case granted
    case denied
    case unknown

    var isGranted: Bool { self == .granted }
    var isDenied: Bool { self == .denied }
}

/// 首次启动引导所需的权限逻辑：探测、跳转系统设置、重启自身、引导标记。
///
/// 全部为纯函数 / 静态方法，不依赖任何 UI —— 因此既能被 AppState 调用，
/// 也能被独立编译的回归测试（`Tests/permission/main.swift`）直接驱动。
///
/// ## 关于 ad-hoc 签名的副作用
/// 每次重新 `./build.sh`，二进制的 cdhash 都会变化，macOS 会把之前授予的
/// FDA 一并撤销。所以开发期反复构建后检测会重新变成「未授权」——这是
/// **预期行为**，不是 bug。
enum FullDiskAccess {

    // MARK: - 探测点

    /// 需要 FDA 才能读取的系统路径。授权前这些路径全部返回 EPERM；
    /// 授权后可读。注意：`~/Library/Caches/com.apple.helpd` 之类
    /// **不需要** FDA 即可读取，绝不能拿来当探测点（会误判为已授权）。
    static let defaultProbePaths: [String] = [
        "~/Library/Application Support/com.apple.TCC/TCC.db",
        "~/Library/Mail",
        "~/Library/Messages",
        "~/Library/Caches/com.apple.Safari",
        "~/Library/Safari",
        "~/Library/Group Containers/group.com.apple.notes",
    ]

    // MARK: - 检测

    /// 探测完全磁盘访问权限。
    ///
    /// - Parameter paths: 探测点列表，默认 `defaultProbePaths`。做成可注入参数
    ///   是为了让回归测试能构造「全部存在但被拒 / 全部不存在 / 全部可读」
    ///   三种场景。
    /// - Returns: 见 `PermissionStatus`。
    ///
    /// 判定规则（强信号优先）：
    /// 1. 任一存在的探测点读取被拒 → `.denied`
    /// 2. 否则若至少有一个探测点可读 → `.granted`
    /// 3. 否则（探测点全都不存在）→ `.unknown`
    ///
    /// 路径不存在（ENOENT）只跳过，既不算授权也不算未授权 ——
    /// 某些机器上 Mail / Messages 目录可能本就不存在。
    static func detect(paths: [String] = defaultProbePaths) -> PermissionStatus {
        var sawReadable = false
        var sawDenied = false

        for raw in paths {
            let path = (raw as NSString).expandingTildeInPath
            switch probe(path) {
            case .readable:               sawReadable = true
            case .denied:                 sawDenied = true
            case .absent, .inconclusive:  continue
            }
        }

        if sawDenied { return .denied }
        if sawReadable { return .granted }
        return .unknown
    }

    /// 单个探测点的结果
    private enum Probe {
        case readable       // 可读
        case denied         // 存在但被拒（EPERM/EACCES）
        case absent         // 不存在（ENOENT）
        case inconclusive   // 其它错误，无法判定
    }

    /// 用 `open(2)` 直接试探访问权限：FDA 被拒时内核直接返回 EPERM/EACCES，
    /// 不必去解析 Cocoa 包装过的 NSError。目录同样可以用 O_RDONLY 打开，
    /// 因此文件与目录走同一条路径。
    private static func probe(_ path: String) -> Probe {
        // 先确认存在性：open 的 ENOENT 要区分「本就不存在」与「竞态消失」，
        // 但两者都归为 absent，处理一致。
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
            return .absent
        }

        let fd = open(path, O_RDONLY | O_NONBLOCK)
        if fd >= 0 {
            close(fd)
            return .readable
        }
        switch errno {
        case EPERM, EACCES: return .denied
        case ENOENT:        return .absent
        default:            return .inconclusive
        }
    }

    // MARK: - 授权跳转

    /// 打开「系统设置 → 隐私与安全性 → 完全磁盘访问权限」。
    /// 主用深链新老系统都兼容；失败再试 macOS 15+ 的新版设置面板深链。
    /// - Returns: 是否成功把设置面板唤起（两个深链都失败则为 false，
    ///   调用方应提示用户手动打开）。
    @discardableResult
    static func openSystemSettings() -> Bool {
        let links = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
        ]
        for link in links {
            guard let url = URL(string: link) else { continue }
            if NSWorkspace.shared.open(url) { return true }
        }
        return false
    }

    // MARK: - 重启自身

    /// 授权后 FDA 不会即时生效，必须重启 App。
    /// 先 shell 起一个「延迟 1 秒再 open bundle」的进程，再终止当前实例 ——
    /// 顺序很关键，否则当前进程都没了才开始 open，中间会空一段。
    static func relaunchApp() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // 用双引号包住路径，避免路径里出现空格导致参数被拆开
        task.arguments = ["-c", "sleep 1; open \"\(bundlePath)\""]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            NSLog("[Sweep] 重启失败：%@", String(describing: error))
        }
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }

    // MARK: - 首次引导标记

    /// 「引导已看过」的 UserDefaults 键
    static let guideSeenKey = "sweep.permissionGuide.seen"

    /// 是否已经看过首启引导（看过即不再自动弹出）
    static var hasSeenGuide: Bool {
        get { UserDefaults.standard.bool(forKey: guideSeenKey) }
        set { UserDefaults.standard.set(newValue, forKey: guideSeenKey) }
    }

    /// 记录「引导已看过」
    static func markGuideSeen() {
        hasSeenGuide = true
    }

    /// 是否需要自动弹出首次引导：未授权 且 没看过。
    /// 做成接受 `status` 的纯函数，避免在渲染路径上同步探测磁盘。
    static func needsGuide(given status: PermissionStatus) -> Bool {
        !status.isGranted && !hasSeenGuide
    }
}
