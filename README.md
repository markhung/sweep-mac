# Sweep

一个二次元猫系少女风格的 macOS 清理工具原生 GUI，封装了开源命令行清理引擎 [Mole](https://github.com/tw93/Mole)。

![开始界面](prototype/assets/mascot-idle.png)

> 核心交互：点击「开始」→ 执行清理 → 实时展示日志 → 展示结果。

## 特性

- **原生 SwiftUI**：仅用 Command Line Tools 构建，产物小巧。
- **内置 Mole 引擎**：直接调用 `mole/bin/clean.sh`，无需额外安装。
- **用户级清理**：非交互模式下只清理用户目录，不会索要管理员密码。
- **实时进度**：进度圆环 + 百分比 + 实时释放量 + 猫娘打气。
- **完全磁盘访问权限引导**：首次启动引导用户授权，扫得更干净。
- **DMG 安装包**：一键拖拽安装。

## 安装

1. 在 [Releases](https://github.com/markhung/sweep-mac/releases) 下载最新 `Sweep.dmg`。
2. 双击挂载 DMG，把 `Sweep.app` 拖到「应用程序」。
3. 首次打开请在 Finder 中右键 `Sweep.app` →「打开」，并在「系统设置 → 隐私与安全性」中允许。

## 构建

需要 macOS Command Line Tools：

```bash
cd app
./build.sh          # 编译 Sweep.app
./package-dmg.sh    # 打包成 Sweep.dmg
```

产物位于 `app/build/Sweep.app` 与 `app/build/Sweep.dmg`。

## 测试

```bash
cd app
# 解析器回归 + 分片一致性测试
swiftc -O -parse-as-library -target arm64-apple-macos13.0 \
  Sources/*.swift Sources/Views/*.swift Tests/parser/main.swift \
  -o build/parse_test && ./build/parse_test

# FDA 权限判定单元测试
swiftc -O -target arm64-apple-macos13.0 \
  Sources/Permission.swift Tests/permission/main.swift \
  -o build/permission_test && ./build/permission_test

# 真实 bundle 环境自检（预览模式跑一遍引擎，不删文件）
./build/Sweep.app/Contents/MacOS/Sweep --selftest
```

## 开源合规

本项目基于 [Mole](https://github.com/tw93/Mole)（GPL-3.0）构建。Mole 的源码副本位于：

- `mole-src/` —— 上游完整源码（commit `b8180ab`）
- `app/Resources/mole/` —— 内置到 App 中的运行副本

Sweep 本身亦以 **GPL-3.0** 开源，详见 [LICENSE](LICENSE)。

根据 Mole 的 [TRADEMARK.md](mole-src/TRADEMARK.md)，本项目未使用 "Mole" 名称或图标，也不暗示任何官方背书。

## 第三方素材

- 圆体：「站酷庆科黄油体」(ZCOOL QingKe HuangYou)，OFL 开源字体。
- 猫系少女立绘与背景：AI 生成，仅用于本项目。
