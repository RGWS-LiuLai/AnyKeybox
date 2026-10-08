#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

# ============================================================
# 可配置参数：命令行 > 环境变量 > 原值默认
# ============================================================
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BASE_DIR="${AK_BASE_DIR:-$SCRIPT_DIR/..}"
KEYS_DIR="${AK_KEYS_DIR:-$BASE_DIR/keys}"
KEYBOX_INPUT_DIR="${AK_KEYBOX_INPUT_DIR:-$BASE_DIR/keybox_input}"
OVERLAY_BUILD_DIR="${AK_OVERLAY_BUILD_DIR:-$BASE_DIR/overlay_build}"
OUTPUT_DIR="${AK_OUTPUT_DIR:-$BASE_DIR/output}"
MIRROR_URL="${AK_MIRROR_URL:-https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main}"
MIRROR_SUITE="${AK_MIRROR_SUITE:-stable}"
MIRROR_COMPONENT="${AK_MIRROR_COMPONENT:-main}"
FRAMEWORK_APK_SRC="${AK_FRAMEWORK_APK:-/system/framework/framework-res.apk}"
FRAMEWORK_APK_MODE="${AK_FRAMEWORK_APK_MODE:-666}"
SU_CMD="${AK_SU_CMD:-su}"

# 交互控制（默认保持原脚本行为：交互提示，默认不换源）
ASSUME_YES="${ASSUME_YES:-0}"
FORCE_MIRROR="${FORCE_MIRROR:-0}"
FORCE_NO_MIRROR="${FORCE_NO_MIRROR:-0}"

usage() {
    cat <<'EOF'
用法 / Usage: 01_setup_env.sh [选项]

选项 / Options:
  --prefix DIR        Termux PREFIX 路径 (默认: $PREFIX 或 /data/data/com.termux/files/usr)
  --base-dir DIR      项目根目录 (默认: 脚本所在目录的上一级)
  --keys-dir DIR      keys 目录
  --keybox-input-dir DIR   keybox_input 目录
  --overlay-build-dir DIR  overlay_build 目录
  --output-dir DIR    output 目录
  --mirror-url URL    国内镜像源地址 (默认: 清华源)
  --mirror-suite S    镜像套件 (默认: stable)
  --mirror-component C    镜像组件 (默认: main)
  --framework-apk PATH    系统 framework-res.apk 源路径
  --su-cmd CMD        提权命令 (默认: su)
  -m, --mirror        强制切换镜像源（跳过交互）
  -M, --no-mirror     强制不换源（跳过交互）
  -y, --yes           对所有交互自动回答"是"
  -h, --help          显示本帮助

环境变量 / Env vars: AK_BASE_DIR, AK_KEYS_DIR, AK_KEYBOX_INPUT_DIR,
  AK_OVERLAY_BUILD_DIR, AK_OUTPUT_DIR, AK_MIRROR_URL, AK_MIRROR_SUITE,
  AK_MIRROR_COMPONENT, AK_FRAMEWORK_APK, AK_SU_CMD, PREFIX
EOF
}

# ---------------- 命令行参数解析 ----------------
while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)              PREFIX="${2:?--prefix 需要一个参数}"; shift 2 ;;
        --base-dir)            BASE_DIR="${2:?--base-dir 需要一个参数}"; shift 2 ;;
        --keys-dir)            KEYS_DIR="${2:?--keys-dir 需要一个参数}"; shift 2 ;;
        --keybox-input-dir)    KEYBOX_INPUT_DIR="${2:?--keybox-input-dir 需要一个参数}"; shift 2 ;;
        --overlay-build-dir)   OVERLAY_BUILD_DIR="${2:?--overlay-build-dir 需要一个参数}"; shift 2 ;;
        --output-dir)          OUTPUT_DIR="${2:?--output-dir 需要一个参数}"; shift 2 ;;
        --mirror-url)          MIRROR_URL="${2:?--mirror-url 需要一个参数}"; shift 2 ;;
        --mirror-suite)        MIRROR_SUITE="${2:?--mirror-suite 需要一个参数}"; shift 2 ;;
        --mirror-component)    MIRROR_COMPONENT="${2:?--mirror-component 需要一个参数}"; shift 2 ;;
        --framework-apk)       FRAMEWORK_APK_SRC="${2:?--framework-apk 需要一个参数}"; shift 2 ;;
        --su-cmd)              SU_CMD="${2:?--su-cmd 需要一个参数}"; shift 2 ;;
        -m|--mirror)           FORCE_MIRROR=1; shift ;;
        -M|--no-mirror)        FORCE_NO_MIRROR=1; shift ;;
        -y|--yes)              ASSUME_YES=1; shift ;;
        -h|--help)             usage; exit 0 ;;
        *) echo "错误 / Error: 未知参数 / unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# 选择包管理器：优先 pkg，缺失时回退 apt
if command -v pkg >/dev/null 2>&1; then
    PKG_MGR=(pkg)
else
    PKG_MGR=("${PREFIX}/bin/apt" apt)
    command -v apt >/dev/null 2>&1 || PKG_MGR=("${PREFIX}/bin/apt")
fi

# 自动创建所需文件夹 (在项目根目录下)
mkdir -p -- "$KEYS_DIR" "$KEYBOX_INPUT_DIR" "$OVERLAY_BUILD_DIR" "$OUTPUT_DIR"

echo "=== 正在智能检测环境依赖 / Smart detecting environment dependencies ==="
MISSING_PKGS=()

# 命令 -> Termux 包名 映射（便于维护，避免重复 if）
DEP_CMDS=(openssl aapt2 apksigner zip java python3)
DEP_PKGS=(openssl-tool aapt2 apksigner zip openjdk-21 python3)

for _i in "${!DEP_CMDS[@]}"; do
    if ! command -v "${DEP_CMDS[$_i]}" >/dev/null 2>&1; then
        MISSING_PKGS+=("${DEP_PKGS[$_i]}")
    fi
done
unset _i

if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
    echo "检测到缺失依赖 / Missing dependencies detected: ${MISSING_PKGS[*]}"

    # 决定是否换源：强制项 > 交互提示（默认 N，-y 自动确认）
    if [ "$FORCE_MIRROR" -eq 1 ]; then
        use_cn_mirror="y"
    elif [ "$FORCE_NO_MIRROR" -eq 1 ]; then
        use_cn_mirror=""
    elif [ "$ASSUME_YES" -eq 1 ]; then
        use_cn_mirror="y"
    else
        read -r -p "是否需要切换为国内镜像源(清华)以加速下载? / Do you want to switch to a Chinese mirror (Tsinghua) for faster download? [y/N]: " use_cn_mirror || use_cn_mirror=""
    fi

    if [[ "$use_cn_mirror" =~ ^[Yy]$ ]]; then
        echo "正在配置清华镜像源... / Configuring Tsinghua mirror..."
        # 备份原 sources.list（mktemp 避免覆盖已有备份）
        SRC_LIST="$PREFIX/etc/apt/sources.list"
        SRC_BAK=""
        if [ -f "$SRC_LIST" ]; then
            SRC_BAK="$(mktemp "$SRC_LIST.bak.XXXXXX")" || SRC_BAK=""
            [ -n "$SRC_BAK" ] && cp -- "$SRC_LIST" "$SRC_BAK" 2>/dev/null || SRC_BAK=""
        fi
        [ -n "$SRC_BAK" ] && echo "已备份原源列表到 / Backed up sources.list to: $SRC_BAK"
        # 清空第三方源，写入镜像源
        rm -f -- "$PREFIX"/etc/apt/sources.list.d/*.list 2>/dev/null || true
        printf 'deb %s %s %s\n' "$MIRROR_URL" "$MIRROR_SUITE" "$MIRROR_COMPONENT" > "$SRC_LIST"
        "${PKG_MGR[@]}" update -y
    else
        echo "跳过换源，使用当前默认源安装。/ Skipping mirror switch, using default source."
    fi
    echo "开始安装缺失依赖... / Installing missing dependencies..."
    # shellcheck disable=SC2068
    "${PKG_MGR[@]}" install -y ${MISSING_PKGS[@]+"${MISSING_PKGS[@]}"}
else
    echo "所有环境依赖均已安装，跳过 pkg install 和换源环节。/ All dependencies installed, skipping."
fi

echo "=== 检查并提取 framework-res.apk / Checking and extracting framework-res.apk ==="
FRAMEWORK_APK_DST="$OVERLAY_BUILD_DIR/framework-res.apk"
if [ ! -f "$FRAMEWORK_APK_DST" ]; then
    echo "正在提取系统 framework-res.apk 作为 aapt2 链接库... / Extracting system framework-res.apk..."
    if ! command -v "$SU_CMD" >/dev/null 2>&1; then
        echo "错误 / Error: 未找到提权命令 / su command not found: $SU_CMD" >&2
        exit 1
    fi
    # 合并为一次提权调用：复制 + 授权
    # shellcheck disable=SC2016
    "$SU_CMD" -c 'cp "$1" "$2" && chmod "$3" "$2"' su \
        "$FRAMEWORK_APK_SRC" "$FRAMEWORK_APK_DST" "$FRAMEWORK_APK_MODE"
fi
echo "环境准备完成！/ Environment setup complete!"
