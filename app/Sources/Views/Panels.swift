import SwiftUI

// MARK: - 待机提示

struct HintPanel: View {


    private let chips = ["应用缓存", "系统日志", "开发者工具", "浏览器", "应用残留", "大文件"]
    private var theme: Theme { Theme.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("我会帮你扫干净这些地方")
                .font(theme.fonts.body(11, .bold))
                .tracking(0.6)
                .foregroundStyle(theme.colors.text2)

            FlowChips(items: chips, theme: theme)

            VStack(alignment: .leading, spacing: 2) {
                Text("全部在本机完成，不联网。")
                Text("只管用户级内容，") + Text("不会向你要管理员密码").bold() + Text("。")
            }
            .font(theme.fonts.body(11, .medium))
            .foregroundStyle(theme.colors.text2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
}

/// 简单的换行 chip 布局
private struct FlowChips: View {
    let items: [String]
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(theme.fonts.body(11, .semibold))
                            .foregroundStyle(theme.colors.text1)
                            .padding(.vertical, 3.5)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule().fill(theme.colors.elev)
                                    .overlay(Capsule().stroke(theme.colors.border, lineWidth: 1.5))
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
    var grouped: [ModuleReport]?
    var scrollable = true


    private var theme: Theme { Theme.current }
    private var trailingPadding: CGFloat { theme.mascot.isVisible ? 102 : 16 }

    var body: some View {
        let rows = Group {
            if let grouped {
                ForEach(grouped) { report in
                    if !report.items.isEmpty {
                        LogRow(entry: LogEntry(kind: .section, text: report.name), theme: theme)
                        ForEach(report.items) { item in
                            LogRow(entry: item, theme: theme)
                        }
                    }
                }
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    LogRow(entry: entry, isFirst: idx == 0, theme: theme)
                        .id(entry.id)
                }
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
                        .padding(.trailing, trailingPadding)
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
                .padding(.trailing, trailingPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
        }
    }
}

struct LogRow: View {
    let entry: LogEntry
    var isFirst: Bool = false
    let theme: Theme

    var body: some View {
        HStack(spacing: 8) {
            Text(mark)
                .font(theme.fonts.body(11, .bold))
                .foregroundStyle(markColor)
                .frame(width: 14)
            Text(displayText)
                .font(theme.fonts.body(entry.kind == .section ? 11 : 12,
                                      entry.kind == .section ? .bold : .medium))
                .tracking(entry.kind == .section ? 0.5 : 0)
                .foregroundStyle(isDim ? theme.colors.text2 : theme.colors.text0)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            if let note = entry.note {
                Text(note)
                    .font(theme.fonts.body(11, .medium))
                    .foregroundStyle(theme.colors.text2)
                    .lineLimit(1)
            }
            if let size = entry.size {
                Text(size)
                    .font(theme.fonts.body(11, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.text1)
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
        case .section: return theme.colors.accent
        case .item:    return theme.colors.ok
        case .skip:    return theme.colors.warn
        case .manual, .empty, .info: return theme.colors.text2
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


    private var theme: Theme { Theme.current }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(theme.fonts.body(11, .bold))
                .tracking(1)
                .foregroundStyle(theme.colors.text2)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(size.value)
                    .font(theme.fonts.percent(40))
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.text0)
                Text(size.unit)
                    .font(theme.fonts.body(18, .bold))
                    .foregroundStyle(theme.colors.text2)
            }

            HStack(spacing: 26) {
                StatColumn(number: "\(report.itemsCleaned)", caption: "清理项", theme: theme)
                Rectangle().fill(theme.colors.border).frame(width: 2, height: 26)
                StatColumn(number: "\(report.categories)", caption: "分类", theme: theme)
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
                Text("→").foregroundStyle(theme.colors.text2)
                Text(SizeFormat.human(after))
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.ok)
                    .fontWeight(.heavy)
            }
            .font(theme.fonts.body(11.5, .semibold))
            .foregroundStyle(theme.colors.text1)
        } else {
            Color.clear.frame(height: 16)
        }
    }
}

private struct StatColumn: View {
    let number: String
    let caption: String
    let theme: Theme

    var body: some View {
        VStack(spacing: 2) {
            Text(number)
                .font(theme.fonts.percent(19))
                .monospacedDigit()
                .foregroundStyle(theme.colors.text0)
            Text(caption)
                .font(theme.fonts.body(10.5, .semibold))
                .tracking(0.5)
                .foregroundStyle(theme.colors.text2)
        }
    }
}
