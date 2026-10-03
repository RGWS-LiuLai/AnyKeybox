#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

KEYBOX_PATH="$SCRIPT_DIR/keybox_input/keybox.xml"

# 检查 keybox.xml 是否存在 / Check if keybox.xml exists
if [ ! -f "$KEYBOX_PATH" ]; then
    echo "========================================================"
    echo "  错误：找不到 keybox.xml / Error: keybox.xml not found"
    echo "  请将 keybox.xml 放入以下文件夹 / Please put keybox.xml into:"
    echo "  $SCRIPT_DIR/keybox_input/"
    echo "  确保文件名严格为 keybox.xml / Ensure the filename is exactly keybox.xml"
    echo "========================================================"
    exit 1
fi

chmod +x *.sh

echo "=== 步骤 1: 准备环境 / Step 1: Preparing environment ==="
bash 01_setup_env.sh
echo "=== 步骤 2: 从 Keybox 提取根证书 / Step 2: Extracting root certificate from Keybox ==="
bash 02_extract_cert.sh
echo "=== 步骤 3: 编译并签名 APK / Step 3: Building and signing APK ==="
bash 03_build_overlay.sh
echo "=== 步骤 4: 打包模块 / Step 4: Packaging module ==="
bash 04_package_module.sh

echo "========================================================"
echo "全部完成！/ All done!"
echo "请前往以下目录提取 MyOemOverlay.zip 刷入 / Extract MyOemOverlay.zip to flash:"
echo "$SCRIPT_DIR/output"
echo "========================================================"
echo "作者 / Author: RGWS-LiuLai (酷安: 恋勿思)"
echo "GitHub: https://github.com/RGWS-LiuLai"
echo "酷安主页 / Coolapk Profile: https://www.coolapk.com/u/28676823"
echo "========================================================"
echo "感谢名单 / Special Thanks:"
echo "感谢 ITxiao6666 捐赠三星 keybox.xml"
echo "GitHub: https://github.com/ITxiao6666"
echo "酷安 / Coolapk: 阿奎亚"
echo "酷安主页 / Coolapk Profile: https://www.coolapk.com/u/31943847"
echo "（注：以上仅为致谢，未参与开发 / Note: Acknowledgment only, not involved in development）"
echo "========================================================"