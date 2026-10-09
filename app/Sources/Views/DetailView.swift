import SwiftUI

/// 明细区 —— 严格对齐设计稿 `.detail`：
/// dhead（标题+状态）→ 内容（idle:intro / running+查看明细:mole 日志流 / done:summary）→ dfoot（进度条）
struct DetailView: View {
    @ObservedObject var appState: AppState
    private var theme: Theme { Theme.current }

    private var phase: Phase { appState.phase }
    private var isStopped: Bool { appState.report?.cancelled == true }

    /// 完成后明细先留 480ms 让最后一行的对勾落地，再让位给结果摘要（设计稿状态机）
    /// 注意：裸 swiftc 编译载入不了 SwiftUI 宏，@State 一律用显式 State(initialValue:) 写法
    private var _pendingSummary = State(initialValue: false)
    private var pendingSummary: Bool {
        get { _pendingSummary.wrappedValue }
        nonmutating set { _pendingSummary.wrappedValue = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            dfoot
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.panel)
        .onChange(of: phase) { newPhase in
            guard newPhase == .done else {
                if !newPhase.isRunning { pendingSummary = false }
                return
            }
            pendingSummary = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                // 期间点了「完成」会直接重置，此时不该再换页
                if appState.phase == .done { pendingSummary = false }
            }
        }
    }

    // MARK: - 状态
    private var percent: Double { appState.percent }

    /// 页脚左侧的状态文案（设计稿 .plegend：四态各一）
    private var legendText: String {
        switch phase {
        case .idle: return "等待开始"
        case .running: return "正在释放空间"
        case .done: return isStopped ? "已强制停止" : "清理完成"
        case .failed: return "清理失败"
        }
    }

    // MARK: - 内容
    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            intro
        case .running:
            logStream
        case .done:
            if appState.showDetail {
                VStack(spacing: 0) {
                    sumMini
                    logStream
                }
            } else if pendingSummary {
                // 摘要未接管前，明细原地多停半秒
                logStream
            } else {
                summary
            }
        case .failed:
            summary
        }
    }

    // MARK: - 待扫描介绍
    private var intro: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Text("我会帮你扫干净这些地方")
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(theme.colors.text0)
                chips
                introNotes
                if !appState.permissionGranted { permBar }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
        }
    }
    private var chips: some View {
        FlowLayout(spacing: 9) {
            ForEach(appState.categories, id: \.self) { c in
                Text(c)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(theme.colors.text1)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(theme.colors.elev)
                            .overlay(Capsule().stroke(theme.colors.border, lineWidth: 1))
                    )
                    .overlay(alignment: .leading) {
                        Circle().fill(theme.colors.accent).opacity(0.66)
                            .frame(width: 4, height: 4)
                            .padding(.leading, 8)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    private var introNotes: some View {
        VStack(spacing: 5) {
            (Text("全部在").foregroundColor(theme.colors.text2)
                + Text("本机完成").fontWeight(.medium).foregroundColor(theme.colors.text1)
                + Text("，").foregroundColor(theme.colors.text2)
                + Text("不联网").fontWeight(.medium).foregroundColor(theme.colors.text1)
                + Text("。").foregroundColor(theme.colors.text2))
            (Text("只管用户级内容，").foregroundColor(theme.colors.text2)
                + Text("不会向你索要管理员密码").fontWeight(.medium).foregroundColor(theme.colors.text1)
                + Text("。").foregroundColor(theme.colors.text2))
        }
        .font(.system(size: 12))
        .lineSpacing(8)
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.colors.border).frame(width: 44, height: 1)
                .padding(.top, -7)
        }
    }
    private var permBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(theme.colors.accent).opacity(0.85)
            Text("未授予完全磁盘访问权限")
                .font(.system(size: 11.5))
                .foregroundStyle(theme.colors.text2)
            Button("去授权") { openFDA() }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(theme.colors.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(theme.colors.accent.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(theme.colors.accent.opacity(0.16), lineWidth: 1))
        )
    }

    // MARK: - mole 日志流（终端默认滚动样式：持续追加、自动跟随到底）
    private var logStream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(appState.entries) { entry in
                        logLine(entry).id(entry.id)
                    }
                    Color.clear.frame(height: 2).id("log-bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear { proxy.scrollTo("log-bottom", anchor: .bottom) }
            .onChange(of: appState.entries.count) { _ in
                // 等新行完成布局再贴底，模拟终端 tail -f 的跟随感
                DispatchQueue.main.async {
                    proxy.scrollTo("log-bottom", anchor: .bottom)
                }
            }
        }
    }

    /// 单行日志：沿用 mole 终端的标记符号与配色语义
    /// （➤ 模块头 / ✓ 清理 / ◎ 跳过 / ⊙ 手动 / 说明行弱化）
    @ViewBuilder
    private func logLine(_ e: LogEntry) -> some View {
        switch e.kind {
        case .section:
            HStack(spacing: 6) {
                Text("➤")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.colors.accent)
                Text(e.text)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.colors.text0)
                    .lineLimit(1)
            }
            .padding(.top, 9)
            .padding(.bottom, 3)

        case .item:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("✓")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.ok)
                Text(e.text)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.colors.text1)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let note = e.note {
                    Text(note)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.colors.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: 10)
                if let size = e.size {
                    Text(size)
                        .font(.system(size: 11.5))
                        .monospacedDigit()
                        .frame(width: 68, alignment: .trailing)   // 设计稿：大小列锁 68px
                        .foregroundStyle(theme.colors.text2)
                }
            }
            .padding(.vertical, 2.5)

        case .skip:
            glyphLine("◎", glyphColor: theme.colors.text2,
                      textColor: theme.colors.text2, e)

        case .manual:
            glyphLine("⊙", glyphColor: theme.colors.accent,
                      textColor: theme.colors.text1, e, noteColor: theme.colors.accent)

        case .empty:
            glyphLine("✓", glyphColor: theme.colors.text2,
                      textColor: theme.colors.text2, e)

        case .info:
            Text(e.text)
                .font(.system(size: 11.5))
                .foregroundStyle(theme.colors.text2)
                .padding(.vertical, 2.5)

        case .error:
            Text(e.text)
                .font(.system(size: 12))
                .foregroundStyle(theme.colors.warn)
                .padding(.vertical, 2.5)
        }
    }

    private func glyphLine(_ glyph: String, glyphColor: Color, textColor: Color,
                           _ e: LogEntry, noteColor: Color? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(glyph)
                .font(.system(size: 11))
                .foregroundStyle(glyphColor)
            Text(e.text)
                .font(.system(size: 12))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(.middle)
            if let note = e.note {
                Text(note)
                    .font(.system(size: 10.5))
                    .foregroundStyle(noteColor ?? theme.colors.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 10)
            if let size = e.size {
                Text(size)
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .frame(width: 68, alignment: .trailing)       // 设计稿：大小列锁 68px
                    .foregroundStyle(theme.colors.text2)
            }
        }
        .padding(.vertical, 2.5)
    }

    // MARK: - 结果摘要
    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline) {
                    Text(isStopped ? "已停止 · 本次释放" : "已释放")
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(isStopped ? theme.colors.accent : theme.colors.ok)
                    Spacer()
                    let parts = SizeFormat.split(appState.report?.reclaimedBytes ?? 0)
                    (Text(parts.value)
                        + Text(" " + parts.unit).font(.system(size: 14)).foregroundColor(theme.colors.text2))
                        .font(.system(size: 27, weight: .medium))
                        .monospacedDigit()
                        .tracking(-0.8)
                        .foregroundStyle(theme.colors.text0)
                }
                if let r = appState.report {
                    Text("扫描 \(r.categories) 类 · 移除 \(r.itemsCleaned) 项")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(theme.colors.text2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 6)
                }
                VStack(spacing: 0) {
                    sumRow("清理项目", value: "\(appState.report?.itemsCleaned ?? 0)")
                    sumRow("涉及分类", value: "\(appState.report?.categories ?? 0)")
                    sumRow("磁盘可用空间", value: String(format: "%.1f GB", Double(appState.report?.freeAfterBytes ?? 0) / 1_000_000_000))
                }
                .padding(.top, 14)
                if !appState.permissionGranted || isStopped {
                    sumNote
                }
                Button {
                    appState.showDetail = true
                } label: {
                    Text("查看明细")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.text0)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(theme.colors.border, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .background(
            LinearGradient(colors: [Color(hex: 0xFFB224, alpha: 0.05), .clear],
                           startPoint: .top, endPoint: .bottom)
                .background(theme.colors.panel)
        )
    }
    private func sumRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 11.5)).foregroundStyle(theme.colors.text2)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(theme.colors.text0)
        }
        .padding(.vertical, 7)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
        }
    }
    private var sumNote: some View {
        VStack(alignment: .leading, spacing: 3) {
            if isStopped {
                Text("这次扫到一半就停下了，已清掉的会保留。")
            }
            if !appState.permissionGranted {
                HStack(spacing: 4) {
                    Text("未授予权限，应用缓存与残留清理受限。")
                    Button("去授权") { openFDA() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(theme.colors.accent)
                }
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(theme.colors.text2)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(theme.colors.accent.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(theme.colors.accent.opacity(0.16), lineWidth: 1))
        )
        .padding(.top, 11)
    }
    private var sumMini: some View {
        HStack {
            let parts = SizeFormat.split(appState.report?.reclaimedBytes ?? 0)
            Text("已释放")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.colors.accent)
            Text("\(parts.value) \(parts.unit)")
                .font(.system(size: 11))
                .foregroundStyle(theme.colors.text1)
            Spacer()
            Button("收起明细") { appState.showDetail = false }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(theme.colors.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(theme.colors.accent.opacity(0.035))
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
        }
    }

    // MARK: - 页脚
    private var dfoot: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                Capsule().fill(theme.colors.border)
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(phase == .done && !isStopped
                                  ? LinearGradient(colors: [Color(hex: 0x8CEAB6), theme.colors.ok], startPoint: .leading, endPoint: .trailing)
                                  : LinearGradient(colors: [theme.colors.accent, theme.colors.accent2], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * max(0, min(1, percent)), height: 4)
                    }
            }
            .frame(height: 4)
            HStack {
                Text(legendText)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.colors.text2)
                Spacer()
                Text(phase == .idle ? "—" : "\(Int(percent * 100))%")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.text1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            LinearGradient(colors: [.clear, theme.colors.scrimBottom],
                           startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
        }
    }

    private func openFDA() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
        appState.refreshPermissionStatus()
    }
}

/// 流式布局（芯片换行），对齐设计稿 .chips（flex-wrap）
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = layout(proposal.width ?? 0, subviews)
        return CGSize(width: proposal.width ?? 0, height: rows.height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = layout(bounds.width, subviews)
        var y = bounds.minY
        for row in rows.lines {
            var x = bounds.minX
            for idx in row {
                let size = subviews[idx].sizeThatFits(.unspecified)
                subviews[idx].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += rows.lineHeight + spacing
        }
    }
    private func layout(_ width: CGFloat, _ subviews: Subviews) -> (lines: [[Int]], height: CGFloat, lineHeight: CGFloat) {
        var lines: [[Int]] = [[]]
        var x: CGFloat = 0
        var lineHeight: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let size = v.sizeThatFits(.unspecified)
            lineHeight = max(lineHeight, size.height)
            if x + size.width > width, !lines.last!.isEmpty {
                lines.append([]); x = 0
            }
            lines[lines.count - 1].append(i)
            x += size.width + spacing
        }
        return (lines, height: max(lineHeight, 1) * CGFloat(lines.count) + spacing * CGFloat(max(lines.count - 1, 0)), lineHeight: lineHeight)
    }
}
