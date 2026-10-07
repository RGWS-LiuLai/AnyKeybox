#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$SCRIPT_DIR/../output"
MODULE_DIR="$WORK_DIR/module_files"
APK_FILE="$SCRIPT_DIR/../overlay_build/MyOemOverlay.apk"

echo "检查 APK 文件是否存在... / Checking if APK file exists..."
if [ ! -f "$APK_FILE" ]; then
    echo "错误：找不到 $APK_FILE，无法打包模块！ / Error: Cannot find APK!"
    exit 1
fi

echo "正在构建模块结构... / Building module structure..."
rm -rf "$MODULE_DIR"
mkdir -p "$MODULE_DIR/product/overlay/"

# 注意：路径已由 system/product/overlay 改为 product/overlay ！
cp "$APK_FILE" "$MODULE_DIR/product/overlay/"

# 使用单行 echo 写入，完美避开 Linux/Termux 输入法截断换行的问题
echo "id=my_oem_overlay" > "$MODULE_DIR/module.prop"
echo "name=My OEM Attestation Overlay" >> "$MODULE_DIR/module.prop"
echo "version=1.0" >> "$MODULE_DIR/module.prop"
echo "versionCode=1" >> "$MODULE_DIR/module.prop"
echo "author=RGWS-LiuLai" >> "$MODULE_DIR/module.prop"
echo "description=Overlay to inject custom OEM attestation certificate. GitHub: https://github.com/RGWS-LiuLai | Coolapk: 恋勿思" >> "$MODULE_DIR/module.prop"

echo "正在打包 ZIP... / Packaging ZIP..."
rm -f "$WORK_DIR/MyOemOverlay.zip"
cd "$MODULE_DIR"
zip -r ../MyOemOverlay.zip .

if [ ! -f "$WORK_DIR/MyOemOverlay.zip" ]; then
    echo "错误：打包失败，ZIP 未生成！ / Error: Failed to create ZIP!"
    exit 1
fi

echo "打包完成！ / Packaging complete!"
echo "文件位置 / File location: $WORK_DIR/MyOemOverlay.zip"
