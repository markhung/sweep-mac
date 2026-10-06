import SwiftUI
import AppKit

/// 首次启动的「完全磁盘访问权限」引导覆盖层：四屏
/// ① 欢迎 → ② 权限说明 → ③ 授权操作 → ④ 完成。
///
/// 视觉沿用主界面的樱花粉体系：圆角、2px 描边、柔光阴影。
/// 字体遵循既定规则：圆体 `SweepFont.round()` 只用于**大标题 / 按钮文字 / 步骤数字**，
/// 正文一律 `SweepFont.body()` 苹方。（随包圆体是字符子集，故圆体文案都挑选
/// 子集内已覆盖的字，避免同屏出现字体回退造成的混排。）
///
/// 注意：本机只有 Command Line Tools，SwiftUI 的 `@State` 宏插件不在工具链里，
/// 所以下面的状态都手工声明为 `State` 存储 + computed 访问器（与宏展开产物一致）。
struct OnboardingView: View {

    @ObservedObject var appState: AppState

    // MARK: - 手工 State

    private var _step: State<Int>
    /// 当前步骤（0...3）
    private var step: Int {
        get { _step.wrappedValue }
        nonmutating set { _step.wrappedValue = newValue }
    }

    private var _settingsHint = State(initialValue: false)
    /// 深链跳转系统设置失败时，展示「请手动打开」的提示
    private var settingsHint: Bool {
        get { _settingsHint.wrappedValue }
        nonmutating set { _settingsHint.wrappedValue = newValue }
    }

    /// - Parameter initialStep: 初始步骤。仅供离屏快照自检逐屏取图使用。
    init(appState: AppState, initialStep: Int = 0) {
        self.appState = appState
        self._step = State(initialValue: min(max(initialStep, 0), OnboardingView.totalSteps - 1))
    }

    private static let totalSteps = 4
    private var grantedStatus: Bool { appState.permissionGranted }

    // MARK: - 组装

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                indicator
                    .padding(.top, 22)

                Spacer(minLength: 6)

                content

                Spacer(minLength: 6)

                footer
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 26)
        }
        .frame(width: 420, height: 600)
        .onAppear {
            // 进入「授权操作」屏时先探测一次，让状态条反映真实情况
            if step == 2 { appState.refreshPermissionStatus() }
        }
        .onChange(of: appState.permissionStatus) { status in
            // 检测通过 → 自动进入完成屏
            if step == 2 && status == .granted {
                withAnimation(.easeInOut(duration: 0.3)) { self.step = 3 }
            }
        }
    }

    // MARK: - 背景

    private var background: some View {
        ZStack {
            Palette.win
            LinearGradient(colors: [Palette.win, Palette.panel, Palette.elev],
                           startPoint: .top, endPoint: .bottom)
                .opacity(0.92)
            // 底部一圈樱花粉柔光，呼应主界面
            RadialGradient(colors: [Palette.c1.opacity(0.16), Color.clear],
                           center: UnitPoint(x: 0.5, y: 1.08),
                           startRadius: 12, endRadius: 280)
        }
        .frame(width: 420, height: 600)
        .clipped()
    }

    // MARK: - 步骤指示点

    private var indicator: some View {
        HStack(spacing: 7) {
            ForEach(0..<Self.totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Palette.c1 : Palette.border)
                    .frame(width: i == step ? 18 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 14) {
            mascot

            Text(titleText)
                .font(SweepFont.round(23))
                .tracking(1)
                .foregroundStyle(Palette.text0)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if step == 2 {
                howToList
                statusRow
                if settingsHint { hintLine }
            } else {
                Text(bodyText)
                    .font(SweepFont.body(12.5, weight: .medium))
                    .foregroundStyle(Palette.text1)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 立绘（复用同一个角色的三张状态图，绝不新造形象）

    private var mascotName: String {
        switch step {
        case 2:      return "mascot-cheer"
        case 3:      return grantedStatus ? "mascot-done" : "mascot-idle"
        default:     return "mascot-idle"
        }
    }

    private var mascotHeight: CGFloat { step == 2 ? 150 : 178 }

    private var mascot: some View {
        Group {
            if let img = Resources.image(mascotName) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: mascotHeight * 0.71, height: mascotHeight)
                    .shadow(color: Color(hex: 0x4A3F55, alpha: 0.20), radius: 8, x: 0, y: 8)
            } else {
                Color.clear.frame(width: mascotHeight * 0.71, height: mascotHeight)
            }
        }
        .frame(height: mascotHeight)
    }

    // MARK: - 授权操作屏：分步图文

    private var howToList: some View {
        VStack(alignment: .leading, spacing: 9) {
            howRow(1, "打开「系统设置 → 隐私与安全性」")
            howRow(2, "找到「完全磁盘访问权限」，点进去")
            howRow(3, "打开「Sweep」右边的开关")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private func howRow(_ index: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(SweepFont.round(13))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Palette.primaryBtn))
            Text(text)
                .font(SweepFont.body(12.5, weight: .medium))
                .foregroundStyle(Palette.text0)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
            Spacer(minLength: 0)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(grantedStatus ? Palette.ok : Palette.warn)
                .frame(width: 7, height: 7)
            Text(grantedStatus ? "已检测到授权" : "尚未检测到授权，开好开关再复检")
                .font(SweepFont.body(11.5, weight: .semibold))
                .foregroundStyle(Palette.text1)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 13)
        .background(
            Capsule()
                .fill(Palette.elev)
                .overlay(Capsule().stroke(Palette.border, lineWidth: 1.5))
        )
    }

    private var hintLine: some View {
        Text("没打开？请手动打开「系统设置 → 隐私与安全性 → 完全磁盘访问权限」。")
            .font(SweepFont.body(10.5))
            .foregroundStyle(Palette.warn)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)
    }

    // MARK: - 底部按钮

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 10) {
            switch step {
            case 0:
                PrimaryButton(title: "开始吧") { go(to: 1) }
                SecondaryButton(title: "跳过") { finish() }

            case 1:
                PrimaryButton(title: "开启吧") { go(to: 2) }
                SecondaryButton(title: "跳过") { finish() }

            case 2:
                PrimaryButton(title: "打开系统设置") { openSettings() }
                SecondaryButton(title: "重新检测") { appState.refreshPermissionStatus() }
                LinkButton(title: "完成设置") { go(to: 3) }

            default:
                if grantedStatus {
                    PrimaryButton(title: "开始使用") { finish() }
                } else {
                    PrimaryButton(title: "重启 Sweep") { FullDiskAccess.relaunchApp() }
                    SecondaryButton(title: "跳过") { finish() }
                }
            }
        }
    }

    // MARK: - 文案

    private var titleText: String {
        switch step {
        case 0:  return "打扫猫娘来啦～"
        case 1:  return "打扫看不见的角落"
        case 2:  return "动手开一下"
        default: return grantedStatus ? "清扫完成" : "重启一下"
        }
    }

    private var bodyText: String {
        switch step {
        case 0:
            return "把 Mac 里攒下的缓存、日志、残留和大文件，一次扫干净。\n"
                 + "全程在本机完成，不联网，也不用给密码。"
        case 1:
            return "macOS 默认不让 App 看 Safari 缓存、邮件附件、\n"
                 + "信息缓存这些地方。Sweep 看不到，也就清不掉。\n\n"
                 + "给 Sweep 开启「完全磁盘访问权限」后，\n这些角落也能一并扫干净。"
        case 3:
            if grantedStatus {
                return "现在 Sweep 能看到更多角落啦，随时可以开始清扫。"
            }
            return "「完全磁盘访问权限」要重启 App 才会生效哦。\n"
                 + "点「重启 Sweep」，它会带着新权限回来。"
        default:
            return ""
        }
    }

    // MARK: - 动作

    private func go(to index: Int) {
        withAnimation(.easeInOut(duration: 0.28)) {
            step = min(max(index, 0), Self.totalSteps - 1)
        }
    }

    private func finish() {
        appState.dismissOnboarding()
    }

    private func openSettings() {
        let opened = FullDiskAccess.openSystemSettings()
        settingsHint = !opened
        // 用户切去系统设置后 1.5 秒复检一次：若已生效，「自动进入完成屏」
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            appState.refreshPermissionStatus()
        }
    }
}

// MARK: - 按钮

/// 主按钮：品牌渐变填充 + 白字（圆体）
private struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SweepFont.round(17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.primaryBtn)
                        .shadow(color: Palette.c1.opacity(0.38), radius: 9, x: 0, y: 5)
                )
        }
        .buttonStyle(.plain)
    }
}

/// 次按钮：浅粉底 + 描边（正文苹方，弱化处理）
private struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SweepFont.body(13, weight: .semibold))
                .foregroundStyle(Palette.text1)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.elev)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Palette.border, lineWidth: 2)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

/// 文字链按钮：更轻的「继续」出口
private struct LinkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SweepFont.body(12, weight: .semibold))
                .foregroundStyle(Palette.c2)
                .underline()
                .frame(height: 22)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}
