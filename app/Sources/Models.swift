import Foundation

// MARK: - 运行阶段

enum Phase: Equatable {
    case idle
    case running
    case done
    /// 进程异常退出
    case failed(String)

    var isRunning: Bool { self == .running }
}

// MARK: - 日志行

enum LogKind {
    /// 模块标题（➤）
    case section
    /// 已清理条目（✓）
    case item
    /// 跳过（◎）
    case skip
    /// 需人工确认（⊙）
    case manual
    /// 模块内无内容（✓ Nothing to clean）
    case empty
    /// 引擎的说明性输出
    case info
    /// 错误
    case error
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let kind: LogKind
    let text: String
    /// 该条目释放的体积（人类可读）
    var size: String?
    /// 补充说明（跳过原因等）
    var note: String?

    static func == (a: LogEntry, b: LogEntry) -> Bool { a.id == b.id }
}

// MARK: - 单个模块的清理明细（结果页「查看详情」用）

struct ModuleReport: Identifiable {
    let id = UUID()
    let name: String
    var items: [LogEntry] = []

    var cleanedCount: Int { items.filter { $0.kind == .item }.count }
}

// MARK: - 引擎事件

enum EngineEvent: Equatable {
    /// `⚙ Apple Silicon | Free space: 177.40GB`
    case diskInfo(text: String, freeBytes: Int64?)
    /// 一个新模块开始
    case moduleStarted(String)
    /// 模块内的条目
    case entry(LogEntry)
    /// 结束时磁盘可用空间
    case freeSpaceAfter(Int64)
    /// 未识别的说明性行
    case info(String)
}

/// 引擎退出后的汇总
struct EngineSummary: Equatable {
    var reclaimedBytes: Int64 = 0
    var itemsCleaned: Int = 0
    var categories: Int = 0
    var freeAfterBytes: Int64?
}

// MARK: - 清理结果

struct CleanReport {
    /// 引擎汇报的释放体积（字节）
    var reclaimedBytes: Int64 = 0
    /// 清理条目数（文件数，来自引擎汇总行）
    var itemsCleaned: Int = 0
    /// 分类数（来自引擎汇总行）
    var categories: Int = 0
    /// 开始时磁盘可用空间
    var freeBeforeBytes: Int64?
    /// 结束时磁盘可用空间
    var freeAfterBytes: Int64?
    /// 本次是否被用户中断
    var cancelled = false

    /// 磁盘可用空间的净增长；无数据时退回引擎汇报值
    var effectiveReclaimedBytes: Int64 {
        if let b = freeBeforeBytes, let a = freeAfterBytes, a > b { return a - b }
        return reclaimedBytes
    }
}

// MARK: - 体积格式化

enum SizeFormat {
    private static let units = ["B", "KB", "MB", "GB", "TB"]

    /// 二进制单位，小数位对齐 Mole 自己的显示习惯
    /// （它输出 `177.40GB` / `428.8MB` / `16KB`）
    static func human(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        var value = Double(bytes)
        var idx = 0
        while value >= 1024, idx < units.count - 1 {
            value /= 1024
            idx += 1
        }
        switch idx {
        case 0:  return "\(bytes) B"
        case 1:  return String(format: value >= 100 ? "%.0f KB" : "%.1f KB", value)
        case 2:  return String(format: "%.1f MB", value)
        default: return String(format: "%.2f %@", value, units[idx])
        }
    }

    /// 去掉单位的纯数字，用于「大数字 + 小单位」排版
    static func split(_ bytes: Int64) -> (value: String, unit: String) {
        let text = human(bytes)
        let parts = text.split(separator: " ", maxSplits: 1)
        guard parts.count == 2 else { return (text, "") }
        return (String(parts[0]), String(parts[1]))
    }

    /// 解析 "84.2MB" / "1 KB" / "293.1 MB" 之类的字符串为字节。
    /// 注意 Mole 原始输出里数字和单位之间**没有空格**，而本文件 format 出来是有的，
    /// 所以这里两种写法都必须吃下。
    static func parseBytes(_ raw: String) -> Int64 {
        let s = raw.trimmingCharacters(in: .whitespaces).uppercased()
        guard let re = try? NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)\s*(B|KB|MB|GB|TB)"#)
        else { return 0 }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let m = re.firstMatch(in: s, options: [], range: range),
              let valueRange = Range(m.range(at: 1), in: s),
              let unitRange = Range(m.range(at: 2), in: s),
              let value = Double(s[valueRange])
        else { return 0 }

        let mult: Double
        switch String(s[unitRange]) {
        case "B":  mult = 1
        case "KB": mult = 1024
        case "MB": mult = 1024 * 1024
        case "GB": mult = 1024 * 1024 * 1024
        case "TB": mult = 1024 * 1024 * 1024 * 1024
        default:   return 0
        }
        return Int64(value * mult)
    }
}
