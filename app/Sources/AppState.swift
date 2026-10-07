import Foundation
import SwiftUI

/// 立绘姿态
enum Pose {
    case idle, cheer, done
}

/// 删除方式：直接删除（permanent）或移至废纸篓（trash）
enum DeleteMode: String, CaseIterable {
    case direct = "permanent"
    case trash = "trash"
    var label: String {
        switch self {
        case .direct: return "直接删除"
        case .trash:  return "移至废纸篓"
        }
    }
}

/// 界面状态机 + 进度模型。
///
/// 进度不是假的：模块边界来自引擎真实输出（`➤` 行），
/// 每个模块的权重取自阶段①在本机实测的耗时占比（和为 100）；
/// 模块内部用时间饱和曲线插值，避免长时间停在同一个数字上。
@MainActor
final class AppState: ObservableObject {

    // MARK: - 对界面暴露的状态

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var percent: Double = 0          // 0...1
    @Published private(set) var entries: [LogEntry] = []
    @Published private(set) var reports: [ModuleReport] = []
    @Published private(set) var reclaimedBytes: Int64 = 0
    @Published private(set) var bubbleText = "点击开始，全程在本机完成 · 可随时停止"
    @Published private(set) var pose: Pose = .idle
    @Published private(set) var diskSummary = "正在读取磁盘信息…"
    @Published private(set) var report: CleanReport?
    @Published private(set) var errorText: String?

    /// 「查看详情」是否展开
    @Published var showDetail = false

    // MARK: - 用户设置（持久化到 UserDefaults）

    // didSet 只在值真正变化时落盘/调系统服务：init 还原持久化值也会触发
    // didSet，若不判等，每次启动都会白写一遍 UserDefaults、重调一遍自启服务。
    @Published var deleteMode: DeleteMode = .direct {
        didSet {
            guard oldValue != deleteMode else { return }
            UserDefaults.standard.set(deleteMode.rawValue, forKey: "Sweep.deleteMode")
        }
    }
    @Published var launchAtLogin: Bool = false {
        didSet {
            guard oldValue != launchAtLogin else { return }
            UserDefaults.standard.set(launchAtLogin, forKey: "Sweep.launchAtLogin")
            LoginController.setLaunchAtLogin(launchAtLogin)
        }
    }
    // 「菜单栏常驻」不在这里持有 @Published：它由 AppDelegate 的裸
    // NSStatusItem 直接读持久化键 "Sweep.showInMenuBar"。之前的
    // MenuBarExtra(isInserted:) 场景会和 NSStatusItemScene 互相触发
    // 失效，主线程死循环卡死，已整体移除。

    /// 设置面板是否打开（与主界面互斥的视图切换，非持久）
    @Published var showSettings = false

    /// 清理范围承诺（设计稿 CATS，六类；与结果摘要的「涉及分类」同源口径）
    let categories: [String] = [
        "应用缓存", "开发者工具", "系统垃圾", "浏览器", "应用残留", "大文件"
    ]

    // MARK: - 首次启动的权限引导

    /// 引导覆盖层是否展示
    @Published var showOnboarding = false
    /// 最近一次完全磁盘访问权限检测结果（探测在后台线程执行）
    @Published private(set) var permissionStatus: PermissionStatus = .unknown

    /// 命令行自检标记：`--selftest` 时不做任何权限引导，保证无人值守跑完
    static let isSelfTest = CommandLine.arguments.contains("--selftest")

    // MARK: - 内部

    private let engine = CleanEngine()
    private var ticker: Timer?
    private var lastTick = Date()

    /// 展示用百分比（阻尼跟随 targetPercent）
    private var displayPercent: Double = 0
    private var targetPercent: Double = 0
    private var moduleStart = Date()
    private var runStart = Date()

    /// 模块权重（阶段①实测耗时占比，合计 100）
    private static let moduleWeights: [String: Double] = [
        "User essentials": 12,
        "App caches": 10,
        "Browsers": 5,
        "Cloud & Office": 3,
        "Developer tools": 38,
        "Apps & utilities": 6,
        "Virtualization": 3,
        "Application Support": 7,
        "App leftovers": 8,
        "Apple Silicon updates": 2,
        "Device backups & firmware": 2,
        "Time Machine": 2,
        "Large files": 2,
        "Project artifacts": 0,
    ]

    /// 模块实际顺序（Mole 的固定顺序）
    private static let moduleOrder: [String] = [
        "User essentials", "App caches", "Browsers", "Cloud & Office",
        "Developer tools", "Apps & utilities", "Virtualization",
        "Application Support", "App leftovers", "Apple Silicon updates",
        "Device backups & firmware", "Time Machine", "Large files",
        "Project artifacts",
    ]

    private var cumulativeBefore: [String: Double] = [:]
    private var currentModuleEN: String?
    private var diskBeforeBytes: Int64?
    private var runToken = 0

    init() {
        var running: Double = 0
        for name in Self.moduleOrder {
            cumulativeBefore[name] = running
            running += Self.moduleWeights[name] ?? 0
        }
        deleteMode = DeleteMode(rawValue: UserDefaults.standard.string(forKey: "Sweep.deleteMode") ?? "") ?? .direct
        launchAtLogin = UserDefaults.standard.bool(forKey: "Sweep.launchAtLogin")
    }

    // MARK: - 权限引导

    /// 是否已获得完全磁盘访问权限
    var permissionGranted: Bool { permissionStatus.isGranted }

    /// 未授权提示条是否显示：未授权 + 引导已看过 + 当前未在展示引导
    var showsPermissionBanner: Bool {
        !permissionGranted && FullDiskAccess.hasSeenGuide && !showOnboarding
    }

    /// 应用启动时调用一次：先探测权限，再决定是否自动弹出首次引导。
    func bootstrapPermission() {
        guard !Self.isSelfTest else { return }   // 自检模式不弹引导
        refreshPermissionStatus {
            if FullDiskAccess.needsGuide(given: self.permissionStatus) {
                self.showOnboarding = true
            }
        }
    }

    /// 后台重新探测完全磁盘访问权限，回主线程刷新。
    /// - Parameter completion: 探测完成并更新 `permissionStatus` 后，在主线程回调
    func refreshPermissionStatus(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let status = FullDiskAccess.detect()
            Task { @MainActor in
                guard let self else { return }
                self.permissionStatus = status
                completion?()
            }
        }
    }

    /// 回填检测结果（供离屏快照自检直接摆状态使用）
    func applyDetectedPermission(_ status: PermissionStatus) {
        permissionStatus = status
    }

    /// 手动重新进入引导（点击常驻提示条）
    func presentOnboarding() {
        showOnboarding = true
    }

    /// 关闭引导（跳过或走完），并记录「看过」——之后不再自动弹出
    func dismissOnboarding() {
        FullDiskAccess.markGuideSeen()
        showOnboarding = false
    }

    // MARK: - 离屏快照自检入口

    /// 仅供离屏快照自检：把界面摆进「运行中」的视觉状态。
    /// 真实运行时这些值由 start()/tick() 驱动，不需要外部设置。
    func enterRunningVisual(percent p: Double) {
        phase = .running
        pose = .cheer
        displayPercent = p
        targetPercent = p
        percent = p
        if let name = currentModuleEN {
            bubbleText = MoleText.quip(for: MoleText.section(name))
        }
    }

    // MARK: - 引擎可用性

    var engineReady: Bool { engine.scriptExists }

    // MARK: - 开始清理

    func start() {
        guard phase != .running else { return }
        guard engineReady else {
            errorText = "内置清理引擎缺失，无法运行"
            phase = .failed("内置清理引擎缺失")
            return
        }

        runToken &+= 1
        let token = runToken

        errorText = nil
        entries = []
        reports = []
        reclaimedBytes = 0
        report = nil
        showDetail = false
        displayPercent = 0
        targetPercent = 0
        percent = 0
        currentModuleEN = nil
        diskBeforeBytes = nil
        pose = .cheer
        bubbleText = "正在清理中…"
        phase = .running
        moduleStart = Date()
        runStart = Date()

        startTicker()

        engine.start(dryRun: false, deleteMode: deleteMode.rawValue) { [weak self] event in
            guard let self, self.runToken == token else { return }
            self.handle(event)
        }
    }

    /// 中途停止（Esc 或「停止」按钮）
    func cancel() {
        guard phase == .running else { return }
        engine.stop()
        bubbleText = "好，我收手啦～"
    }

    func reset() {
        guard phase != .running else { return }
        runToken &+= 1
        phase = .idle
        percent = 0
        displayPercent = 0
        targetPercent = 0
        entries = []
        reports = []
        reclaimedBytes = 0
        report = nil
        showDetail = false
        errorText = nil
        pose = .idle
        bubbleText = "点击开始，全程在本机完成 · 可随时停止"
        stopTicker()
    }

    // MARK: - 事件处理

    private func handle(_ event: CleanEngine.Event) {
        switch event {
        case let .stream(inner):   handleStream(inner)
        case let .finished(summary, code, cancelled):
            finish(summary: summary, code: code, cancelled: cancelled)
        }
    }

    /// 内部可见（非 private）：离屏快照自检会把真实引擎事件直接喂进来，
    /// 用来验证「解析 → 状态 → 布局」整条链路
    func handleStream(_ event: EngineEvent) {
        switch event {
        case let .diskInfo(text, bytes):
            diskSummary = text
            if let bytes { diskBeforeBytes = bytes }
            // mole 终端开场那行「⚙ … · 可用空间 …」，日志流里原样呈现
            entries.append(LogEntry(kind: .info, text: text))

        case let .moduleStarted(nameEN):
            currentModuleEN = nameEN
            moduleStart = Date()
            let cn = MoleText.section(nameEN)
            let start = (cumulativeBefore[nameEN] ?? min(targetPercent, 0.96))
            targetPercent = start
            // 模块刚开始时不让指针倒退
            displayPercent = max(displayPercent, start)
            bubbleText = MoleText.quip(for: cn)
            appendReportHeader(cn)
            // 模块标题进日志流（mole 的 ➤ 行），供「清理明细」滚动展示
            entries.append(LogEntry(kind: .section, text: cn))

        case let .entry(entry):
            entries.append(entry)
            appendToCurrentReport(entry)
            if entry.kind == .item, let size = entry.size {
                reclaimedBytes += SizeFormat.parseBytes(size)
            }

        case let .freeSpaceAfter(bytes):
            if diskBeforeBytes == nil { diskBeforeBytes = bytes }

        case let .info(text):
            entries.append(LogEntry(kind: .info, text: text))
        }
    }

    private func appendReportHeader(_ cn: String) {
        if reports.last?.items.isEmpty == true { return }
        reports.append(ModuleReport(name: cn))
    }

    private func appendToCurrentReport(_ entry: LogEntry) {
        if reports.isEmpty { reports.append(ModuleReport(name: "其他")) }
        reports[reports.count - 1].items.append(entry)
    }

    /// 同上，供离屏快照自检使用
    func finish(summary: EngineSummary, code: Int32, cancelled: Bool) {
        stopTicker()

        var result = CleanReport()
        result.cancelled = cancelled
        result.reclaimedBytes = summary.reclaimedBytes > 0
            ? summary.reclaimedBytes
            : reclaimedBytes
        result.itemsCleaned = summary.itemsCleaned > 0
            ? summary.itemsCleaned
            : entries.filter { $0.kind == .item }.count
        result.categories = summary.categories > 0
            ? summary.categories
            : max(reports.filter { !$0.items.isEmpty }.count, 1)
        result.freeBeforeBytes = diskBeforeBytes
        result.freeAfterBytes = summary.freeAfterBytes

        reclaimedBytes = result.reclaimedBytes
        report = result

        if cancelled {
            phase = .idle
            pose = .idle
            bubbleText = "停下来啦，扫过的地方都清干净了～"
            percent = 0
        } else if code != 0 {
            phase = .failed("清理引擎退出码 \(code)")
            pose = .idle
            bubbleText = "咦…好像出了点小状况"
            errorText = "清理过程提前结束（退出码 \(code)）"
        } else {
            phase = .done
            pose = .done
            bubbleText = "搞定！磁盘清爽啦～"
            animateToFull()
        }
    }

    // MARK: - 进度驱动

    private func startTicker() {
        stopTicker()
        lastTick = Date()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        guard dt > 0 else { return }

        if phase == .running {
            // 模块内部的推进目标：时间饱和曲线，最多推进到本模块带宽的 88%，
            // 剩下的留给「模块真正结束」这个真实事件
            let inModule = now.timeIntervalSince(moduleStart)
            let intra = min(1 - exp(-inModule / 6.5), 0.88)

            let start = targetPercent
            let end = nextBoundary(after: currentModuleEN)
            let target = start + (end - start) * intra

            // 阻尼跟随：帧率无关
            displayPercent += (target - displayPercent) * (1 - exp(-dt * 3.4))
            percent = min(displayPercent, 0.995)
        } else if phase == .done {
            displayPercent += (1 - displayPercent) * (1 - exp(-dt * 4.5))
            percent = min(displayPercent, 1)
            if percent > 0.999 { percent = 1 }
        }
    }

    /// 本模块结束时应到达的累计进度
    private func nextBoundary(after nameEN: String?) -> Double {
        guard let name = nameEN else { return 0.06 }
        let before = cumulativeBefore[name] ?? 0
        let weight = Self.moduleWeights[name] ?? 2
        return min((before + weight) / 100, 0.995)
    }

    private func animateToFull() {
        targetPercent = 1
        startTicker()   // ticker 在 finish 里被停掉了，重新起一个走完最后的动画
    }

    // MARK: - 展示辅助

    /// 当前版本号（来自 Info.plist）
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// 顶部/气泡下方的实时释放量
    var releasedText: String {
        reclaimedBytes > 0 ? "已释放 \(SizeFormat.human(reclaimedBytes))" : ""
    }

    /// 已清理的条目数（日志流里 ✓ 行的计数），供明细状态与停止确认使用
    var cleanedCount: Int { entries.filter { $0.kind == .item }.count }

    var elapsedText: String {
        let seconds = Int(Date().timeIntervalSince(runStart))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// 结果页文案
    var resultTitle: String { report?.cancelled == true ? "已强制停止" : "已清理干净" }

    var resultSize: (value: String, unit: String) {
        SizeFormat.split(report?.effectiveReclaimedBytes ?? 0)
    }
}
