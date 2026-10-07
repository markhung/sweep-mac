import SwiftUI

struct MainView: View {
    @ObservedObject var appState: AppState

    private let windowSize = CGSize(width: 420, height: 600)
    private let titleBarHeight: CGFloat = 44
    /// 面板高度按原型推算：600 - 标题栏44 - 上16 - 圆环196 - 气泡42
    ///  - 释放行19 - 面板上边距12 - 按钮51 - 下18 = 202
    private let panelHeight: CGFloat = 202

    private var theme: Theme { Theme.current }
    private var _showStopConfirm = State(initialValue: false)
    private var showStopConfirm: Bool {
        get { _showStopConfirm.wrappedValue }
        nonmutating set { _showStopConfirm.wrappedValue = newValue }
    }

    private var _showSettings = State(initialValue: false)
    private var showSettings: Bool {
        get { _showSettings.wrappedValue }
        nonmutating set { _showSettings.wrappedValue = newValue }
    }
    private var showSettingsBinding: Binding<Bool> {
        Binding(get: { showSettings }, set: { showSettings = $0 })
    }
    private var _showUpdate = State(initialValue: false)
    private var showUpdate: Bool {
        get { _showUpdate.wrappedValue }
        nonmutating set { _showUpdate.wrappedValue = newValue }
    }
    private var showUpdateBinding: Binding<Bool> {
        Binding(get: { showUpdate }, set: { showUpdate = $0 })
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            windowBackground

            VStack(spacing: 0) {
                titleBar

                VStack(spacing: 0) {
                    DialView(state: appState, onTap: { appState.start() }, onPause: { appState.cancel() })
                        .frame(height: 196)

                    bubbleRow
                    releasedRow
                    panel
                    actions
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }

            // 右下角 mascot（按主题显隐）
            if theme.mascot.isVisible {
                MascotView(pose: appState.pose)
                    .padding(.trailing, 6)
                    .padding(.bottom, 6)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // 首次启动的权限引导覆盖层（全屏盖住主界面）
            if appState.showOnboarding {
                OnboardingView(appState: appState)
                    .transition(.opacity)
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .background(theme.colors.bg)
        .overlay(alignment: .top) {
            if appState.showsPermissionBanner {
                permissionBanner
                    .padding(.top, 35)
            }
        }
        .onExitCommand {
            appState.showOnboarding ? appState.dismissOnboarding() : appState.cancel()
        }
        .animation(.easeInOut(duration: 0.3), value: appState.phase)
        .animation(.easeInOut(duration: 0.25), value: appState.showOnboarding)
        .overlay {
            if showStopConfirm {
                stopConfirmCard
            }
        }
        .sheet(isPresented: showSettingsBinding) {
            SettingsView(appState: appState,
                         isPresented: showSettingsBinding,
                         onCheckUpdate: { showUpdate = true })
        }
        .sheet(isPresented: showUpdateBinding) {
            UpdateSheet(appState: appState, isPresented: showUpdateBinding)
        }
    }

    // MARK: - 未授权常驻提示条

    private var permissionBanner: some View {
        Button {
            appState.presentOnboarding()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.colors.accent)
                Text("开启完全磁盘访问权限，扫得更干净")
                    .font(theme.fonts.body(11.5, .semibold))
                    .foregroundStyle(theme.colors.text0)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.colors.text2)
            }
            .padding(.leading, 13)
            .padding(.trailing, 11)
            .frame(height: 26)
            .background(
                Capsule()
                    .fill(theme.colors.elev)
                    .overlay(Capsule().stroke(theme.colors.border, lineWidth: 1.5))
            )
            .shadow(color: theme.colors.text0.opacity(0.12), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .help("重新查看完全磁盘访问权限引导")
    }

    // MARK: - 背景

    private var windowBackground: some View {
        ZStack {
            theme.colors.bg
            if let name = theme.backgroundImageName,
               let bg = Resources.image(name, ext: "jpg") {
                Image(nsImage: bg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.07)
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .clipped()
    }

    // MARK: - 标题栏

    private var titleBar: some View {
        HStack(spacing: 0) {
            trafficLights
                .padding(.leading, 16)
            Spacer()
            BrandMark(width: 74, height: 16.2)
                .allowsHitTesting(false)
            Spacer()
            HStack(spacing: 10) {
                versionPill
                settingsButton
            }
            .padding(.trailing, 16)
        }
        .frame(height: titleBarHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.colors.borderSoft)
                .frame(height: 2)
        }
    }

    /// macOS 交通灯（设计稿：#FF5F57 / #FEBC2E / #28C840，r=3.2）
    private var trafficLights: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: 0xFF5F57))
                .frame(width: 11, height: 11)
                .onTapGesture { NSApp.terminate(nil) }
            Circle()
                .fill(Color(hex: 0xFEBC2E))
                .frame(width: 11, height: 11)
            Circle()
                .fill(Color(hex: 0x28C840))
                .frame(width: 11, height: 11)
        }
        .help("关闭")
    }

    /// 右侧版本号胶囊：点击唤起检查更新浮层
    private var versionPill: some View {
        Button {
            showUpdate = true
        } label: {
            Text("v\(appState.appVersion)")
                .font(theme.fonts.body(11, .semibold))
                .foregroundStyle(theme.colors.text1)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(theme.colors.elev)
                        .overlay(Capsule().stroke(theme.colors.border, lineWidth: 1.5))
                )
        }
        .buttonStyle(.plain)
        .help("检查更新")
    }

    /// 设置入口
    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.colors.text1)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(theme.colors.elev)
                        .overlay(Circle().stroke(theme.colors.border, lineWidth: 1.5))
                )
        }
        .buttonStyle(.plain)
        .help("设置")
    }

    // MARK: - 气泡 + 实时释放量

    private var bubbleRow: some View {
        BubbleView(text: appState.bubbleText)
            .frame(height: 36)
            .padding(.top, 6)
    }

    private var releasedRow: some View {
        HStack {
            Spacer()
            if !appState.releasedText.isEmpty {
                Text(appState.releasedText)
                    .font(theme.fonts.body(11.5, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.text1)
            }
            Spacer()
        }
        .frame(height: 16)
        .padding(.top, 3)
        .overlay(alignment: .trailing) {
            // 运行中才出现的「停止」出口（Esc 同效）
            Button("停止") { showStopConfirm = true }
                .buttonStyle(.plain)
                .font(theme.fonts.body(11, .semibold))
                .foregroundStyle(theme.colors.text2)
                .opacity(appState.phase == .running ? 1 : 0)
                .allowsHitTesting(appState.phase == .running)
                .help("停止本次清理")
        }
    }

    // MARK: - 面板（提示 / 日志 / 结果 / 详情）

    private var panel: some View {
        ZStack {
            if appState.showDetail, !appState.reports.isEmpty {
                LogPanel(entries: appState.entries, grouped: appState.reports)
            } else {
                switch appState.phase {
                case .idle, .failed:
                    HintPanel()
                case .running:
                    LogPanel(entries: appState.entries, grouped: nil)
                case .done:
                    if let report = appState.report {
                        ResultPanel(report: report,
                                    title: appState.resultTitle,
                                    size: appState.resultSize)
                    } else {
                        LogPanel(entries: appState.entries, grouped: nil)
                    }
                }
            }
        }
        .frame(height: panelHeight)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.colors.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.colors.borderSoft, lineWidth: 2)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 12)
        .animation(.easeInOut(duration: 0.32), value: appState.phase)
        .animation(.easeInOut(duration: 0.32), value: appState.showDetail)
    }

    // MARK: - 底部按钮

    private var actions: some View {
        HStack {
            Button {
                appState.showDetail.toggle()
            } label: {
                Text(appState.showDetail ? "收起日志" : "查看详情")
                    .font(theme.fonts.body(13, .bold))
                    .foregroundStyle(theme.colors.text0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(theme.colors.elev)
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(theme.colors.border, lineWidth: 2)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(height: 38)
        .padding(.trailing, theme.mascot.isVisible ? 100 : 0)
        .padding(.top, 13)
        .opacity(appState.phase == .done ? 1 : 0)
        .allowsHitTesting(appState.phase == .done)
    }

    // MARK: - 停止清理二次确认弹窗

    private var stopConfirmCard: some View {
        ZStack {
            Color(hex: 0x000000, alpha: 0.30)
                .frame(width: windowSize.width, height: windowSize.height)
                .allowsHitTesting(true)

            VStack(spacing: 14) {
                Text("确定要停止清理吗？")
                    .font(theme.fonts.dialCenter(18))
                    .foregroundStyle(theme.colors.text0)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)

                Text("已经清掉的部分会保留，剩下的文件不会再扫。")
                    .font(theme.fonts.body(12, .medium))
                    .foregroundStyle(theme.colors.text1)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 232)

                HStack(spacing: 12) {
                    Button {
                        showStopConfirm = false
                    } label: {
                        Text("继续清理")
                            .font(theme.fonts.body(13, .semibold))
                            .foregroundStyle(theme.colors.text0)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(theme.colors.elev)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .stroke(theme.colors.border, lineWidth: 2)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        appState.cancel()
                        showStopConfirm = false
                    } label: {
                        Text("停止清理")
                            .font(theme.fonts.body(13, .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(theme.colors.primaryBtn)
                                    .shadow(color: theme.colors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 252)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.colors.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(theme.colors.border, lineWidth: 2)
                    )
            )
            .shadow(color: theme.colors.text0.opacity(0.18), radius: 18, x: 0, y: 8)
        }
        .frame(width: windowSize.width, height: windowSize.height)
    }
}
