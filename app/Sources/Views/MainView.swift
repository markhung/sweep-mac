import SwiftUI
import AppKit

/// 主界面 —— 严格对齐设计稿 `.win` + `.stack`：
/// 标题栏（交通灯 + 齿轮）→ 上仪表 GaugeView / 下明细 DetailView；
/// 与引导、设置互斥切换；强制停止用窗口内 sheet。
struct MainView: View {
    @ObservedObject var appState: AppState
    private var theme: Theme { Theme.current }

    private var _showStopConfirm = State(initialValue: false)
    private var showStopConfirm: Bool {
        get { _showStopConfirm.wrappedValue }
        nonmutating set { _showStopConfirm.wrappedValue = newValue }
    }
    private var _showUpdate = State(initialValue: false)
    private var showUpdate: Bool {
        get { _showUpdate.wrappedValue }
        nonmutating set { _showUpdate.wrappedValue = newValue }
    }
    private var showUpdateBinding: Binding<Bool> {
        Binding(get: { showUpdate }, set: { showUpdate = $0 })
    }
    private var showSettingsBinding: Binding<Bool> {
        Binding(get: { appState.showSettings }, set: { appState.showSettings = $0 })
    }

    var body: some View {
        ZStack {
            if appState.showOnboarding {
                OnboardingView(appState: appState)
            } else if appState.showSettings {
                SettingsView(appState: appState,
                             isPresented: showSettingsBinding,
                             onCheckUpdate: { showUpdate = true })
            } else {
                appView
            }
            if showStopConfirm { stopSheet }
        }
        .frame(width: 420, height: 600)
        .background(theme.colors.bg)
        .onAppear { appState.bootstrapPermission() }
        .sheet(isPresented: showUpdateBinding) {
            UpdateSheet(appState: appState, isPresented: showUpdateBinding)
        }
        .onExitCommand { showStopConfirm = false }
    }

    private var appView: some View {
        VStack(spacing: 0) {
            titleBar
            GaugeView(appState: appState)
            DetailView(appState: appState)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 标题栏（设计稿 .bar-title：交通灯 + 齿轮）
    private var titleBar: some View {
        HStack(spacing: 0) {
            trafficLights
                .padding(.leading, 16)
            Spacer()
            settingsButton
                .padding(.trailing, 16)
        }
        .frame(height: 36)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
        }
    }
    private var trafficLights: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: 0xFF5F57)).frame(width: 11, height: 11)
                .onTapGesture { NSApp.terminate(nil) }
            Circle().fill(Color(hex: 0xFEBC2E)).frame(width: 11, height: 11)
            Circle().fill(Color(hex: 0x28C840)).frame(width: 11, height: 11)
        }
        .help("关闭")
    }
    private var settingsButton: some View {
        Button {
            appState.showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.colors.text1)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(theme.colors.elev)
                        .overlay(Circle().stroke(theme.colors.border, lineWidth: 1.5))
                )
        }
        .buttonStyle(.plain)
        .help("设置")
    }

    // MARK: - 强制停止确认（设计稿 .sheet）
    private var stopSheet: some View {
        ZStack {
            Color(hex: 0x060608, alpha: 0.62)
                .frame(width: 420, height: 600)
                .ignoresSafeArea()
                .onTapGesture { showStopConfirm = false }
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(hex: 0xFF5F57, alpha: 0.12))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color(hex: 0xFF5F57))
                    )
                Text("强制停止清理？")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.colors.text1)
                    .padding(.top, 16)
                Text("停止后已清掉的会保留，没扫到的下次还能再清。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.colors.text2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
                    .padding(.top, 8)
                HStack(spacing: 10) {
                    Button { showStopConfirm = false } label: {
                        Text("取消")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.colors.text1)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(theme.colors.border, lineWidth: 1))
                    )
                    Button { appState.cancel(); showStopConfirm = false } label: {
                        Text("停止")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color(hex: 0xC22F33))
                    )
                }
                .padding(.top, 22)
                .frame(maxWidth: 300)
            }
            .padding(24)
            .frame(width: min(348, 420 - 56))
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.colors.elev)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.colors.border, lineWidth: 1))
            )
        }
    }
}
