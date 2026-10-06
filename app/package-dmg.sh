#!/bin/zsh
# 将 Sweep.app 打包成可安装的 .dmg
# 用法：cd app && ./package-dmg.sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/build/Sweep.app"
DMG="$DIR/build/Sweep.dmg"
VOL="Sweep"
STAGE="/tmp/sweep-dmg-$$"

# 1. 确保应用已构建
if [[ ! -d "$APP" ]]; then
    echo "▸ 先构建 Sweep.app…"
    "$DIR/build.sh"
fi

# 2. 准备 DMG 内容
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# 3. 创建临时可读写的 DMG（容量按 app 大小 + 留白）
APP_SIZE=$(du -sm "$APP" | cut -f1)
SIZE=$((APP_SIZE + 12))m   # 额外 12MB 给 alias 和文件系统开销
TMP_DMG="/tmp/sweep-rw-$$.dmg"
rm -f "$TMP_DMG" "$DMG"

echo "▸ 创建临时 DMG（${SIZE}）…"
hdiutil create -size "$SIZE" -fs HFS+ -volname "$VOL" -o "$TMP_DMG" >/dev/null

# 4. 挂载并拷贝
MOUNT=$(hdiutil attach -noverify -noautoopen "$TMP_DMG" | grep -o '/Volumes/[^ ]*' | head -1)
[[ -n "$MOUNT" ]] || { echo "✗ 挂载 DMG 失败"; exit 1; }

cp -R "$STAGE/"* "$MOUNT/"

# 5. 设置卷图标（.VolumeIcon.icns）
if [[ -f "$DIR/Resources/Sweep.icns" ]]; then
    cp "$DIR/Resources/Sweep.icns" "$MOUNT/.VolumeIcon.icns"
    bless --folder "$MOUNT" --openfolder "$MOUNT" >/dev/null 2>&1 || true
fi

# 6. 用 AppleScript 设置 Finder 视图与图标位置（best effort，headless 环境可能失败但不影响功能）
osascript <<'APPLE' >/dev/null 2>&1 || true
tell application "Finder"
    set dmg to disk "Sweep"
    open dmg
    set win to window of dmg
    set current view of win to icon view
    set toolbar visible of win to false
    set statusbar visible of win to false
    set bounds of win to {200, 120, 720, 440}
    set icon size of icon view options of win to 96
    set text size of icon view options of win to 12
    set arrangement of icon view options of win to not arranged
    set position of item "Sweep.app" of dmg to {120, 150}
    set position of item "Applications" of dmg to {360, 150}
    close win
end tell
APPLE

# 7. 卸载并压缩
echo "▸ 压缩 DMG…"
hdiutil detach "$MOUNT" -force >/dev/null
hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG" >/dev/null

# 8. 清理
rm -f "$TMP_DMG"
rm -rf "$STAGE"

DMG_SIZE=$(du -sh "$DMG" | cut -f1)
echo "✓ 完成：$DMG（$DMG_SIZE）"
