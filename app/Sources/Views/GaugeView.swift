import SwiftUI

/// 仪表区 —— 严格对齐设计稿 `.gauge`：
/// 读数（标签+数值同行）→ 环（r78 渐变，环心四态切换）→ 主按钮 cta → hint
struct GaugeView: View {
    @ObservedObject var appState: AppState
    private var theme: Theme { Theme.current }

    private var phase: Phase { appState.phase }
    private var isStopped: Bool { appState.report?.cancelled == true }
    private var percent: Double { appState.percent }

    private let ringDiameter: CGFloat = 156
    private var circumference: CGFloat { 2 * .pi * 78 }

    private var _hovered = State(initialValue: false)
    private var hovered: Bool {
        get { _hovered.wrappedValue }
        nonmutating set { _hovered.wrappedValue = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            metricRow
            ringArea
            cta
            hintRow
        }
        .padding(.top, 22)
        .padding(.bottom, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0xFFFFFF, alpha: 0.012), .clear],
                           startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
        }
    }

    // MARK: - 读数
    private var metricRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            Text(metricLabel)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.54)
                .textCase(.uppercase)
                .foregroundStyle(metricColor)
            Text(phase == .idle ? "—" : metricValue)
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .tracking(-0.56)
                .foregroundStyle(phase == .idle ? theme.colors.text3 : theme.colors.text0)
        }
        .frame(height: 30)
    }
    private var metricLabel: String {
        switch phase {
        case .idle: return "待扫描"
        case .running: return "正在清理"
        case .done: return isStopped ? "已强制停止" : "已清理干净"
        case .failed: return "清理失败"
        }
    }
    private var metricColor: Color {
        switch phase {
        case .idle: return theme.colors.text3
        case .running: return theme.colors.accent
        case .done: return isStopped ? theme.colors.accent : theme.colors.ok
        case .failed: return theme.colors.warn
        }
    }
    private var metricValue: String {
        switch phase {
        case .idle: return "—"
        case .running: return "\(Int(percent * 100))%"
        case .done:
            let gb = (appState.report?.reclaimedBytes ?? 0) / 1_000_000_000
            return String(format: "%.2f GB", gb)
        case .failed: return "—"
        }
    }

    // MARK: - 环
    private var ringArea: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: 8)
                .frame(width: ringDiameter, height: ringDiameter)
            if phase != .idle {
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(percent, 0), 1)))
                    .stroke(progGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))
            }
            core
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
    }
    private var trackColor: Color {
        phase == .idle ? theme.colors.borderSoft : theme.colors.border
    }
    private var progGradient: LinearGradient {
        let g: [Color]
        if phase == .done && !isStopped {
            g = [Color(hex: 0xA7F3C9), Color(hex: 0x3FBF80)]
        } else {
            g = [Color(hex: 0xFFD166), Color(hex: 0xFF7A18)]
        }
        return LinearGradient(colors: g, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - 环心四态
    private enum CoreState { case idle, cleaning, done, stopped }
    private var coreState: CoreState {
        if phase == .idle { return .idle }
        if phase == .running { return .cleaning }
        return isStopped ? .stopped : .done
    }
    private var core: some View {
        VStack(spacing: 3) {
            switch coreState {
            case .idle:
                Image(systemName: "sparkles")
                    .font(.system(size: 38))
                    .foregroundStyle(theme.colors.accent)
                    .opacity(0.85)
            case .cleaning:
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(Int(percent * 100))")
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .tracking(-0.5)
                    Text("%")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(theme.colors.text0)
                Text("正在清理").modifier(CoreCap()).foregroundStyle(theme.colors.text3)
            case .done:
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(theme.colors.ok)
                Text("已清理干净").modifier(CoreCap()).foregroundStyle(theme.colors.ok)
            case .stopped:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(theme.colors.warn)
                Text("已强制停止").modifier(CoreCap()).foregroundStyle(theme.colors.text2)
            }
        }
        .frame(width: 104)
    }
    private struct CoreCap: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(size: 10.5))
                .tracking(1.26)
                .textCase(.uppercase)
        }
    }

    // MARK: - 主按钮
    private var cta: some View {
        Button(action: ctaAction) {
            Text(ctaLabel)
                .frame(maxWidth: 320)
                .frame(height: 46)
                .background(ctaBackground)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(ctaBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
    }
    private var ctaLabel: String {
        switch phase {
        case .idle: return "开始清理"
        case .running: return hovered ? "停止" : "清理中"
        case .done: return "再清理"
        case .failed: return "再清理"
        }
    }
    private var ctaBackground: some View {
        switch phase {
        case .idle:
            return AnyView(LinearGradient(colors: [Color(hex: 0xFFC24D), Color(hex: 0xFF9A1F)],
                                         startPoint: .top, endPoint: .bottom))
        case .running:
            return AnyView((hovered
                            ? Color(hex: 0xFF5F57, alpha: 0.10)
                            : Color.clear))
        case .done:
            return AnyView(Color.clear)
        case .failed:
            return AnyView(Color.clear)
        }
    }
    private var ctaBorder: Color {
        switch phase {
        case .idle: return .clear
        case .running: return hovered ? Color(hex: 0xFF5F57, alpha: 0.42) : theme.colors.border
        case .done: return theme.colors.border
        case .failed: return theme.colors.border
        }
    }
    private func ctaAction() {
        switch phase {
        case .idle: appState.start()
        case .running: appState.cancel()
        case .done: appState.reset(); appState.start()
        case .failed: appState.reset()
        }
    }

    // MARK: - 提示
    private var hintRow: some View {
        Text(phase == .idle ? "点击开始，全程在本机完成 · 可随时停止" : " ")
            .font(.system(size: 11, design: .monospaced))
            .tracking(0.22)
            .foregroundStyle(theme.colors.text3)
            .frame(minHeight: 14)
            .padding(.top, 12)
    }
}
