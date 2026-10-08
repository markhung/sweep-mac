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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.colors.bg)
    }

    // MARK: - 头部
    private var setHd: some View {
        HStack {
            Text("设置")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.colors.text0)
            Spacer()
            Button {
                appState.showSettings = false
                isPresented = false
            } label: {
                Text("完成")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1C1305))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
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
                        deleteSegment
                    }
                }
                sgrp("通用") {
                    srow(icon: "bell", name: "开机时在后台运行",
                         desc: "登录后常驻菜单栏，随时可点") {
                        amberSwitch(Binding(get: { appState.launchAtLogin },
                                            set: { appState.launchAtLogin = $0 }))
                    }
                    srow(icon: "bell.badge", name: "更新提醒",
                         desc: "每次打开时自动检查新版本") {
                        amberSwitch(Binding(get: { appState.updateReminder },
                                            set: { appState.updateReminder = $0 }))
                    }
                    srow(icon: "person.crop.circle", name: "登录",
                         desc: "正在开发中，敬请期待") {
                        devBadge
                    }
                }
                sgrp("权限与关于") {
                    srow(icon: "shield", name: "完全磁盘访问权限",
                         desc: appState.permissionGranted ? "已授予" : "未授予，应用缓存与残留清理受限") {
                        if !appState.permissionGranted {
                            Button("去授权") { openFDA() }
                                .buttonStyle(.plain)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(theme.colors.accent)
                        }
                    }
                    srow(icon: "doc", name: "Sweep v\(appState.appVersion)",
                         desc: "当前版本") {
                        Button("检查更新") { isPresented = false; onCheckUpdate() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(theme.colors.accent)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    /// 分组只留一条小标题 + 细分隔线，不套卡片（设计稿：设置的每一项属于同一件事）
    private func sgrp(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(theme.colors.text2)
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            VStack(spacing: 0) { content() }
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
                    .foregroundStyle(theme.colors.text0)
                Text(desc)
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.colors.text2)
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

    // MARK: - 「开发中」徽标：登录模块占位，不可点击
    private var devBadge: some View {
        Text("开发中")
            .font(.system(size: 10.5))
            .foregroundStyle(theme.colors.text2)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Color.clear)
                    .overlay(Capsule().stroke(theme.colors.border, lineWidth: 1))
            )
    }

    // MARK: - 分段控件（对齐设计稿 .segd：面板底 + 选中项灰阶抬升，不用琥珀）
    /// 系统原生 segmented 在深色主题下文字发黑看不清，按设计稿自绘
    private var deleteSegment: some View {
        HStack(spacing: 2) {
            ForEach(DeleteMode.allCases, id: \.self) { m in
                let selected = (m == appState.deleteMode)
                Text(m.label)
                    .font(.system(size: 11.5, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? theme.colors.text0 : theme.colors.text2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selected ? theme.colors.elev : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(selected ? Color.white.opacity(0.06) : .clear, lineWidth: 1))
                    )
                    .onTapGesture { appState.deleteMode = m }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(theme.colors.panel)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(theme.colors.border, lineWidth: 1))
        )
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
