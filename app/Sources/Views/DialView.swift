import SwiftUI

// MARK: - 进度圆环 + 中心按钮

struct DialView: View {
    @ObservedObject var state: AppState

    var onTap: () -> Void
    var onPause: @MainActor () -> Void = {}

    private let size: CGFloat = 196
    private var clickable: Bool { state.phase == .idle || state.phase == .done }
    private var theme: Theme { Theme.current }
    private var _hovering = State(initialValue: false)
    private var hovering: Bool {
        get { _hovering.wrappedValue }
        nonmutating set { _hovering.wrappedValue = newValue }
    }

    var body: some View {
        ZStack {
            // 待机：呼吸光环
            if state.phase == .idle, theme.dial.showBreatheHalo {
                BreatheHalo(theme: theme).frame(width: size, height: size)
            }

            // 运行中：外圈旋转虚线
            if state.phase == .running, theme.dial.showRotatingDashedHalo {
                RotatingHalo(theme: theme).frame(width: size, height: size)
            }

            // 轨道
            Circle()
                .stroke(theme.colors.track, lineWidth: 9)
                .frame(width: 176, height: 176)

            // 进度（完成态换成功色渐变）
            RingArc(progress: state.percent)
                .stroke(style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .foregroundStyle(state.phase == .done ? theme.colors.ringDone : theme.colors.ringRun)
                .frame(width: 176, height: 176)

            // 进度头部的小星星
            if state.phase == .running, state.percent > 0.02, theme.dial.showSparkleHead {
                SparkleShape()
                    .fill(Color.white)
                    .frame(width: 13, height: 13)
                    .shadow(color: theme.colors.accent, radius: 2.5)
                    .offset(y: -88)
                    .rotationEffect(.degrees(360 * state.percent))
            }

            centerContent
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .onTapGesture { if clickable { onTap() } }
        .overlay {
            // 可点击时才给光晕
            if clickable {
                Circle()
                    .stroke(Color.clear, lineWidth: 0)
                    .frame(width: size, height: size)
                    .shadow(color: theme.dial.shadowColor, radius: 12)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: state.phase)
        .help(helpText)
        .onHover { inside in
            withAnimation(.easeInOut(duration: 0.18)) { hovering = inside }
        }
    }

    private var helpText: String {
        switch state.phase {
        case .idle:  return "开始清理"
        case .done:  return "再清一次"
        case .running: return "正在清理"
        case .failed: return "清理未完成"
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        switch state.phase {
        case .idle, .failed:
            RoundLabel(text: "开始", theme: theme)
                .transition(.scale.combined(with: .opacity))

        case .running:
            ZStack {
                PercentLabel(percent: state.percent, theme: theme)
                    .opacity(hovering ? 0 : 1)
                    .animation(.easeInOut(duration: 0.18), value: hovering)
                if hovering {
                    pauseButton
                        .transition(.scale.combined(with: .opacity))
                }
            }

        case .done:
            RoundLabel(text: "完成", theme: theme)
                .transition(.scale.combined(with: .opacity))
        }
    }

    /// 运行中 hover 出现的暂停按钮：点击立即强制退出清理
    private var pauseButton: some View {
        Button {
            onPause()
        } label: {
            Image(systemName: "pause.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(theme.colors.primaryBtn)
                        .shadow(color: theme.colors.accent.opacity(0.45), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
    }
}

/// 圆环中心的圆体大字（开始 / 完成）
private struct RoundLabel: View {
    let text: String
    let theme: Theme

    var body: some View {
        Text(text)
            .font(theme.fonts.dialCenter(31))
            .tracking(9)
            .foregroundStyle(theme.colors.text0)
            .fixedSize()
            .offset(x: 4.5)
            .shadow(color: theme.dial.shadowColor, radius: 8)
    }
}

/// 中心百分比
private struct PercentLabel: View {
    let percent: Double
    let theme: Theme

    var body: some View {
        let shown = Int((percent * 100).rounded(.down))
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(shown)")
                .font(theme.fonts.percent(34))
                .foregroundStyle(theme.colors.text0)
            Text("%")
                .font(theme.fonts.percentUnit(16))
                .foregroundStyle(theme.colors.text2)
        }
        .monospacedDigit()
        .fixedSize()
    }
}

/// 待机呼吸：外圈缓慢放大淡出
private struct BreatheHalo: View {
    let theme: Theme
    private var _animate = State(initialValue: false)
    private var animate: Bool {
        get { _animate.wrappedValue }
        nonmutating set { _animate.wrappedValue = newValue }
    }

    var body: some View {
        Circle()
            .stroke(theme.colors.accent, lineWidth: theme.dial.haloLineWidth)
            .frame(width: 186, height: 186)
            .scaleEffect(animate ? 1.06 : 0.94)
            .opacity(animate ? 0 : theme.dial.haloOpacity)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)
            .onAppear { animate = true }
    }
}

/// 运行中：虚线光环旋转
private struct RotatingHalo: View {
    let theme: Theme
    private var _spin = State(initialValue: false)
    private var spin: Bool {
        get { _spin.wrappedValue }
        nonmutating set { _spin.wrappedValue = newValue }
    }

    var body: some View {
        Circle()
            .stroke(theme.colors.accent2, style: StrokeStyle(lineWidth: 2.5, lineCap: .round,
                                                             dash: [3, 16]))
            .frame(width: 192, height: 192)
            .opacity(theme.dial.haloOpacity)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 7).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
    }
}

// MARK: - 右下角 mascot

struct MascotView: View {
    let pose: Pose


    private var theme: Theme { Theme.current }

    /// 静态缓存：MainView 运行期间每秒刷新多次，
    /// 不能每次 body 都去磁盘解码 PNG
    private static let images: [Pose: NSImage] = {
        var map: [Pose: NSImage] = [:]
        for (pose, name) in [Pose.idle: "mascot-idle", .cheer: "mascot-cheer", .done: "mascot-done"] {
            if let img = Resources.image(name) { map[pose] = img }
        }
        return map
    }()

    private var _floaty = State(initialValue: false)
    private var floaty: Bool {
        get { _floaty.wrappedValue }
        nonmutating set { _floaty.wrappedValue = newValue }
    }
    private var _jump = State(initialValue: false)
    private var jump: Bool {
        get { _jump.wrappedValue }
        nonmutating set { _jump.wrappedValue = newValue }
    }

    private var size: CGSize {
        switch pose {
        case .cheer: return theme.mascot.cheerSize
        default:     return theme.mascot.idleSize
        }
    }

    var body: some View {
        Group {
            if let img = Self.images[pose] {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .shadow(color: Color(hex: 0x000000, alpha: 0.22), radius: 5, x: 0, y: 5)
                    .offset(y: offsetY)
                    .rotationEffect(.degrees(rotation))
                    .animation(animation, value: floaty)
                    .animation(animation, value: jump)
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            floaty = true
            jump = true
        }
    }

    private var animation: Animation {
        switch pose {
        case .idle:  return .easeInOut(duration: 1.7).repeatForever(autoreverses: true)
        case .cheer: return .easeInOut(duration: 0.32).repeatForever(autoreverses: true)
        case .done:  return .easeInOut(duration: 0.4)
        }
    }

    private var offsetY: CGFloat {
        switch pose {
        case .idle:  return floaty ? -6 : 0
        case .cheer: return jump ? -10 : 0
        case .done:  return jump ? -9 : 0
        }
    }

    private var rotation: Double {
        switch pose {
        case .cheer: return jump ? 3.5 : -3.5
        default:     return 0
        }
    }
}

// MARK: - 对话气泡

struct BubbleView: View {
    let text: String


    private var theme: Theme { Theme.current }

    var body: some View {
        Text(text)
            .font(theme.fonts.body(12.5, .semibold))
            .foregroundStyle(theme.colors.text0)
            .lineLimit(1)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(theme.colors.elev)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(theme.colors.border, lineWidth: 2)
                    )
            )
            .overlay(alignment: .top) {
                // 指向圆环的小尾巴
                Rectangle()
                    .fill(theme.colors.elev)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Rectangle()
                            .stroke(theme.colors.border, lineWidth: 2)
                    )
                    .rotationEffect(.degrees(45))
                    .offset(y: -5)
                    .mask(Rectangle().padding(.bottom, 1))
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.62), value: text)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.94).combined(with: .opacity),
                removal: .opacity))
            .id(text)
    }
}
