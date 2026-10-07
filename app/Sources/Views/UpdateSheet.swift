import SwiftUI

/// 检查更新浮层：设计稿要求「正在检查更新… / 已是最新 / 有新版本」。
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
        ZStack {
            Color(hex: 0x000000, alpha: 0.30)
                .frame(width: 420, height: 600)
                .allowsHitTesting(true)
                .onTapGesture { isPresented = false }

            card
        }
        .frame(width: 420, height: 600)
        .onAppear { runCheck() }
    }

    private var card: some View {
        VStack(spacing: 16) {
            Text("检查更新")
                .font(theme.fonts.body(15, .bold))
                .foregroundStyle(theme.colors.text0)

            if checking {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.1)
                Text("正在检查更新…")
                    .font(theme.fonts.body(12, .medium))
                    .foregroundStyle(theme.colors.text1)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(theme.colors.ok)
                Text("已是最新")
                    .font(theme.fonts.body(14, .semibold))
                    .foregroundStyle(theme.colors.text0)
                Text("当前版本 v\(appState.appVersion)")
                    .font(theme.fonts.body(12, .medium))
                    .foregroundStyle(theme.colors.text2)
            }

            Button {
                isPresented = false
            } label: {
                Text("稍后")
                    .font(theme.fonts.body(13, .semibold))
                    .foregroundStyle(theme.colors.text0)
                    .frame(width: 120, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.colors.elev)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(theme.colors.border, lineWidth: 1.5))
                    )
            }
            .buttonStyle(.plain)
            .disabled(checking)
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.colors.panel)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.colors.border, lineWidth: 2))
        )
        .shadow(color: theme.colors.text0.opacity(0.18), radius: 18, x: 0, y: 8)
    }

    private func runCheck() {
        checking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            checking = false
        }
    }
}
