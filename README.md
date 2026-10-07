# Sweep

macOS 深度清理工具 Sweep 的原生 GUI，封装开源命令行清理引擎 [Mole](https://github.com/tw93/Mole)。

界面遵循项目内「Sweep 设计系统 v1.0」：琥珀色信号 + 暖石墨深色仪表风，单窗口三视图（权限引导 / 主界面 / 设置），四个清理状态共用同一骨架。早期二次元猫系主题的代码与素材仍随包保留，但默认不启用，UI 也不提供切换入口。

## 特性

- **原生 SwiftUI**：仅用 Command Line Tools + 裸 `swiftc` 构建，无 Xcode 工程，产物 7MB。
- **内置 Mole 引擎**：直接调用 `mole/bin/clean.sh`，无需额外安装；清理方式支持「直接删除 / 移至废纸篓」。
- **点击即清理，无扫描阶段**：待机态用 6 个分类胶囊交代清理范围与安全承诺，按下按钮直接开始。
- **滚动明细**：mole 终端式的日志流逐行追加（`➤` 模块头 / `✓` 清理 / `◎` 跳过 / `⊙` 手动），自动跟随到底；完成后明细先停留 480ms 让最后一行对勾落地，再换上结果摘要（释放量 · 项目数 · 分类数 · 磁盘前后），可随时「查看明细」展开。
- **诚实的读数**：待机不预填任何数字（「待清理 —」）；清理中读「已释放」实时增长；结果页磁盘空间报「从多少变成多少」。
- **完全磁盘访问权限引导**：独立一屏讲清为什么需要、在哪开、不给会怎样，可稍后再说。
- **可随时中止**：强制停止前弹确认层，带实时数字（已释放多少、几项完成），回车默认落在安全侧「继续清理」。
- **用户级清理**：非交互模式只清理用户目录，不索要管理员密码；全程本机完成，不联网。
- **菜单栏常驻（可选）**：`defaults write com.sweep.app Sweep.showInMenuBar -bool true` 后重启，标题栏外会出现 sparkle 状态项图标。

当前版本 **v1.1.0**（设置里的「登录」为占位模块，开发中）。

## 安装

1. 在 [Releases](https://github.com/markhung/sweep-mac/releases) 下载最新 `Sweep.dmg`。
2. 双击挂载 DMG，把 `Sweep.app` 拖到「应用程序」。
3. 首次打开请在 Finder 中右键 `Sweep.app` →「打开」，并在「系统设置 → 隐私与安全性」中允许。

## 构建

需要 macOS Command Line Tools：

```bash
cd app
./build.sh          # 编译 Sweep.app（含内置引擎与素材装配、ad-hoc 签名）
./package-dmg.sh    # 打包成 Sweep.dmg
```

产物位于 `app/build/Sweep.app` 与 `app/build/Sweep.dmg`。

## 测试

```bash
cd app

# 解析器回归 + 分片一致性测试
# 注意：测试文件含顶层语句，不能用 -parse-as-library；
# 也只需编译解析器依赖的最小集合，避免混入带 @main 入口的 App 源码。
swiftc -O -target arm64-apple-macos13.0 \
  Sources/Models.swift Sources/MoleText.swift Sources/StreamParser.swift \
  Tests/parser/main.swift \
  -o build/parse_test && ./build/parse_test

# FDA 权限判定单元测试
swiftc -O -target arm64-apple-macos13.0 \
  Sources/Permission.swift Tests/permission/main.swift \
  -o build/permission_test && ./build/permission_test

# 离屏快照自检：把真实引擎输出喂进 AppState，渲染全部视图状态为 PNG
# （含主界面四态、权限引导四屏、设置视图，用于和设计稿逐张比对）
SRC=$(ls Sources/*.swift | grep -v SweepApp.swift)
swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos13.0 \
  ${=SRC} Sources/Views/*.swift Tests/render/RenderMain.swift \
  -o build/render_check
./build/render_check /tmp/sweep-dryrun.txt build/snapshots

# QA UI 级行为验证：权限引导状态机、提示条互斥、遮挡证明、字体子集覆盖
swiftc -O -parse-as-library -swift-version 5 -target arm64-apple-macos13.0 \
  ${=SRC} Sources/Views/*.swift Tests/qa_ui/main.swift \
  -o build/qa_ui && ./build/qa_ui

# 真实 bundle 环境自检（预览模式跑一遍引擎，不删文件）
./build/Sweep.app/Contents/MacOS/Sweep --selftest
```

## 安全模型

- 全程无网络代码；清理动作全部在捆绑引擎内完成，进程为参数数组式调用，无 shell 插值。
- 仅用户级权限，不索要管理员密码；删除范围由系统权限（完全磁盘访问）决定，不开放逐类勾选。
- 引擎输出仅用于展示层渲染，不参与任何后续删除目标的构造。

## 开源合规

本项目基于 [Mole](https://github.com/tw93/Mole)（GPL-3.0）构建。Mole 的源码副本位于：

- `mole-src/` —— 上游完整源码（commit `b8180ab`）
- `app/Resources/mole/` —— 内置到 App 中的运行副本

Sweep 本身亦以 **GPL-3.0** 开源，详见 [LICENSE](LICENSE)。

根据 Mole 的 [TRADEMARK.md](mole-src/TRADEMARK.md)，本项目未使用 "Mole" 名称或图标，也不暗示任何官方背书。
