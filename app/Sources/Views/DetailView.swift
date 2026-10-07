import SwiftUI

/// 明细区 —— 严格对齐设计稿 `.detail`：
/// dhead（标题+状态）→ 内容（idle:intro / running:list / done:summary 或 明细）→ dfoot（进度条）
struct DetailView: View {
    @ObservedObject var appState: AppState
    private var theme: Theme { Theme.current }

    private var phase: Phase { appState.phase }
    private var isStopped: Bool { appState.report?.cancelled == true }

    var body: some View {
        VStack(spacing: 0) {
            dhead
            content
            dfoot
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.panel)
    }

    // MARK: - 头部
    private var dhead: some View {
        HStack {
            Text("清理明细")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(theme.colors.text1)
            Spacer()
            Text(dstat)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.colors.text3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
        }
    }
    private var dstat: String {
        switch phase {
        case .idle: return "等待开始"
        case .running: return "清理中 \(Int(percent * 100))%"
        case .done: return isStopped ? "已强制停止" : "已清理干净"
        case .failed: return "清理失败"
        }
    }
    private var percent: Double { appState.percent }

    // MARK: - 内容
    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            intro
        case .running:
            list
        case .done:
            if appState.showDetail {
                VStack(spacing: 0) {
                    sumMini
                    list
                }
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
                    .foregroundStyle(theme.colors.text1)
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
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.colors.text2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
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
            Text("全部在**本机完成**，**不联网**。")
                .font(.system(size: 12))
                .foregroundStyle(theme.colors.text3)
            Text("只管用户级内容，**不会向你索要管理员密码**。")
                .font(.system(size: 12))
                .foregroundStyle(theme.colors.text3)
        }
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
                .foregroundStyle(theme.colors.text3)
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

    // MARK: - 明细列表
    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(appState.categories.enumerated()), id: \.element) { i, name in
                    row(name, index: i)
                    if i < appState.categories.count - 1 {
                        Divider().background(theme.colors.borderSoft)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
    private func row(_ name: String, index: Int) -> some View {
        let done = (phase == .done)
        let active = (phase == .running)
        return HStack(spacing: 11) {
            Circle()
                .fill(done ? theme.colors.ok.opacity(0.09) : theme.colors.accent.opacity(0.11))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: done ? "checkmark" : "cpu")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(done ? theme.colors.ok : theme.colors.accent)
                )
            Text(name)
                .font(.system(size: 12.5))
                .foregroundStyle(theme.colors.text1)
            Spacer()
            if active || done {
                GeometryReader { geo in
                    Capsule().fill(theme.colors.border)
                        .frame(height: 4)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(done
                                      ? LinearGradient(colors: [Color(hex: 0x8CEAB6), theme.colors.ok], startPoint: .leading, endPoint: .trailing)
                                      : LinearGradient(colors: [theme.colors.accent, theme.colors.accent2], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * (done ? 1 : max(0.04, percent)), height: 4)
                        }
                }
                .frame(width: 64, height: 4)
            }
            Text(done ? "完成" : (active ? "清理中" : ""))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(done ? theme.colors.ok : theme.colors.accent)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.vertical, 9)
    }

    // MARK: - 结果摘要
    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline) {
                    Text("已释放")
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(1.3)
                        .textCase(.uppercase)
                        .foregroundStyle(isStopped ? theme.colors.accent : theme.colors.ok)
                    Spacer()
                    let gb = (appState.report?.reclaimedBytes ?? 0) / 1_000_000_000
                    (Text(String(format: "%.2f", gb)) + Text(" GB").font(.system(size: 14)))
                        .font(.system(size: 27, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.colors.text0)
                }
                if let r = appState.report {
                    Text("扫描 \(r.categories) 类 · 移除 \(r.itemsCleaned) 项")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.colors.text3)
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
                        .foregroundStyle(theme.colors.text1)
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
        HStack {
            Text(title).font(.system(size: 11.5)).foregroundStyle(theme.colors.text3)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(theme.colors.text1)
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
        .foregroundStyle(theme.colors.text3)
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
            let gb = (appState.report?.reclaimedBytes ?? 0) / 1_000_000_000
            Text(String(format: "已释放 %.2f GB", gb))
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(theme.colors.text1)
            Spacer()
            Button("收起明细") { appState.showDetail = false }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
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
                Text(phase == .idle ? "等待开始" : dstat)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.colors.text3)
                Spacer()
                Text(phase == .idle ? "—" : "\(Int(percent * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.colors.text3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            LinearGradient(colors: [.clear, Color(hex: 0x000000, alpha: 0.22)],
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
