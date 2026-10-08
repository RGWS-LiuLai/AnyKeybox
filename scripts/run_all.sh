#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ================================================================
# 参数化优先级: 命令行 > 环境变量 > 原值默认
#   $1                       : keybox 文件路径 (可选)
#   $2                       : keybox 输入目录 (可选)
#   KEYBOX_FILE              : 环境变量, keybox 文件路径
#   KEYBOX_INPUT_DIR         : 环境变量, keybox 输入目录
#   KEYBOX_NAME_PATTERN      : 环境变量, 文件名匹配正则 (ERE, 不区分大小写)
#   OUTPUT_DIR               : 环境变量, 输出目录
#   RUN_SHELL                : 环境变量, 子脚本解释器
# ================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 子脚本解释器 (默认与原脚本一致: bash)
RUN_SHELL="${RUN_SHELL:-bash}"

# keybox 输入目录 (默认与原脚本一致)
INPUT_DIR="${2:-${KEYBOX_INPUT_DIR:-$SCRIPT_DIR/../keybox_input}}"

# 文件名匹配正则 (默认与原脚本一致)
KEYBOX_NAME_PATTERN="${KEYBOX_NAME_PATTERN:-/(key|gay|sex)box\.xml$}"

# 输出目录 (默认与原脚本一致)
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/../output}"

# 查找 keybox 文件，不区分大小写，支持各种奇怪的名字
# keybox 文件路径: 命令行 > 环境变量 > 自动查找
KEYBOX_FILE="${1:-${KEYBOX_FILE:-}}"

if [ -z "$KEYBOX_FILE" ]; then
    echo "正在查找 keybox 文件... / Searching for keybox file..."
    mkdir -p "$INPUT_DIR"
    # 命令组 + || true: 规避 pipefail 下 find/head 的 SIGPIPE 非零返回
    KEYBOX_FILE="$({ find "$INPUT_DIR" -maxdepth 1 -type f 2>/dev/null \
        | LC_ALL=C grep -iE "$KEYBOX_NAME_PATTERN" \
        | head -1; } || true)"

    if [ -z "$KEYBOX_FILE" ]; then
        echo "========================================================"
        echo "  错误：找不到 keybox.xml / Error: keybox.xml not found"
        echo "  请将 keybox.xml（或 gaybox.xml / sexbox.xml）放入以下文件夹 / Please put the file into:"
        echo "  $INPUT_DIR"
        echo "  文件名不区分大小写 / Filename is case-insensitive"
        echo "========================================================"
        exit 1
    fi
else
    # 显式指定文件时校验存在性, 给出明确错误
    if [ ! -f "$KEYBOX_FILE" ]; then
        echo "========================================================"
        echo "  错误：找不到 keybox.xml / Error: keybox.xml not found"
        echo "  指定的文件不存在 / Specified file does not exist:"
        echo "  $KEYBOX_FILE"
        echo "========================================================"
        exit 1
    fi
    mkdir -p "$INPUT_DIR"
fi
echo "已找到文件 / Found file: $KEYBOX_FILE"


echo "=== 步骤 1: 准备环境 / Step 1: Preparing environment ==="
"$RUN_SHELL" "$SCRIPT_DIR/01_setup_env.sh"
echo "=== 步骤 2: 从 Keybox 提取根证书 / Step 2: Extracting root certificate from Keybox ==="
"$RUN_SHELL" "$SCRIPT_DIR/02_extract_cert.sh" "$KEYBOX_FILE"
echo "=== 步骤 3: 编译并签名 APK / Step 3: Building and signing APK ==="
"$RUN_SHELL" "$SCRIPT_DIR/03_build_overlay.sh"
echo "=== 步骤 4: 打包模块 / Step 4: Packaging module ==="
"$RUN_SHELL" "$SCRIPT_DIR/04_package_module.sh"

echo "========================================================"
echo "全部完成！/ All done!"
echo "请前往以下目录提取 MyOemOverlay.zip 刷入 / Extract MyOemOverlay.zip to flash:"
echo "$OUTPUT_DIR"
echo "========================================================"
echo "作者 / Author: RGWS-LiuLai (酷安: 恋勿思)"
echo "GitHub: https://github.com/RGWS-LiuLai"
echo "酷安主页 / Coolapk Profile: https://www.coolapk.com/u/28676823"
echo "========================================================"
echo "感谢名单 / Special Thanks:"
echo "感谢 ITxiao6666 捐赠三星 keybox.xml（非测试用途，纯赠送）"
echo "GitHub: https://github.com/ITxiao6666"
echo "酷安 / Coolapk: 阿奎亚"
echo "酷安主页 / Coolapk Profile: https://www.coolapk.com/u/31943847"
echo "（注：以上仅为致谢，未参与开发 / Note: Acknowledgment only, not involved in development）"
echo "========================================================"
