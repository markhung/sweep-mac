import SwiftUI
import AppKit

/// 设置面板：清理方式 / 删除方式 / 通用（后台运行·常驻菜单栏）/ 权限与关于。
struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    var onCheckUpdate: () -> Void = {}
    private var theme: Theme { Theme.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    cleanSection
                    generalSection
                    permissionSection
                }
                .padding(22)
            }
        }
        .frame(width: 384, height: 468)
        .background(theme.colors.bg)
    }

    // MARK: - 头部

    private var header: some View {
        HStack {
            Text("设置")
                .font(theme.fonts.body(15, .bold))
                .foregroundStyle(theme.colors.text0)
            Spacer()
            Button { isPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.colors.text2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 2)
        }
    }

    // MARK: - 清理方式

    private var cleanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("清理方式")
            Text("立即释放磁盘空间，清理过程全部在本机完成，不联网。")
                .font(theme.fonts.body(12, .medium))
                .foregroundStyle(theme.colors.text1)
                .fixedSize(horizontal: false, vertical: true)

            sectionTitle("删除方式")
            Picker("", selection: Binding(
                get: { appState.deleteMode },
                set: { appState.deleteMode = $0 }
            )) {
                ForEach(DeleteMode.allCases, id: \.self) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - 通用

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("通用")
            toggleRow("开机时在后台运行",
                      subtitle: "登录后自动启动并驻留",
                      isOn: Binding(get: { appState.launchAtLogin },
                                    set: { appState.launchAtLogin = $0 }))
            toggleRow("登录后常驻菜单栏",
                      subtitle: "随时可点开主界面",
                      isOn: Binding(get: { appState.showInMenuBar },
                                    set: { appState.showInMenuBar = $0 }))
        }
    }

    // MARK: - 权限与关于

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("权限与关于")
            HStack(spacing: 8) {
                Image(systemName: appState.permissionGranted
                      ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(appState.permissionGranted ? theme.colors.ok : theme.colors.warn)
                Text(appState.permissionGranted
                     ? "已授予完全磁盘访问权限" : "未授予完全磁盘访问权限")
                    .font(theme.fonts.body(12, .medium))
                    .foregroundStyle(theme.colors.text0)
                Spacer()
                if !appState.permissionGranted {
                    Button("去授权") { openFDA() }
                        .buttonStyle(.plain)
                        .font(theme.fonts.body(12, .semibold))
                        .foregroundStyle(theme.colors.accent)
                }
            }
            HStack {
                Text("当前版本 v\(appState.appVersion)")
                    .font(theme.fonts.body(12, .medium))
                    .foregroundStyle(theme.colors.text1)
                Spacer()
                Button("检查更新") {
                    isPresented = false
                    onCheckUpdate()
                }
                .buttonStyle(.plain)
                .font(theme.fonts.body(12, .semibold))
                .foregroundStyle(theme.colors.accent)
            }
        }
    }

    // MARK: - 小组件

    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(theme.fonts.body(11, .bold))
            .tracking(0.6)
            .foregroundStyle(theme.colors.text2)
    }

    private func toggleRow(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.fonts.body(12.5, .semibold))
                    .foregroundStyle(theme.colors.text0)
                Text(subtitle)
                    .font(theme.fonts.body(11, .medium))
                    .foregroundStyle(theme.colors.text2)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }

    private func openFDA() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
        appState.refreshPermissionStatus()
    }
}
