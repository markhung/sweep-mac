import Foundation

/// Mole 输出的单行文法解析器。
///
/// 纯函数式：`feed(_:)` 吃进任意分块的文本，吐出结构化事件，
/// 不碰进程、不碰界面，因此可以脱离 GUI 直接跑回归测试。
///
/// 识别的文法（来自 `bin/clean.sh` 实测）：
/// ```
/// ➤ 模块名
///   ✓ 条目名 · 6 items, 84.2MB        ← 真实清理
///   → 条目名 · 6 items, 84.2MB dry    ← 预览
///   ◎ 条目名 · skipped (原因)
///   ⊙ 条目名 · manual review
///   ✓ Nothing to clean
/// ⚙ Apple Silicon | Free space: 177.40GB
/// Tracked cleanup: 1.2GB | Items cleaned: 18
/// Free space: 223.5GB (+4.5GB)
/// ```
struct MoleStreamParser {

    private var buffer = ""
    private(set) var summary = EngineSummary()

    mutating func reset() {
        buffer = ""
        summary = EngineSummary()
    }

    /// 喂入一段（可能不完整的）输出，返回其中已完整的行所产生的事件
    mutating func feed(_ text: String) -> [EngineEvent] {
        buffer += text
        var events: [EngineEvent] = []
        while let nl = buffer.firstIndex(of: "\n") {
            let line = String(buffer[buffer.startIndex..<nl])
            buffer.removeSubrange(buffer.startIndex...nl)
            if let e = parse(line: line) { events.append(e) }
        }
        return events
    }

    /// 冲刷缓冲区里最后那半行
    mutating func flush() -> [EngineEvent] {
        guard !buffer.isEmpty else { return [] }
        let rest = buffer
        buffer = ""
        return parse(line: rest).map { [$0] } ?? []
    }

    // MARK: - 逐行

    private static let ansi = try! NSRegularExpression(pattern: "\u{1B}\\[[0-9;]*[A-Za-z]")

    private mutating func parse(line raw: String) -> EngineEvent? {
        let line = Self.stripANSI(raw).replacingOccurrences(of: "\r", with: "")
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.allSatisfy({ $0 == "=" }) { return nil }        // 分隔线
        if trimmed.hasPrefix("↳") { return nil }                   // 白名单路径
        guard let first = trimmed.first else { return nil }

        if let event = parseMarked(first: first, trimmed: trimmed) { return event }
        if Self.isMarked(first) { return nil }   // 是标记行但被有意过滤掉了，别当成普通说明

        // 汇总：`Tracked cleanup: 1.2GB | Items cleaned: 18` / `Potential space: ...`
        if let m = Self.match(trimmed, #"^(?:Potential space|Tracked cleanup):\s*(.+)$"#) {
            let body = Self.clean(m[1])
            summary.reclaimedBytes = SizeFormat.parseBytes(body)
            summary.itemsCleaned = Self.intValue(prefix: "Items cleaned:", in: trimmed)
                ?? Self.intValue(prefix: "Items:", in: trimmed) ?? 0
            summary.categories = Self.intValue(prefix: "Categories:", in: trimmed) ?? 0
            return nil
        }
        // `Free space: 223.5GB (+4.5GB)`
        if trimmed.hasPrefix("Free space:") {
            let body = String(trimmed.dropFirst("Free space:".count))
            if let bytes = Self.freeSpaceBytes(in: body) {
                summary.freeAfterBytes = bytes
                return .freeSpaceAfter(bytes)
            }
            return nil
        }
        // 标题行与尾部指引：不值得进日志
        for noise in ["Cleanup complete", "Dry run complete", "Detailed file list",
                      "Use ", "Clean Your Mac", "Running in non-interactive mode",
                      "Dry Run Mode", "System was already clean",
                      "No additional space freed", "No significant reclaimable"] {
            if trimmed.hasPrefix(noise) { return nil }
        }
        return .info(trimmed)
    }

    /// 行首是否为已知的标记字符
    private static func isMarked(_ c: Character) -> Bool {
        "➤⚙⊙◎✓→".contains(c)
    }

    /// 带前缀标记的行
    private mutating func parseMarked(first: Character, trimmed: String) -> EngineEvent? {
        switch first {
        case "➤":
            let name = Self.clean(String(trimmed.dropFirst()))
            return name.isEmpty ? nil : .moduleStarted(name)

        case "⚙":
            return Self.diskEvent(from: Self.clean(String(trimmed.dropFirst())))

        case "⊙":
            let e = Self.parseStatus(Self.clean(String(trimmed.dropFirst())))
            return .entry(LogEntry(kind: .manual, text: e.text, size: e.size,
                                   note: e.note ?? "需手动确认"))

        case "◎":
            let body = Self.clean(String(trimmed.dropFirst()))
            // `◎ System caches need sudo, ...` 是预览模式的开场提示，不是清理条目
            if body.lowercased().contains("need sudo") { return nil }
            return .entry(Self.parseStatus(body))

        case "✓", "→":
            return Self.resultEvent(from: Self.clean(String(trimmed.dropFirst())))

        default:
            return nil
        }
    }

    /// `⚙ Apple Silicon | Free space: 177.40GB`
    private static func diskEvent(from body: String) -> EngineEvent {
        guard body.lowercased().contains("free space"),
              let bytes = freeSpaceBytes(in: body) else {
            return .info(body)
        }
        let chip = body.components(separatedBy: "|").first?
            .replacingOccurrences(of: "Free space:", with: "")
            .trimmingCharacters(in: .whitespaces) ?? ""
        let size = SizeFormat.human(bytes)
        return .diskInfo(text: chip.isEmpty ? "可用空间 \(size)" : "\(chip) · 可用空间 \(size)",
                         freeBytes: bytes)
    }

    /// `✓ 条目名 · 详情` / `✓ Nothing to clean` / `✓ Whitelist: ...`
    private static func resultEvent(from body: String) -> EngineEvent? {
        if body.contains("Whitelist:") || body.lowercased().hasPrefix("admin access")
            || body.lowercased().hasPrefix("protected items") {
            return nil
        }
        if body.lowercased().hasPrefix("nothing to clean") {
            return .entry(LogEntry(kind: .empty, text: MoleText.item("Nothing to clean")))
        }

        let (name, detail) = split(body)
        let lower = detail.lowercased()
        if lower.hasPrefix("skipped") { return .entry(parseStatus(body)) }
        if lower.contains("manual review") {
            return .entry(LogEntry(kind: .manual, text: MoleText.item(name), note: "需手动确认"))
        }

        var sizeText: String?
        if let m = match(detail, #"([0-9][0-9.,]*\s*(?:B|KB|MB|GB|TB))"#),
           SizeFormat.parseBytes(m[1]) > 0 {
            sizeText = m[1].replacingOccurrences(of: " ", with: "")
        }
        var note: String?
        if let m = match(detail, #"^(\d+)\s+items?"#) { note = "\(m[1]) 项" }
        return .entry(LogEntry(kind: .item, text: MoleText.item(name), size: sizeText, note: note))
    }

    /// `Dia Application Support cache · skipped (Dia running)`
    private static func parseStatus(_ body: String) -> LogEntry {
        let (name, detail) = split(body)
        var reason = detail
        if let m = match(detail, #"\((.*)\)"#) {
            reason = m[1]
        } else if detail.lowercased().hasPrefix("skipped") {
            // 只剥离开头的 "skipped"，不能搜任意位置——
            // `scan skipped · mo purge` 里的 skipped 是原因本身的一部分
            reason = String(detail.dropFirst("skipped".count)).trimmingCharacters(in: .whitespaces)
        }
        var note = MoleText.reason(reason)
        if note.isEmpty { note = "已跳过" }

        var sizeText: String?
        if let m = match(detail, #"([0-9][0-9.,]*\s*(?:B|KB|MB|GB|TB))"#),
           SizeFormat.parseBytes(m[1]) > 0 {
            sizeText = m[1].replacingOccurrences(of: " ", with: "")
        }
        return LogEntry(kind: .skip, text: MoleText.item(name), size: sizeText, note: note)
    }

    // MARK: - 小工具

    /// 按中点拆「名称 · 详情」，取第一个中点
    private static func split(_ body: String) -> (String, String) {
        if let r = body.range(of: " · ") {
            return (String(body[body.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces),
                    String(body[r.upperBound...]).trimmingCharacters(in: .whitespaces))
        }
        return (body.trimmingCharacters(in: .whitespaces), "")
    }

    private static func stripANSI(_ s: String) -> String {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return ansi.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
    }

    /// 去掉预览模式留下的 ` dry` 尾巴
    private static func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasSuffix(" dry") { t = String(t.dropLast(4)) }
        return t.trimmingCharacters(in: .whitespaces)
    }

    private static func match(_ s: String, _ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        guard let m = re.firstMatch(in: s, options: [], range: range) else { return nil }
        var out: [String] = []
        for i in 0..<m.numberOfRanges {
            if let r = Range(m.range(at: i), in: s) { out.append(String(s[r])) } else { out.append("") }
        }
        return out
    }

    private static func intValue(prefix: String, in line: String) -> Int? {
        guard let r = line.range(of: prefix, options: .caseInsensitive) else { return nil }
        let tail = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
        let digits = tail.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// 从 "Apple Silicon | Free space: 177.40GB" 或 "223.5GB (+4.5GB)" 取可用空间；
    /// 括号里是增量，必须排除
    private static func freeSpaceBytes(in text: String) -> Int64? {
        let after = text.range(of: "Free space:", options: .caseInsensitive)
        let scope = after.map { String(text[$0.upperBound...]) } ?? text
        let head = scope.components(separatedBy: "(").first ?? scope
        let bytes = SizeFormat.parseBytes(head)
        return bytes > 0 ? bytes : nil
    }
}
