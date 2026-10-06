import SwiftUI

// MARK: - 进度圆环 + 中心按钮

struct DialView: View {
    @ObservedObject var state: AppState
    var onTap: () -> Void

    private let size: CGFloat = 196
    private var clickable: Bool { state.phase == .idle || state.phase == .done }

    var body: some View {
        ZStack {
            // 待机：呼吸光环
            if state.phase == .idle {
                BreatheHalo().frame(width: size, height: size)
            }

            // 运行中：外圈旋转虚线
            if state.phase == .running {
                RotatingHalo().frame(width: size, height: size)
            }

            // 轨道
            Circle()
                .stroke(Palette.track, lineWidth: 9)
                .frame(width: 176, height: 176)

            // 进度（完成态换绿粉渐变）
            RingArc(progress: state.percent)
                .stroke(style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .foregroundStyle(state.phase == .done ? Palette.ringDone : Palette.ringRun)
                .frame(width: 176, height: 176)

            // 进度头部的小星星
            if state.phase == .running, state.percent > 0.02 {
                SparkleShape()
                    .fill(Color.white)
                    .frame(width: 13, height: 13)
                    .shadow(color: Palette.c1, radius: 2.5)
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
                    .shadow(color: Palette.glow, radius: 12)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: state.phase)
        .help(helpText)
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
            RoundLabel(text: "开始", color: Palette.text0, glow: Palette.glow)
                .transition(.scale.combined(with: .opacity))

        case .running:
            PercentLabel(percent: state.percent)
                .transition(.scale.combined(with: .opacity))

        case .done:
            RoundLabel(text: "完成", color: Palette.ok, glow: Palette.okGlow)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

/// 圆环中心的圆体大字（开始 / 完成）
private struct RoundLabel: View {
    let text: String
    let color: Color
    let glow: Color

    var body: some View {
        Text(text)
            .font(SweepFont.round(31))
            .tracking(9)          // .3em ≈ 9pt
            .foregroundStyle(color)
            .fixedSize()
            // 末尾字符也带字距，会显得偏左，往右补半个字距
            .offset(x: 4.5)
            .shadow(color: glow, radius: 8)
    }
}

/// 中心百分比（圆体数字）
private struct PercentLabel: View {
    let percent: Double

    var body: some View {
        let shown = Int((percent * 100).rounded(.down))
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(shown)")
                .font(SweepFont.round(34))
                .foregroundStyle(Palette.text0)
            Text("%")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.text2)
        }
        .monospacedDigit()
        .fixedSize()
    }
}

/// 待机呼吸：外圈缓慢放大淡出
///
/// 注意：本机只有 Command Line Tools，SwiftUI 的 `@State` 宏插件
/// （SwiftUIMacros）不在工具链里，`@State` 无法展开。下面手工声明
/// `State` 存储 —— 与宏展开的产物一致，SwiftUI 依旧能接管它。
private struct BreatheHalo: View {
    private var _animate = State(initialValue: false)
    private var animate: Bool {
        get { _animate.wrappedValue }
        nonmutating set { _animate.wrappedValue = newValue }
    }

    var body: some View {
        Circle()
            .stroke(Palette.c1, lineWidth: 2)
            .frame(width: 186, height: 186)
            .scaleEffect(animate ? 1.06 : 0.94)
            .opacity(animate ? 0 : 0.35)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)
            .onAppear { animate = true }
    }
}

/// 运行中：虚线光环旋转
private struct RotatingHalo: View {
    private var _spin = State(initialValue: false)
    private var spin: Bool {
        get { _spin.wrappedValue }
        nonmutating set { _spin.wrappedValue = newValue }
    }

    var body: some View {
        Circle()
            .stroke(Palette.c1, style: StrokeStyle(lineWidth: 2.5, lineCap: .round,
                                                   dash: [3, 16]))
            .frame(width: 192, height: 192)
            .opacity(0.38)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 7).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
    }
}

// MARK: - 右下角猫娘

struct MascotView: View {
    let pose: Pose

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
        case .cheer: return CGSize(width: 104, height: 146)
        default:     return CGSize(width: 94, height: 132)
        }
    }

    var body: some View {
        Group {
            if let img = Self.images[pose] {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
                    .shadow(color: Color(hex: 0x4A3F55, alpha: 0.22), radius: 5, x: 0, y: 5)
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

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Palette.text0)
            .lineLimit(1)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Palette.elev)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(Palette.border, lineWidth: 2)
                    )
            )
            .overlay(alignment: .top) {
                // 指向圆环的小尾巴
                Rectangle()
                    .fill(Palette.elev)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Rectangle()
                            .stroke(Palette.border, lineWidth: 2)
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
