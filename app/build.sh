#!/bin/zsh
# Sweep 构建：编译 SwiftUI 源码 → 组装 .app（含内置 Mole 引擎与素材）→ ad-hoc 签名
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/build/Sweep.app"
BIN="$APP/Contents/MacOS/Sweep"
TARGET="arm64-apple-macos13.0"

echo "▸ 编译 Swift 源码…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library \
  -target "$TARGET" \
  "$DIR"/Sources/*.swift "$DIR"/Sources/Views/*.swift \
  -o "$BIN"

echo "▸ 装配资源…"
cp "$DIR/Resources/Info.plist"  "$APP/Contents/Info.plist"
cp "$DIR/Resources/Sweep.icns"  "$APP/Contents/Resources/Sweep.icns"
# 极简科技主题图标
if [[ -f "$DIR/Resources/SweepMinimalLight.icns" ]]; then
  cp "$DIR/Resources/SweepMinimalLight.icns" "$APP/Contents/Resources/SweepMinimalLight.icns"
fi
if [[ -f "$DIR/Resources/SweepMinimalDark.icns" ]]; then
  cp "$DIR/Resources/SweepMinimalDark.icns" "$APP/Contents/Resources/SweepMinimalDark.icns"
fi
cp -R "$DIR/Resources/assets"   "$APP/Contents/Resources/assets"
cp -R "$DIR/Resources/fonts"    "$APP/Contents/Resources/fonts"
cp -R "$DIR/Resources/mole"     "$APP/Contents/Resources/mole"

# 合规：把引擎许可与来源说明放在包内显眼处
cp "$DIR/Resources/mole/LICENSE"       "$APP/Contents/Resources/LICENSE-Mole.txt"
cp "$DIR/Resources/mole/TRADEMARK.md"  "$APP/Contents/Resources/TRADEMARK-Mole.md"

echo "▸ 校验引擎可执行…"
[[ -x "$APP/Contents/Resources/mole/bin/clean.sh" ]] || {
  echo "内置引擎不可执行"; exit 1
}
[[ -f "$APP/Contents/Resources/fonts/SweepRound.ttf" ]] || {
  echo "圆体缺失"; exit 1
}

echo "▸ 校验 Info.plist…"
plutil -lint "$APP/Contents/Info.plist" > /dev/null

echo "▸ ad-hoc 签名…"
codesign --force --deep --sign - "$APP" 2>&1 | tail -2
codesign --verify --verbose=1 "$APP" 2>&1 | tail -2

SIZE=$(du -sh "$APP" | cut -f1)
echo "✓ 完成：$APP（$SIZE）"
