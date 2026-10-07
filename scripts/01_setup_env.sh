#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

# 自动创建所需文件夹 (在项目根目录下)
mkdir -p "$SCRIPT_DIR/../keys" "$SCRIPT_DIR/../keybox_input" "$SCRIPT_DIR/../overlay_build" "$SCRIPT_DIR/../output"

echo "=== 正在智能检测环境依赖 / Smart detecting environment dependencies ==="
MISSING_PKGS=()

if ! command -v openssl >/dev/null 2>&1; then MISSING_PKGS+=(openssl-tool); fi
if ! command -v aapt2 >/dev/null 2>&1; then MISSING_PKGS+=(aapt2); fi
if ! command -v apksigner >/dev/null 2>&1; then MISSING_PKGS+=(apksigner); fi
if ! command -v zip >/dev/null 2>&1; then MISSING_PKGS+=(zip); fi
if ! command -v java >/dev/null 2>&1; then MISSING_PKGS+=(openjdk-21); fi
if ! command -v python3 >/dev/null 2>&1; then MISSING_PKGS+=(python3); fi

if [ "${#MISSING_PKGS[@]}" -gt 0 ]; then
    echo "检测到缺失依赖 / Missing dependencies detected: ${MISSING_PKGS[*]}"
    read -r -p "是否需要切换为国内镜像源(清华)以加速下载? / Do you want to switch to a Chinese mirror (Tsinghua) for faster download? [y/N]: " use_cn_mirror || use_cn_mirror=""
    if [[ "$use_cn_mirror" =~ ^[Yy]$ ]]; then
        echo "正在配置清华镜像源... / Configuring Tsinghua mirror..."
        cp "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.bak" 2>/dev/null || true
        rm -f "$PREFIX"/etc/apt/sources.list.d/*.list 2>/dev/null || true
        echo "deb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main" > "$PREFIX/etc/apt/sources.list"
        pkg update -y
    else
        echo "跳过换源，使用当前默认源安装。/ Skipping mirror switch, using default source."
    fi
    echo "开始安装缺失依赖... / Installing missing dependencies..."
    pkg install -y "${MISSING_PKGS[@]}"
else
    echo "所有环境依赖均已安装，跳过 pkg install 和换源环节。/ All dependencies installed, skipping."
fi

echo "=== 检查并提取 framework-res.apk / Checking and extracting framework-res.apk ==="
if [ ! -f "$SCRIPT_DIR/../overlay_build/framework-res.apk" ]; then
    echo "正在提取系统 framework-res.apk 作为 aapt2 链接库... / Extracting system framework-res.apk..."
    su -c "cp /system/framework/framework-res.apk '$SCRIPT_DIR/../overlay_build/framework-res.apk'"
    su -c "chmod 666 '$SCRIPT_DIR/../overlay_build/framework-res.apk'"
fi
echo "环境准备完成！/ Environment setup complete!"
