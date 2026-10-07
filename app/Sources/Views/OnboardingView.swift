import SwiftUI
import AppKit

/// 首次启动的「完全磁盘访问权限」引导覆盖层：四屏
/// ① 欢迎 → ② 权限说明 → ③ 授权操作 → ④ 完成。
///
/// 猫系主题风格，仅一套引导。
struct OnboardingView: View {

    @ObservedObject var appState: AppState


    private var theme: Theme { Theme.anime }

    // MARK: - 手工 State

    private var _step: State<Int>
    private var step: Int {
        get { _step.wrappedValue }
        nonmutating set { _step.wrappedValue = newValue }
    }

    private var _settingsHint = State(initialValue: false)
    private var settingsHint: Bool {
        get { _settingsHint.wrappedValue }
        nonmutating set { _settingsHint.wrappedValue = newValue }
    }

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
            if step == 2 { appState.refreshPermissionStatus() }
        }
        .onChange(of: appState.permissionStatus) { status in
            if step == 2 && status == .granted {
                withAnimation(.easeInOut(duration: 0.3)) { self.step = 3 }
            }
        }
    }

    // MARK: - 背景

    private var background: some View {
        ZStack {
            theme.colors.bg
            if theme.backgroundImageName == nil {
                LinearGradient(colors: [theme.colors.bg, theme.colors.panel, theme.colors.elev],
                               startPoint: .top, endPoint: .bottom)
                    .opacity(0.92)
            }
        }
        .frame(width: 420, height: 600)
        .clipped()
    }

    // MARK: - 步骤指示点

    private var indicator: some View {
        HStack(spacing: 7) {
            ForEach(0..<Self.totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? theme.colors.accent : theme.colors.border)
                    .frame(width: i == step ? 18 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 14) {
            if theme.mascot.isVisible {
                mascot
            }

            Text(titleText)
                .font(theme.fonts.dialCenter(23))
                .tracking(1)
                .foregroundStyle(theme.colors.text0)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if step == 2 {
                howToList
                statusRow
                if settingsHint { hintLine }
            } else {
                Text(bodyText)
                    .font(theme.fonts.body(12.5, .medium))
                    .foregroundStyle(theme.colors.text1)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 立绘

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
                    .shadow(color: Color(hex: 0x000000, alpha: 0.20), radius: 8, x: 0, y: 8)
            } else {
                Color.clear.frame(width: mascotHeight * 0.71, height: mascotHeight)
            }
        }
        .frame(height: mascotHeight)
    }

    // MARK: - 授权操作屏

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
                .font(theme.fonts.dialCenter(13))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(theme.colors.primaryBtn))
            Text(text)
                .font(theme.fonts.body(12.5, .medium))
                .foregroundStyle(theme.colors.text0)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
            Spacer(minLength: 0)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(grantedStatus ? theme.colors.ok : theme.colors.warn)
                .frame(width: 7, height: 7)
            Text(grantedStatus ? "已检测到授权" : "尚未检测到授权，开好开关再复检")
                .font(theme.fonts.body(11.5, .semibold))
                .foregroundStyle(theme.colors.text1)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 13)
        .background(
            Capsule()
                .fill(theme.colors.elev)
                .overlay(Capsule().stroke(theme.colors.border, lineWidth: 1.5))
        )
    }

    private var hintLine: some View {
        Text("没打开？请手动打开「系统设置 → 隐私与安全性 → 完全磁盘访问权限」。")
            .font(theme.fonts.body(10.5, .medium))
            .foregroundStyle(theme.colors.warn)
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
        case 0:  return "欢迎使用 Sweep"
        case 1:  return "清理看不见的角落"
        case 2:  return "动手开一下"
        default: return grantedStatus ? "准备就绪" : "重启一下"
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            appState.refreshPermissionStatus()
        }
    }
}

// MARK: - 按钮

private struct PrimaryButton: View {
    let title: String

    let action: () -> Void

    private var theme: Theme { Theme.anime }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.fonts.dialCenter(17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.colors.primaryBtn)
                        .shadow(color: theme.colors.accent.opacity(0.38), radius: 9, x: 0, y: 5)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SecondaryButton: View {
    let title: String

    let action: () -> Void

    private var theme: Theme { Theme.anime }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.fonts.body(13, .semibold))
                .foregroundStyle(theme.colors.text1)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.colors.elev)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(theme.colors.border, lineWidth: 2)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct LinkButton: View {
    let title: String

    let action: () -> Void

    private var theme: Theme { Theme.anime }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.fonts.body(12, .semibold))
                .foregroundStyle(theme.colors.accent2)
                .underline()
                .frame(height: 22)
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}
