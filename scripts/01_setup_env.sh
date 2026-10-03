#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 自动创建所需文件夹
mkdir -p "$SCRIPT_DIR/keys" "$SCRIPT_DIR/keybox_input" "$SCRIPT_DIR/overlay_build" "$SCRIPT_DIR/output"

# 判断是否为 Termux 环境 / Check if it's Termux environment
IS_TERMUX=false
if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ]; then
    IS_TERMUX=true
fi

if $IS_TERMUX; then
    echo "=== 检测到 Termux 环境 / Detected Termux environment ==="
    MISSING_PKGS=""
    if ! command -v openssl >/dev/null 2>&1; then MISSING_PKGS="$MISSING_PKGS openssl-tool"; fi
    if ! command -v aapt2 >/dev/null 2>&1; then MISSING_PKGS="$MISSING_PKGS aapt2"; fi
    if ! command -v apksigner >/dev/null 2>&1; then MISSING_PKGS="$MISSING_PKGS apksigner"; fi
    if ! command -v zip >/dev/null 2>&1; then MISSING_PKGS="$MISSING_PKGS zip"; fi
    if ! command -v java >/dev/null 2>&1; then MISSING_PKGS="$MISSING_PKGS openjdk-21"; fi
    if ! command -v python3 >/dev/null 2>&1; then MISSING_PKGS="$MISSING_PKGS python3"; fi

    if [ -n "$MISSING_PKGS" ]; then
        echo "检测到缺失依赖:$MISSING_PKGS"
        read -p "是否需要切换为国内镜像源(清华)以加速下载? [y/N]: " use_cn_mirror
        if [[ "$use_cn_mirror" =~ ^[Yy]$ ]]; then
            cp $PREFIX/etc/apt/sources.list $PREFIX/etc/apt/sources.list.bak 2>/dev/null || true
            rm -f $PREFIX/etc/apt/sources.list.d/*.list 2>/dev/null || true
            echo "deb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main" > $PREFIX/etc/apt/sources.list
            pkg update -y
        fi
        pkg install $MISSING_PKGS -y
    else
        echo "所有环境依赖均已安装。/ All dependencies installed."
    fi
else
    echo "=== 检测到普通 Linux 环境 / Detected standard Linux environment ==="
    MISSING_TOOLS=""
    for tool in java aapt2 apksigner zip python3 openssl; do
        if ! command -v $tool >/dev/null 2>&1; then
            MISSING_TOOLS="$MISSING_TOOLS $tool"
        fi
    done
    if [ -n "$MISSING_TOOLS" ]; then
        echo "错误：当前 Linux 系统缺失以下工具：$MISSING_TOOLS"
        echo "请安装它们后再运行此脚本。"
        echo "例如在 Ubuntu/Debian 上: sudo apt install openjdk-17-jdk python3 zip openssl"
        echo "aapt2 和 apksigner 通常需要从 Android SDK Build-Tools 中获取，并加入 PATH。"
        exit 1
    fi
    echo "所有基本工具已就绪。/ All basic tools are ready."
fi

echo "=== 检查 framework-res.apk / Checking framework-res.apk ==="
if [ ! -f "$SCRIPT_DIR/overlay_build/framework-res.apk" ]; then
    if $IS_TERMUX; then
        echo "正在提取系统 framework-res.apk 作为 aapt2 链接库..."
        su -c "cp /system/framework/framework-res.apk $SCRIPT_DIR/overlay_build/"
        su -c "chmod 666 $SCRIPT_DIR/overlay_build/framework-res.apk"
    else
        echo "错误：Linux 环境下需要手动提供 framework-res.apk！"
        echo "请将一个安卓系统的 framework-res.apk 文件放到以下目录："
        echo "$SCRIPT_DIR/overlay_build/"
        exit 1
    fi
fi
echo "环境准备完成！/ Environment setup complete!"