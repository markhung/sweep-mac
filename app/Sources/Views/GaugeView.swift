import SwiftUI

/// 仪表区 —— 严格对齐设计稿 `.gauge`：
/// 读数（标签+数值同行）→ 环（r78 渐变，环心四态切换）→ 主按钮 cta → hint
struct GaugeView: View {
    @ObservedObject var appState: AppState
    var onStopRequest: () -> Void = {}
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
            RadialGradient(colors: [Color(hex: 0xFFB224, alpha: 0.05), .clear],
                           center: UnitPoint(x: 0.5, y: 0.4),
                           startRadius: 0, endRadius: 380)
                .overlay(
                    LinearGradient(colors: [Color(hex: 0xFFFFFF, alpha: 0.012), .clear],
                                   startPoint: .top, endPoint: .bottom)
                )
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
        }
    }

    // MARK: - 读数
    /// 设计稿口径：待机不报数（待清理 —）；清理中读「已释放」实时增长；
    /// 完成/停止读最终释放量。百分比只住在环心里。
    private var metricRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            Text(metricLabel)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.54)
                .textCase(.uppercase)
                .foregroundStyle(metricColor)
            if phase == .idle {
                Text("—")
                    .font(.system(size: 28, weight: .medium))
                    .tracking(-0.56)
                    .foregroundStyle(theme.colors.text2)
            } else {
                (Text(readout.value)
                    + Text(" \(readout.unit)").font(.system(size: 14))
                        .foregroundColor(theme.colors.text2))
                    .font(.system(size: 28, weight: .medium))
                    .monospacedDigit()
                    .tracking(-0.56)
                    .foregroundStyle(theme.colors.text0)
            }
        }
        .frame(height: 30)
    }
    private var readout: (value: String, unit: String) {
        switch phase {
        case .running: return SizeFormat.split(appState.reclaimedBytes)
        default:       return appState.resultSize
        }
    }
    private var metricLabel: String {
        switch phase {
        case .idle: return "待清理"
        case .running, .done, .failed: return "已释放"
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
        // 兼容旧引用；读数已由 readout 提供
        readout.value
    }

    // MARK: - 环
    private var ringArea: some View {
        ZStack {
            tickRing
            Circle()
                .stroke(trackColor, lineWidth: 5)
                .frame(width: ringDiameter, height: ringDiameter)
            if phase != .idle {
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(percent, 0), 1)))
                    .stroke(progGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))
                    .opacity(isStopped ? 0.78 : 1)   // 停止态压暗，传达「未完成」
                    .shadow(color: doneGlow ? theme.colors.ok.opacity(0.4) : .clear,
                            radius: 7)               // 完成是唯一的奖励时刻
            }
            if phase == .running {
                OrbitComet(diameter: ringDiameter, color: theme.colors.accent)
            }
            core
        }
        .frame(height: 176)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    /// 外部刻度环：72 根，每 6 根加长（设计稿进度环规格）
    private var tickRing: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let base = ringDiameter / 2 + 5
            for i in 0..<72 {
                let angle = CGFloat(i) / 72 * 2 * .pi
                let len: CGFloat = i % 6 == 0 ? 5 : 2.5
                let p1 = CGPoint(x: center.x + base * cos(angle),
                                 y: center.y + base * sin(angle))
                let p2 = CGPoint(x: center.x + (base + len) * cos(angle),
                                 y: center.y + (base + len) * sin(angle))
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                context.stroke(path, with: .color(theme.colors.text2.opacity(0.32)),
                               lineWidth: 1)
            }
        }
        .frame(width: ringDiameter + 30, height: ringDiameter + 30)
        .allowsHitTesting(false)
    }
    private var doneGlow: Bool { phase == .done && !isStopped }
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
                        .font(.system(size: 31, weight: .medium))
                        .tracking(-0.93)
                    Text("%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.colors.text2)
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
                .font(.system(size: 15, weight: .semibold))
                .tracking(0.15)
                .foregroundStyle(ctaLabelColor)
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
    /// 设计稿 .cta：琥珀底上用深棕字，中性态用次级文字色；
    /// 悬停揭示停止动作时转 danger-txt（#FF8079）
    private var ctaLabelColor: Color {
        switch phase {
        case .idle: return Color(hex: 0x1C1305)
        case .running: return hovered ? Color(hex: 0xFF8079) : theme.colors.text1
        case .done, .failed: return theme.colors.text0
        }
    }
    private var ctaLabel: String {
        switch phase {
        case .idle: return "开始清理"
        case .running: return hovered ? "停止清理" : "清理中…"
        case .done, .failed: return "完成"
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
        case .running: onStopRequest()          // 点击 → 确认层，不直接停
        case .done, .failed: appState.reset()   // 「完成」→ 回待机
        }
    }

    // MARK: - 提示
    private var hintRow: some View {
        Text(hintText)
            .font(.system(size: 11))
            .monospacedDigit()
            .tracking(0.22)
            .foregroundStyle(theme.colors.text2)
            .frame(minHeight: 14)
            .padding(.top, 12)
    }
    private var hintText: String {
        switch phase {
        case .idle: return "点击开始，全程在本机完成 · 可随时停止"
        case .running: return "正在清理 · 用时 \(appState.elapsedText) · 可随时停止"
        case .done: return isStopped ? "已停止 · 可随时再开始" : "清理完成"
        case .failed: return "清理失败"
        }
    }

    /// 清理中的环轨动效：一束彗尾沿环匀速旋转（linear，无回弹，仪器感）
    private struct OrbitComet: View {
        var diameter: CGFloat
        var color: Color

        // 裸 swiftc 载入不了宏，用显式 State(initialValue:) 写法
        private var _angle = State(initialValue: Double(0))
        private var angle: Double {
            get { _angle.wrappedValue }
            nonmutating set { _angle.wrappedValue = newValue }
        }

        /// 彗尾弧长（占整圈比例），渐变从透明尾到实色头
        private static let arcFraction: Double = 0.14

        var body: some View {
            let sweep = 360 * Self.arcFraction
            return Circle()
                .trim(from: 0, to: Self.arcFraction)
                .stroke(
                    AngularGradient(colors: [color.opacity(0), color],
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(sweep)),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(angle))
                .onAppear {
                    withAnimation(.linear(duration: 1.8)
                        .repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
