import SwiftUI
import AppKit

/// 主界面 —— 严格对齐设计稿 `.win` + `.stack`：
/// 标题栏（交通灯 + 齿轮）→ 上仪表 GaugeView / 下明细 DetailView；
/// 与引导、设置互斥切换；强制停止用窗口内 sheet。
struct MainView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var updateService: UpdateService
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
            if showUpdate { updatePopoverLayer }
        }
        .frame(width: 468, height: 740)
        .background(theme.colors.bg)
        .onAppear { appState.bootstrapPermission() }
        // 浮层互斥：任何时刻只留一个。开始清理或弹停止确认时收起更新浮层
        .onChange(of: appState.phase) { phase in
            if phase.isRunning || showStopConfirm { closeUpdatePopover() }
        }
        .onChange(of: showStopConfirm) { shown in
            if shown { closeUpdatePopover() }
        }
        .onExitCommand {
            // Esc 分层：每次只收最上面一层（确认层 → 更新浮层 → 设置）
            if showStopConfirm {
                showStopConfirm = false
            } else if showUpdate {
                closeUpdatePopover()
            } else if appState.showSettings {
                appState.showSettings = false
            }
        }
    }

    private var appView: some View {
        VStack(spacing: 0) {
            titleBar
            GaugeView(appState: appState, onStopRequest: { showStopConfirm = true })
            DetailView(appState: appState)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 标题栏（设计稿 .bar：46px，居中字标，右侧版本号 + 齿轮）
    ///
    /// 红黄绿用系统原生按钮（.windowStyle(.hiddenTitleBar) 自带），
    /// 这里不再自绘，避免出现两套按钮嵌套。
    private var titleBar: some View {
        ZStack {
            HStack(spacing: 7) {
                // 琥珀点：5px 实心 + 3px 光环（设计稿 .bar-title .dot）
                Circle().fill(theme.colors.accent)
                    .frame(width: 5, height: 5)
                    .background(Circle().fill(theme.colors.accent.opacity(0.14))
                        .frame(width: 11, height: 11))
                Text("Sweep")
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(0.75)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.colors.text1)
            }
            HStack {
                Spacer()
                versionButton
                settingsButton.padding(.leading, 6)
            }
            .padding(.trailing, 16)
        }
        .frame(height: 46)
        .background(
            LinearGradient(colors: [Color(hex: 0xFFFFFF, alpha: 0.028), .clear],
                           startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
        }
    }
    /// 版本号入口（设计稿 .ver）：点击打开检查更新浮层；
    /// 有已报未装的新版本时挂琥珀点（5px 实心 + 11px 光环，同标题栏圆点规格）
    private var versionButton: some View {
        Button {
            showUpdate = true
        } label: {
            Text("v\(appState.appVersion)")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.84)
                .foregroundStyle(theme.colors.text2)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.001))
                )
                .overlay(alignment: .topTrailing) {
                    if updateService.hasPendingUpdate {
                        Circle().fill(theme.colors.warn)
                            .frame(width: 5, height: 5)
                            .background(Circle().fill(theme.colors.warn.opacity(0.18))
                                .frame(width: 11, height: 11))
                            .offset(x: 4, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .help("Sweep v\(appState.appVersion) · 检查更新")
    }

    /// 关闭更新浮层并作废在途的手动检查回调（启动静默检查不受影响）
    private func closeUpdatePopover() {
        showUpdate = false
        updateService.cancelInFlightManual()
    }

    /// 检查更新浮层：标题栏附属的非模态层。透明捕获层负责「点空白关闭」，
    /// 不加暗色遮罩——主界面在它下面照常可见（同原生 popover 的一次点击语义）
    private var updatePopoverLayer: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: 468, height: 740)
                .onTapGesture { closeUpdatePopover() }
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    UpdateSheet(appState: appState,
                                updateService: updateService,
                                isPresented: showUpdateBinding)
                        .padding(.top, 39)      // 箭头尖落在版本号下缘
                        .padding(.trailing, 16)
                }
                Spacer()
            }
        }
    }
    private var settingsButton: some View {
        Button {
            appState.showSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.colors.text2)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.001))
                )
        }
        .buttonStyle(.plain)
        .help("设置")
    }

    // MARK: - 强制停止确认（设计稿 .sheet）
    /// 确认文案带实时数字：已释放多少、几项完成；未完成部分如实说明
    private var stopDesc: Text {
        let secondary = theme.colors.text1
        let strong = theme.colors.text0
        let n = appState.cleanedCount
        guard n > 0 else {
            return Text("当前还没有项目清理完成，尚未清理的部分保持原样，不会被删除。")
                .foregroundColor(secondary)
        }
        return Text("当前已释放 ").foregroundColor(secondary)
            + Text(SizeFormat.human(appState.reclaimedBytes))
                .fontWeight(.semibold).foregroundColor(strong)
            + Text("，").foregroundColor(secondary)
            + Text("\(n) 项").fontWeight(.semibold).foregroundColor(strong)
            + Text("已完成。尚未清理的部分保持原样，不会被删除。").foregroundColor(secondary)
    }

    private var stopSheet: some View {
        ZStack {
            Color(hex: 0x060608, alpha: 0.62)
                .frame(width: 468, height: 740)
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
                    .foregroundStyle(theme.colors.text0)
                    .padding(.top, 16)
                // 文案带实时数字：让用户知道停止会损失什么
                stopDesc
                    .font(.system(size: 12.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: 280)
                    .padding(.top, 8)
                HStack(spacing: 10) {
                    Button {
                        showStopConfirm = false
                    } label: {
                        Text("继续清理")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(theme.colors.text0)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                    .buttonStyle(.plain)
                    // 默认焦点落在安全侧：回车 = 继续清理（破坏性确认黄金规则）
                    .keyboardShortcut(.defaultAction)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(theme.colors.border, lineWidth: 1))
                    )
                    Button {
                        appState.cancel()
                        showStopConfirm = false
                    } label: {
                        Text("停止清理")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: 0xC22F33), Color(hex: 0xA02024)],
                                                 startPoint: .top, endPoint: .bottom))
                    )
                }
                .padding(.top, 22)
                .frame(maxWidth: 300)
            }
            .padding(24)
            .frame(width: min(348, 468 - 56))
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(theme.colors.elev)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color(hex: 0x2E2E37), lineWidth: 1))
            )
        }
    }
}
