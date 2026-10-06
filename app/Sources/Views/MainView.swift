import SwiftUI

struct MainView: View {
    @ObservedObject var appState: AppState

    private let windowSize = CGSize(width: 420, height: 600)
    private let titleBarHeight: CGFloat = 44
    /// 面板高度按原型推算：600 - 标题栏44 - 上16 - 圆环196 - 气泡42
    ///  - 释放行19 - 面板上边距12 - 按钮51 - 下18 = 202
    private let panelHeight: CGFloat = 202

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            windowBackground

            VStack(spacing: 0) {
                titleBar

                VStack(spacing: 0) {
                    DialView(state: appState) { appState.start() }
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

            // 右下角常驻猫娘
            MascotView(pose: appState.pose)
                .padding(.trailing, 6)
                .padding(.bottom, 6)
                .allowsHitTesting(false)

            // 首次启动的权限引导覆盖层（全屏盖住主界面）
            if appState.showOnboarding {
                OnboardingView(appState: appState)
                    .transition(.opacity)
            }
        }
        .frame(width: windowSize.width, height: windowSize.height)
        .background(Palette.win)
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
    }

    // MARK: - 未授权常驻提示条

    /// 方案 (A)：悬浮胶囊，绝对定位覆盖在标题栏下沿、水平居中，
    /// **不参与 VStack 垂直预算**，因此不会把底部按钮挤出窗口。
    ///
    /// 垂直预算是按位图逐像素量出来的（见 build/snapshots，x=210pt 列）：
    ///   品牌字标底 ≈ 30.1pt，圆环外沿顶 = 65.5pt，中间只有 35.4pt 的空档，
    ///   而胶囊 26pt 放不下 —— 只能往两头借。取「胶囊高 24 + 顶部留白 35」：
    ///   胶囊占 y 35..59，距字标 ≈4.9pt、距圆环顶 ≈6.5pt，两头都不压。
    /// 点击可重新进入引导。
    private var permissionBanner: some View {
        Button {
            appState.presentOnboarding()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.c1)
                Text("开启完全磁盘访问权限，扫得更干净")
                    .font(SweepFont.body(11.5, weight: .semibold))
                    .foregroundStyle(Palette.text0)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.text2)
            }
            .padding(.leading, 13)
            .padding(.trailing, 11)
            .frame(height: 26)
            .background(
                Capsule()
                    .fill(Palette.elev)
                    .overlay(Capsule().stroke(Palette.border, lineWidth: 1.5))
            )
            .shadow(color: Color(hex: 0x4A3F55, alpha: 0.12), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .help("重新查看完全磁盘访问权限引导")
    }

    // MARK: - 背景

    /// 注意：aspectRatio(.fill) 会让图片返回比提案更大的尺寸，
    /// 从而把整个 ZStack 撑大、把兄弟视图挤出版心——必须在这里
    /// 用固定 frame + clipped 把背景钉死在窗口大小里。
    private var windowBackground: some View {
        ZStack {
            Palette.win
            if let bg = Resources.image("bg-necogirl", ext: "jpg") {
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
        ZStack {
            BrandMark(width: 74, height: 16.2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: titleBarHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.borderSoft)
                .frame(height: 2)
        }
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
                    .font(.system(size: 11.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.text1)
            }
            Spacer()
        }
        .frame(height: 16)
        .padding(.top, 3)
        .overlay(alignment: .trailing) {
            // 运行中才出现的「停止」出口（Esc 同效）
            Button("停止") { appState.cancel() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.text2)
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
                .fill(Palette.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.borderSoft, lineWidth: 2)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 12)
        .animation(.easeInOut(duration: 0.32), value: appState.phase)
        .animation(.easeInOut(duration: 0.32), value: appState.showDetail)
    }

    // MARK: - 底部按钮（宽度右退 100 给猫娘让位）

    private var actions: some View {
        HStack {
            Button {
                appState.showDetail.toggle()
            } label: {
                Text(appState.showDetail ? "收起日志" : "查看详情")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.text0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Palette.elev)
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(Palette.border, lineWidth: 2)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(height: 38)
        .padding(.trailing, 100)
        .padding(.top, 13)
        .opacity(appState.phase == .done ? 1 : 0)
        .allowsHitTesting(appState.phase == .done)
    }
}
