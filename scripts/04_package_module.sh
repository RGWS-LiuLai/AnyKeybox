#!/data/data/com.termux/files/usr/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$SCRIPT_DIR/output"
MODULE_DIR="$WORK_DIR/module_files"
APK_FILE="$SCRIPT_DIR/overlay_build/MyOemOverlay.apk"

echo "检查 APK 文件是否存在... / Checking if APK file exists..."
if [ ! -f "$APK_FILE" ]; then
    echo "错误：找不到 $APK_FILE，无法打包模块！ / Error: Cannot find $APK_FILE, unable to package module!"
    exit 1
fi

echo "正在构建模块结构... / Building module structure..."
rm -rf "$MODULE_DIR"
mkdir -p "$MODULE_DIR/system/product/overlay/"
cp "$APK_FILE" "$MODULE_DIR/system/product/overlay/"

cat > "$MODULE_DIR/module.prop" << 'EOF'
id=my_oem_overlay
name=My OEM Attestation Overlay
version=1.0
versionCode=1
author=RGWS-LiuLai
description=Overlay to inject custom OEM attestation certificate. GitHub: https://github.com/RGWS-LiuLai | Coolapk: 恋勿思
EOF

echo "正在打包 ZIP... / Packaging ZIP..."
cd "$MODULE_DIR"
zip -r ../MyOemOverlay.zip ./*

echo "打包完成！ / Packaging complete!"
echo "文件位置 / File location: $WORK_DIR/MyOemOverlay.zip"