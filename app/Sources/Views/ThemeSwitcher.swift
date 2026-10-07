import SwiftUI

struct ThemeSwitcher: View {
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        Picker("主题", selection: Binding(
            get: { themeManager.selectedTheme },
            set: { themeManager.selectTheme($0) }
        )) {
            Text("猫系主题").tag(AppTheme.anime)
            Text("极简科技").tag(AppTheme.minimal)
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
        .help("切换界面主题")
    }
}
