import Foundation

/// 软件更新检测：对接 GitHub Releases（提醒 + 跳转下载，不做应用内自装）。
/// 只 import Foundation，便于脱离 UI 独立编译单测（Tests/update）。
///
/// 交互契约（设计文档 §09 检查更新）：
/// - 启动静默检查，24h 至多一次；失败不推进节流时间戳
/// - 手动检查（点版本号）无视节流，但同一时刻只允许一个在途请求
/// - 发现新版本后持久化 pending 版本号驱动琥珀点，直到某次检查
///   返回「不高于本地版本」才摘除——用户手动装了新 DMG 也会自愈
/// - 更新检测不属于清理状态机；静默失败无声，手动失败给可重试的内联提示
@MainActor
final class UpdateService: ObservableObject {

    // MARK: - 状态

    enum CheckState: Equatable {
        case idle
        case checking
        case available(ReleaseInfo)
        case upToDate
        /// 仅手动检查会进入；静默检查失败保持原状态不动
        case failed(String)
    }

    struct ReleaseInfo: Equatable {
        /// tag 去掉 "v" 前缀后的版本号，如 "1.2.0"
        let version: String
        let htmlURL: String
        /// 更新要点（≤3 条）
        let notes: [String]
    }

    @Published private(set) var state: CheckState = .idle
    /// 版本号入口的琥珀点：已报新版本且尚未被本地版本追上
    @Published private(set) var hasPendingUpdate = false

    // MARK: - 常量

    static let releasePageURL = URL(string: "https://github.com/markhung/sweep-mac/releases/latest")!
    static let throttleInterval: TimeInterval = 24 * 60 * 60

    /// 测试钩子：设 SWEEP_UPDATE_API_URL 可把检测指到本地 mock，
    /// 与 --selftest 同款思路——不设置即对真实 repo 检测
    private static var apiURL: URL {
        if let raw = ProcessInfo.processInfo.environment["SWEEP_UPDATE_API_URL"],
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "https://api.github.com/repos/markhung/sweep-mac/releases/latest")!
    }

    private static let isSelfTest = CommandLine.arguments.contains("--selftest")
    private static let lastCheckKey = "Sweep.updateLastCheckAt"
    private static let pendingVersionKey = "Sweep.updatePendingVersion"

    // MARK: - 在途请求

    private var dataTask: URLSessionDataTask?
    /// 递增令牌：回调回来时对不上号即视为过期，直接丢弃
    private var requestToken = 0
    private var inFlightIsManual = false

    // MARK: - 公开入口

    /// 启动静默检查：24h 节流；--selftest 不联网
    func startupCheckIfNeeded() {
        guard !Self.isSelfTest else { return }
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        guard Date().timeIntervalSince1970 - last >= Self.throttleInterval else { return }
        performCheck(manual: false)
    }

    /// 手动检查（点版本号 / 设置入口 / 浮层重试）：无视节流，去重
    func checkNow() {
        guard !Self.isSelfTest else { return }
        performCheck(manual: true)
    }

    /// 浮层关闭时调用：作废在途的手动回调（静默检查不受影响）
    func cancelInFlightManual() {
        guard inFlightIsManual else { return }
        requestToken &+= 1
        dataTask?.cancel()
        dataTask = nil
        inFlightIsManual = false
        if case .checking = state { state = .idle }
    }

    // MARK: - 请求与响应

    private func performCheck(manual: Bool) {
        // 去重：同一时刻只保留一次在途请求
        requestToken &+= 1
        dataTask?.cancel()
        inFlightIsManual = manual
        state = .checking

        var request = URLRequest(url: Self.apiURL, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Sweep/\(localVersion) (github.com/markhung/sweep-mac)",
                         forHTTPHeaderField: "User-Agent")

        let token = requestToken
        dataTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self, token == self.requestToken else { return }   // 过期回调
                self.dataTask = nil
                self.inFlightIsManual = false
                let wasManual = manual

                // 任何失败：静默路径不动状态，手动路径给可重试提示
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                guard error == nil, statusCode == 200,
                      let data, let release = try? JSONDecoder().decode(GitHubRelease.self, from: data)
                else {
                    if wasManual {
                        let message: String
                        if let urlError = error as? URLError {
                            message = urlError.code == .timedOut
                                ? "检查超时，请确认网络后重试"
                                : "检查失败，请确认网络后重试"
                        } else if let statusCode {
                            message = "检查失败 (\(statusCode))"
                        } else {
                            message = "无法解析更新信息"
                        }
                        self.state = .failed(message)
                    }
                    return
                }

                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
                self.absorb(release, manual: wasManual)
            }
        }
        dataTask?.resume()
    }

    /// 吸收一次成功的检测结果
    private func absorb(_ release: GitHubRelease, manual: Bool) {
        guard !release.draft, !release.prerelease,
              let remote = Self.parseVersion(release.tagName),
              let local = Self.parseVersion(localVersion),
              let comparison = Self.compareVersions(remote, local)
        else {
            // 远端信息不完整：不造假更新；手动路径如实报失败
            if manual { state = .failed("无法解析更新信息") }
            return
        }

        if comparison == .orderedDescending {
            let notes = Self.parseNotes(from: release.body ?? "")
            let versionText = remote.map(String.init).joined(separator: ".")
            state = .available(ReleaseInfo(version: versionText,
                                           htmlURL: release.htmlUrl,
                                           notes: notes))
            UserDefaults.standard.set(versionText, forKey: Self.pendingVersionKey)
        } else {
            state = .upToDate
            UserDefaults.standard.removeObject(forKey: Self.pendingVersionKey)
        }
        refreshPendingFlag()
    }

    // MARK: - 琥珀点

    private func refreshPendingFlag() {
        let pending = UserDefaults.standard.string(forKey: Self.pendingVersionKey)
        guard let pending,
              let pendingParts = Self.parseVersion(pending),
              let localParts = Self.parseVersion(localVersion),
              let comparison = Self.compareVersions(pendingParts, localParts)
        else {
            hasPendingUpdate = false
            return
        }
        hasPendingUpdate = (comparison == .orderedDescending)
    }

    // MARK: - 纯函数（单测覆盖）

    /// "v1.2.0" → [1,2,0]；逐段取前导数字，短数组按 0 补齐；任何一段非数字 → nil
    nonisolated static func parseVersion(_ raw: String) -> [Int]? {
        var tag = raw.trimmingCharacters(in: .whitespaces)
        if tag.hasPrefix("v") || tag.hasPrefix("V") {
            tag = String(tag.dropFirst())
        }
        guard !tag.isEmpty else { return nil }
        var parts: [Int] = []
        for piece in tag.split(separator: ".", omittingEmptySubsequences: false) {
            let digits = piece.prefix { $0.isNumber }
            guard let value = Int(digits), !digits.isEmpty else { return nil }
            parts.append(value)
        }
        return parts.isEmpty ? nil : parts
    }

    /// 等长补 0 后逐段比较；任一侧畸形 → nil（调用方按「无更新」处理）
    nonisolated static func compareVersions(_ a: String, _ b: String) -> ComparisonResult? {
        guard let pa = parseVersion(a), let pb = parseVersion(b) else { return nil }
        return compareVersions(pa, pb)
    }

    nonisolated static func compareVersions(_ a: [Int], _ b: [Int]) -> ComparisonResult? {
        let width = max(a.count, b.count)
        for i in 0..<width {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x < y { return .orderedAscending }
            if x > y { return .orderedDescending }
        }
        return .orderedSame
    }

    /// 从 release body 提取更新要点：取 "- " / "* " 开头的行，剥 markdown 强调，
    /// 每条超长截断；凑不满就返回空数组（调用方头部兜底，不留占位文案）
    nonisolated static func parseNotes(from body: String, max: Int = 3) -> [String] {
        var notes: [String] = []
        for line in body.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") else { continue }
            var note = String(trimmed.dropFirst(2))
            for mark in ["**", "*", "`"] {
                note = note.replacingOccurrences(of: mark, with: "")
            }
            note = note.trimmingCharacters(in: .whitespaces)
            guard !note.isEmpty else { continue }
            if note.count > 72 {
                note = String(note.prefix(72)) + "…"
            }
            notes.append(note)
            if notes.count >= max { break }
        }
        return notes
    }

    // MARK: - 本地版本

    private var localVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}

// MARK: - GitHub Releases API 模型

struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String
    let body: String?
    let draft: Bool
    let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body, draft, prerelease
    }
}
