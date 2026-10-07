import SwiftUI

/// 检查更新浮层：挂在标题栏版本号下的非模态浮层（设计稿「检查更新」）。
/// 点版本号才问，不问就不打扰；Esc / 点空白 / 「知道了」三条退路。
/// 箭头与卡片同底色、同边框色，视觉上是同一个容器。
/// 当前无真实更新服务器，采用本地版本占位——打开后模拟检查，最终展示「已是最新」。
struct UpdateSheet: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    private var theme: Theme { Theme.current }

    private var _checking = State(initialValue: false)
    private var checking: Bool {
        get { _checking.wrappedValue }
        nonmutating set { _checking.wrappedValue = newValue }
    }

    var body: some View {
        ZStack(alignment: .top) {
            card
            arrow
                .offset(y: -6)      // 底部 1px 叠进卡片边框，接缝融合
        }
        .padding(.top, 7)           // 给箭头留出高度
        .onAppear { runCheck() }
    }

    /// 箭头：实心三角与卡片同底色，两条斜边描边与边框同色
    private var arrow: some View {
        let borderColor = Color(hex: 0x2E2E37)
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

    private var card: some View {
        VStack(spacing: 14) {
            if checking {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
                Text("正在检查更新…")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(theme.colors.text1)
            } else {
                // 结果用形状 + 颜色双通道：对勾 = 没问题
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
                    .foregroundStyle(theme.colors.text2)
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
        .padding(20)
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(theme.colors.elev)
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color(hex: 0x2E2E37), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 10)
    }

    private func runCheck() {
        checking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            checking = false
        }
    }
}
