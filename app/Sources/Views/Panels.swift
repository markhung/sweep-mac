import SwiftUI

// MARK: - 待机提示

struct HintPanel: View {
    private let chips = ["应用缓存", "系统日志", "开发者工具", "浏览器", "应用残留", "大文件"]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("我会帮你扫干净这些地方")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Palette.text2)

            FlowChips(items: chips)

            VStack(alignment: .leading, spacing: 2) {
                Text("全部在本机完成，不联网。")
                Text("只管用户级内容，") + Text("不会向你要管理员密码").bold() + Text("。")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.text2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
}

/// 简单的换行 chip 布局
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        // 每个 chip 约 74pt 宽，一行放 4 个；用固定三行堆叠保证在小窗口里稳定
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.text1)
                            .padding(.vertical, 3.5)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule().fill(Palette.elev)
                                    .overlay(Capsule().stroke(Palette.border, lineWidth: 1.5))
                            )
                    }
                }
            }
        }
    }

    private var rows: [[String]] {
        stride(from: 0, to: items.count, by: 3).map {
            Array(items[$0..<min($0 + 3, items.count)])
        }
    }
}

// MARK: - 实时日志

struct LogPanel: View {
    let entries: [LogEntry]
    /// 是否显示模块明细（结果页的「查看详情」）
    var grouped: [ModuleReport]?
    /// 仅供离屏快照自检：ImageRenderer 渲染不出 ScrollView 的内容，
    /// 关掉滚动容器才能在快照里核对日志样式。真实界面恒为 true。
    var scrollable = true

    var body: some View {
        let rows = Group {
            if let grouped {
                ForEach(grouped) { report in
                    if !report.items.isEmpty {
                        LogRow(entry: LogEntry(kind: .section, text: report.name))
                        ForEach(report.items) { item in
                            LogRow(entry: item)
                        }
                    }
                }
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    LogRow(entry: entry, isFirst: idx == 0)
                        .id(entry.id)
                }
                // 滚动锚点
                Color.clear.frame(height: 1).id("bottom")
            }
        }

        if scrollable {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    rows
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                        .padding(.leading, 13)
                        .padding(.trailing, 102)   // 右侧给右下角的猫娘让位
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: entries.count) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        } else {
            rows
                .padding(.top, 10)
                .padding(.bottom, 14)
                .padding(.leading, 13)
                .padding(.trailing, 102)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
    }
}

struct LogRow: View {
    let entry: LogEntry
    var isFirst: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(mark)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(markColor)
                .frame(width: 14)
            Text(displayText)
                .font(.system(size: entry.kind == .section ? 11 : 12,
                              weight: entry.kind == .section ? .bold : .medium))
                .tracking(entry.kind == .section ? 0.5 : 0)
                .foregroundStyle(isDim ? Palette.text2 : Palette.text0)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            if let note = entry.note {
                Text(note)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.text2)
                    .lineLimit(1)
            }
            if let size = entry.size {
                Text(size)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.text1)
            }
        }
        .frame(height: entry.kind == .section ? 28 : 25)
        .padding(.top, entry.kind == .section && !isFirst ? 5 : 0)
    }

    private var isDim: Bool { entry.kind == .section || entry.kind == .empty }

    private var mark: String {
        switch entry.kind {
        case .section: return "➤"
        case .item:    return "✓"
        case .skip:    return "◎"
        case .manual:  return "⊙"
        case .empty:   return "✓"
        case .info:    return "·"
        case .error:   return "!"
        }
    }

    private var markColor: Color {
        switch entry.kind {
        case .section: return Palette.c1
        case .item:    return Palette.ok
        case .skip:    return Palette.warn
        case .manual, .empty, .info: return Palette.text2
        case .error:   return Color.red
        }
    }

    private var displayText: String {
        if let note = entry.note, entry.kind == .empty { return entry.text + "（\(note)）" }
        return entry.text
    }
}

// MARK: - 结果

struct ResultPanel: View {
    let report: CleanReport
    let title: String
    let size: (value: String, unit: String)

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(Palette.text2)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(size.value)
                    .font(.system(size: 40, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Palette.text0)
                Text(size.unit)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.text2)
            }

            HStack(spacing: 26) {
                StatColumn(number: "\(report.itemsCleaned)", caption: "清理项")
                Rectangle().fill(Palette.border).frame(width: 2, height: 26)
                StatColumn(number: "\(report.categories)", caption: "分类")
            }
            .padding(.top, 12)

            diskLine
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private var diskLine: some View {
        if let before = report.freeBeforeBytes, let after = report.freeAfterBytes {
            HStack(spacing: 6) {
                Text("磁盘可用")
                Text(SizeFormat.human(before)).monospacedDigit()
                Text("→").foregroundStyle(Palette.text2)
                Text(SizeFormat.human(after))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ok)
                    .fontWeight(.heavy)
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Palette.text1)
        } else {
            Color.clear.frame(height: 16)
        }
    }
}

private struct StatColumn: View {
    let number: String
    let caption: String

    var body: some View {
        VStack(spacing: 2) {
            Text(number)
                .font(.system(size: 19, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Palette.text0)
            Text(caption)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Palette.text2)
        }
    }
}
