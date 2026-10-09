import SwiftUI

/// 检查更新浮层：挂在标题栏版本号下的非模态浮层（设计稿「检查更新」）。
/// 点版本号才问，不问就不打扰；Esc / 点空白 / 「知道了」三条退路。
/// 四态：检查中 / 已是最新 / 发现新版本（要点 + 去更新）/ 检查失败（可重试）。
/// 结果与文案来自 UpdateService（GitHub Releases），本视图不持有检查状态。
struct UpdateSheet: View {
    @ObservedObject var appState: AppState
    @ObservedObject var updateService: UpdateService
    @Binding var isPresented: Bool
    private var theme: Theme { Theme.current }

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack(alignment: .top) {
            card
            arrow
                .offset(y: -6)      // 底部 1px 叠进卡片边框，接缝融合
        }
        .padding(.top, 7)           // 给箭头留出高度
        .onAppear { updateService.checkNow() }
    }

    /// 箭头：实心三角与卡片同底色，两条斜边描边与边框同色
    private var arrow: some View {
        let borderColor = theme.colors.borderPop
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 7))
                p.addLine(to: CGPoint(x: 7, y: 0))
                p.addLine(to: CGPoint(x: 14, y: 7))
                p.closeSubpath()
            }
            .fill(theme.colors.elev)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 7))
                p.addLine(to: CGPoint(x: 7, y: 0))
                p.addLine(to: CGPoint(x: 14, y: 7))
            }
            .stroke(borderColor, lineWidth: 1)
        }
        .frame(width: 14, height: 7)
        .offset(x: 63)              // 指向标题栏的版本号入口
    }

    @ViewBuilder
    private var card: some View {
        switch updateService.state {
        case .idle, .checking:
            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
                Text("正在检查更新…")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(theme.colors.text1)
            }
            .frame(width: 240)
            .cardChrome()

        case .upToDate:
            // 形状 + 颜色双通道：对勾 = 没问题
            VStack(spacing: 14) {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(theme.colors.ok)
                    Text("已是最新")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(theme.colors.text0)
                }
                Text("当前版本 v\(appState.appVersion)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(theme.colors.text2)
                closeButton
            }
            .frame(width: 240)
            .cardChrome()

        case .available(let info):
            // 先讲更新了什么，再问要不要；要点为空时整体不出现，不留占位文案
            VStack(spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(theme.colors.warn)
                    Text("发现新版本 v\(info.version)")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(theme.colors.text0)
                }
                if !info.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(info.notes, id: \.self) { note in
                            HStack(alignment: .top, spacing: 6) {
                                Circle().fill(theme.colors.accent).opacity(0.75)
                                    .frame(width: 3, height: 3)
                                    .padding(.top, 5)
                                Text(note)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(theme.colors.text1)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.colors.panel)
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.colors.borderSoft, lineWidth: 1))
                    )
                }
                Button {
                    openURL(URL(string: info.htmlURL) ?? UpdateService.releasePageURL)
                    isPresented = false
                } label: {
                    Text("去更新")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1C1305))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(theme.colors.primaryBtn)
                        )
                }
                .buttonStyle(.plain)
                // 下载失败的人工兜底路径：浏览器被拦时仍有一条手走的路
                Text("或打开 \(UpdateService.releasePageURL.absoluteString)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(theme.colors.text3)
                    .onTapGesture {
                        openURL(UpdateService.releasePageURL)
                    }
                closeButton
            }
            .frame(width: 280)
            .cardChrome()

        case .failed(let message):
            // 仅手动检查可达；内联提示 + 重试，不用 alert 打断
            VStack(spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.arrow.circlepath")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.colors.text2)
                    Text("检查失败")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(theme.colors.text0)
                }
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.colors.text2)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Button {
                        updateService.checkNow()
                    } label: {
                        Text("重试")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.colors.text0)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.clear)
                                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(theme.colors.border, lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    closeButton
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 240)
            .cardChrome()
        }
    }

    private var closeButton: some View {
        Button {
            isPresented = false
        } label: {
            Text("知道了")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.colors.text0)
                .padding(.horizontal, 18)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.colors.border, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    /// 浮层卡片外观：raise 底 + 深描边 + 悬浮投影（与设计稿 .pcard 同源）
    func cardChrome() -> some View {
        padding(20)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Theme.current.colors.elev)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Theme.current.colors.borderPop, lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 10)
    }
}
