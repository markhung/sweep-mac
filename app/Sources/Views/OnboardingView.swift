import SwiftUI
import AppKit

/// 首次安装 · 权限引导 —— 严格对齐设计稿 `.setup`：
/// 视觉锚点（虚线环 → 授权后转实线薄荷 + 盾牌勾）、三步指引、打开系统设置 / 稍后再说
struct OnboardingView: View {
    @ObservedObject var appState: AppState
    private var theme: Theme { Theme.current }

    private var _waiting = State(initialValue: false)
    private var waiting: Bool {
        get { _waiting.wrappedValue }
        nonmutating set { _waiting.wrappedValue = newValue }
    }

    var body: some View {
        VStack(spacing: 18) {
            setupTop
            setupH
            setupP
            steps
            setupAct
        }
        .padding(.top, 34)
        .padding(.horizontal, 30)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0xFFB224, alpha: 0.06), .clear],
                           startPoint: .top, endPoint: .bottom)
                .background(theme.colors.bg)
        )
    }

    // MARK: - 视觉锚点
    private var setupTop: some View {
        ZStack {
            Circle()
                .stroke(appState.permissionGranted
                        ? Color(hex: 0x68E0A4, alpha: 0.5)
                        : theme.colors.border,
                        style: StrokeStyle(lineWidth: 5,
                                           dash: appState.permissionGranted ? [CGFloat]() : [5, 10]))
                .frame(width: 160, height: 160)
            Image(systemName: appState.permissionGranted ? "checkmark.shield.fill" : "shield")
                .font(.system(size: 42))
                .foregroundStyle(appState.permissionGranted ? theme.colors.ok : theme.colors.accent)
        }
        .frame(width: 160, height: 160)
        .frame(maxWidth: .infinity)
    }

    private var setupH: some View {
        Text("需要「完全磁盘访问权限」")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(theme.colors.text1)
            .multilineTextAlignment(.center)
            .padding(.top, 22)
    }

    private var setupP: some View {
        Text("macOS 默认不允许任何应用读取其他应用的数据。\n授权后 Sweep 才能清理应用缓存与应用残留。")
            .font(.system(size: 12.5))
            .foregroundStyle(theme.colors.text3)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .padding(.top, 10)
    }

    private var steps: some View {
        VStack(spacing: 0) {
            step(1, "打开 系统设置")
            Divider().background(theme.colors.borderSoft)
            step(2, "进入 隐私与安全性 › 完全磁盘访问权限")
            Divider().background(theme.colors.borderSoft)
            step(3, "打开 Sweep 的开关，然后回到本窗口")
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(theme.colors.panel)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(theme.colors.borderSoft, lineWidth: 1))
        )
        .padding(.top, 20)
    }
    private func step(_ n: Int, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(n)")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.colors.accent)
                .frame(width: 19, height: 19)
                .background(
                    Circle().fill(theme.colors.accent.opacity(0.11))
                        .overlay(Circle().stroke(theme.colors.accent.opacity(0.22), lineWidth: 1))
                )
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(theme.colors.text2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var setupAct: some View {
        VStack(spacing: 12) {
            if waiting {
                HStack(spacing: 8) {
                    Circle().fill(theme.colors.accent).frame(width: 6, height: 6)
                    Text("已打开系统设置，勾选 Sweep 后回来点「重新检测」")
                        .font(.system(size: 11.5))
                        .foregroundStyle(theme.colors.text3)
                }
            }
            Button(action: primaryAction) {
                Text(waiting ? "重新检测" : "打开系统设置")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1C1305))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.plain)
            .background(
                LinearGradient(colors: [Color(hex: 0xFFC24D), Color(hex: 0xFF9A1F)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Button {
                appState.showOnboarding = false
            } label: {
                Text("稍后再说")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.colors.text3)
                    .padding(5)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private func primaryAction() {
        if waiting {
            appState.refreshPermissionStatus()
            if appState.permissionGranted { appState.showOnboarding = false }
        } else {
            openFDA()
            waiting = true
        }
    }
    private func openFDA() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
