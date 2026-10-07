import SwiftUI
import AppKit

/// 设置面板 —— 严格对齐设计稿 `.setView`：
/// 分组（清理方式 / 通用 / 权限与关于），每行 sic 图标 + smeta 名称/说明 + 控件
struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Binding var isPresented: Bool
    var onCheckUpdate: () -> Void = {}
    private var theme: Theme { Theme.current }

    var body: some View {
        VStack(spacing: 0) {
            setHd
            setBody
            setFoot
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.bg)
    }

    // MARK: - 头部
    private var setHd: some View {
        HStack {
            Text("设置")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.colors.text1)
            Spacer()
            Button {
                appState.showSettings = false
                isPresented = false
            } label: {
                Text("完成")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1C1305))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.colors.accent)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
        }
    }

    // MARK: - 主体
    private var setBody: some View {
        ScrollView {
            VStack(spacing: 16) {
                sgrp("清理方式") {
                    srow(icon: "trash", name: "删除方式",
                         desc: "立即释放磁盘空间") {
                        Picker("", selection: Binding(get: { appState.deleteMode },
                                                      set: { appState.deleteMode = $0 })) {
                            ForEach(DeleteMode.allCases, id: \.self) { m in
                                Text(m.label).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
                sgrp("通用") {
                    srow(icon: "bell", name: "开机时在后台运行",
                         desc: "登录后常驻菜单栏，随时可点") {
                        amberSwitch(Binding(get: { appState.launchAtLogin },
                                            set: { appState.launchAtLogin = $0 }))
                    }
                }
                sgrp("权限与关于") {
                    srow(icon: "shield", name: "完全磁盘访问权限",
                         desc: appState.permissionGranted ? "已授予" : "未授予，应用缓存与残留清理受限") {
                        if !appState.permissionGranted {
                            Button("去授权") { openFDA() }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.colors.accent)
                        }
                    }
                    srow(icon: "doc", name: "Sweep v\(appState.appVersion)",
                         desc: "当前版本") {
                        Button("检查更新") { isPresented = false; onCheckUpdate() }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.colors.accent)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private func sgrp(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(theme.colors.text3)
                .padding(.horizontal, 2)
            VStack(spacing: 0) { content() }
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(theme.colors.panel)
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(theme.colors.borderSoft, lineWidth: 1))
                )
        }
    }
    private func srow(icon: String, name: String, desc: String,
                      @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(theme.colors.text2)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.colors.elev)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.colors.border, lineWidth: 1))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.colors.text1)
                Text(desc)
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.colors.text3)
            }
            Spacer(minLength: 0)
            control()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
        }
    }

    // MARK: - 底部说明
    private var setFoot: some View {
        Text("原型说明：删除方式会真实改变清理结果；后台运行仅记录状态。")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(theme.colors.text3)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Rectangle().fill(theme.colors.borderSoft).frame(height: 1)
            }
    }

    // MARK: - 琥珀开关（对齐设计稿 .sw）
    private func amberSwitch(_ isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Circle()
                .fill(isOn.wrappedValue ? Color(hex: 0x1C1305) : theme.colors.text3)
                .frame(width: 16, height: 16)
                .padding(2.5)
                .background(
                    Capsule()
                        .fill(isOn.wrappedValue ? theme.colors.accent : theme.colors.elev)
                        .overlay(Capsule()
                            .stroke(isOn.wrappedValue ? Color(hex: 0xFFB224, alpha: 0.5) : theme.colors.border,
                                    lineWidth: 1))
                )
                .frame(width: 36, height: 21)
        }
        .buttonStyle(.plain)
    }

    private func openFDA() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
        appState.refreshPermissionStatus()
    }
}
