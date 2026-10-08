#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

# 默认值（可被环境变量覆盖，命令行参数优先级最高）
WORK_DIR="${WORK_DIR:-$SCRIPT_DIR/../output}"
APK_FILE="${APK_FILE:-$SCRIPT_DIR/../overlay_build/MyOemOverlay.apk}"
ZIP_NAME="${ZIP_NAME:-MyOemOverlay.zip}"
MODULE_ID="${MODULE_ID:-my_oem_overlay}"
MODULE_NAME="${MODULE_NAME:-My OEM Attestation Overlay}"
MODULE_VERSION="${MODULE_VERSION:-1.0}"
MODULE_VERSION_CODE="${MODULE_VERSION_CODE:-1}"
MODULE_AUTHOR="${MODULE_AUTHOR:-RGWS-LiuLai}"
MODULE_DESCRIPTION="${MODULE_DESCRIPTION:-Overlay to inject custom OEM attestation certificate. GitHub: https://github.com/RGWS-LiuLai | Coolapk: 恋勿思}"

usage() {
    cat <<'EOF'
用法 / Usage: 04_package_module.sh [选项]

选项 / Options:
  --apk <file>          APK 文件路径 / Path to the APK file
  --work-dir <dir>      输出目录 / Output working directory
  --zip-name <name>     输出 ZIP 文件名 / Output ZIP file name
  --id <id>             模块 id / Module id
  --name <name>         模块名称 / Module name
  --version <ver>       模块版本 / Module version
  --version-code <code> 模块版本号 / Module versionCode
  --author <author>     模块作者 / Module author
  --description <desc>  模块描述 / Module description
  -h, --help            显示帮助 / Show this help

也可通过同名环境变量覆盖默认值 / Values can also be overridden via environment variables.
EOF
}

# 命令行参数解析（优先级最高）
while [ $# -gt 0 ]; do
    case "$1" in
        --apk) APK_FILE="${2:?--apk 需要一个参数 / requires an argument}"; shift 2 ;;
        --work-dir) WORK_DIR="${2:?--work-dir 需要一个参数 / requires an argument}"; shift 2 ;;
        --zip-name) ZIP_NAME="${2:?--zip-name 需要一个参数 / requires an argument}"; shift 2 ;;
        --id) MODULE_ID="${2:?--id 需要一个参数 / requires an argument}"; shift 2 ;;
        --name) MODULE_NAME="${2:?--name 需要一个参数 / requires an argument}"; shift 2 ;;
        --version) MODULE_VERSION="${2:?--version 需要一个参数 / requires an argument}"; shift 2 ;;
        --version-code) MODULE_VERSION_CODE="${2:?--version-code 需要一个参数 / requires an argument}"; shift 2 ;;
        --author) MODULE_AUTHOR="${2:?--author 需要一个参数 / requires an argument}"; shift 2 ;;
        --description) MODULE_DESCRIPTION="${2:?--description 需要一个参数 / requires an argument}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "错误：未知参数：$1 / Error: Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

MODULE_DIR="$WORK_DIR/module_files"
OUTPUT_ZIP="$WORK_DIR/$ZIP_NAME"

if ! command -v zip >/dev/null 2>&1; then
    echo "错误：未安装 zip 命令，请先安装（pkg install zip）！ / Error: 'zip' not found, please install it first!"
    exit 1
fi

echo "检查 APK 文件是否存在... / Checking if APK file exists..."
if [ ! -f "$APK_FILE" ]; then
    echo "错误：找不到 $APK_FILE，无法打包模块！ / Error: Cannot find APK!"
    exit 1
fi

echo "正在构建模块结构... / Building module structure..."
if [ -n "$MODULE_DIR" ]; then
    rm -rf "$MODULE_DIR"
fi
mkdir -p "$MODULE_DIR/product/overlay/"
mkdir -p "$WORK_DIR"

# 注意：路径已由 system/product/overlay 改为 product/overlay ！
cp "$APK_FILE" "$MODULE_DIR/product/overlay/"

# 使用单行 echo 写入，完美避开 Linux/Termux 输入法截断换行的问题
echo "id=$MODULE_ID" > "$MODULE_DIR/module.prop"
echo "name=$MODULE_NAME" >> "$MODULE_DIR/module.prop"
echo "version=$MODULE_VERSION" >> "$MODULE_DIR/module.prop"
echo "versionCode=$MODULE_VERSION_CODE" >> "$MODULE_DIR/module.prop"
echo "author=$MODULE_AUTHOR" >> "$MODULE_DIR/module.prop"
echo "description=$MODULE_DESCRIPTION" >> "$MODULE_DIR/module.prop"

echo "正在打包 ZIP... / Packaging ZIP..."
rm -f "$OUTPUT_ZIP"
cd "$MODULE_DIR" || { echo "错误：无法进入目录 $MODULE_DIR！ / Error: Cannot enter directory!"; exit 1; }
zip -r "$OUTPUT_ZIP" .

if [ ! -f "$OUTPUT_ZIP" ]; then
    echo "错误：打包失败，ZIP 未生成！ / Error: Failed to create ZIP!"
    exit 1
fi

echo "打包完成！ / Packaging complete!"
echo "文件位置 / File location: $OUTPUT_ZIP"
