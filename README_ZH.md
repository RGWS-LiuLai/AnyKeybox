# AnyKeybox

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Linux-green.svg)](https://github.com/RGWS-LiuLai/AnyKeybox)

> [English](./README.md) | **简体中文**

> 将任意现成的 `keybox.xml`（**包括人工伪造的**）转换为设备信任的 OEM 根证书 RRO 模块。

## 项目简介

AnyKeybox 是一款面向安全研究与玩机爱好者的纯脚本工具。它可以解析**任意**来源的 `keybox.xml` 文件——无论是从其他设备提取、网上下载，还是**从头人工伪造**——提取其中的证书链，并自动编译、签名、打包成一个 KernelSU / Magisk / APatch 模块。

刷入该模块后，你的 Android 设备会将 `keybox.xml` 中的根证书视为“设备制造商信任的 OEM 证书”，从而在 [KeyAttestation](https://github.com/vvb2060/KeyAttestation) 等检测工具中显示为**“本设备信任该根证书，但其他设备可能不信任”**的合法状态。

**最关键的是：哪怕这个 `keybox.xml` 完全是人工伪造的，也同样生效。** 系统不会向 Google 验证证书的真实性，也不会进行任何远程校验。只要证书被放入系统的 OEM 信任数组，设备就会无条件信任它。

---

## 免责声明

本项目**仅供个人学习、安全研究与技术交流**使用。严禁将本项目用于任何违法用途，包括但不限于绕过金融支付认证、伪造身份、侵犯他人隐私等。使用者应自行承担因使用本项目而产生的一切法律风险。作者不对任何滥用行为负责。

---

## 核心特性

- **纯脚本驱动**：无需 Android Studio，Termux 或 Linux 终端即可完成全部流程。
- **跨平台兼容**：同时支持 Android (Termux) 与标准 Linux 环境。
- **一键操作**：将 `keybox.xml` 放入指定文件夹，运行一条命令即可生成模块。
- **支持伪造 Keybox**：即使是完全人工伪造的 `keybox.xml`，也能让设备信任其根证书。
- **V1 + V2 + V3 全签名**：自动完成 APK 的多重签名，确保模块兼容性。
- **完全可逆**：所有修改通过 KernelSU / Magisk / APatch 模块挂载，卸载后重启即恢复原状。
- **双语文档**：提供完整的中英双语说明文档。

---

## 工作原理

### Android 密钥认证背景

Android 密钥认证（Key Attestation）是一种安全机制，允许应用验证非对称密钥对是否**由硬件支持**（存储在 TEE 或 StrongBox 中），以及设备是否处于**可信状态**。当密钥在安全环境中生成时，KeyMint（Keymaster 的现代替代品）会生成一条**证书链**：

1. **认证证书（Attestation Certificate）**：包含公钥和认证扩展信息（设备状态、安全级别等）
2. **中间证书（Intermediate Certificate）**：由厂商的中间 CA 签名
3. **根证书（Root Certificate）**：最终的信任锚点，通常由 Google 的认证根密钥签名

整个认证的可信度，取决于验证者是否将**根证书**识别为受信任的锚点。在原厂 Android 系统上，系统信任由 Google 或设备制造商（OEM）签名的根证书。

### RRO Overlay 机制

Android 的 **运行时资源覆盖（RRO）** 框架允许一个包在运行时覆盖另一个包的资源值——而无需修改目标包的 APK。我们瞄准的资源是：

```

vendor_required_attestation_certificates

```

这是一个定义在 `framework-res.apk`（系统框架资源包）中的 `string-array` 资源。它包含系统在认证验证时信任的、经过 PEM 编码的根证书。

在大多数设备上，这个数组默认是**空的或不存在**。通过创建一个静态 RRO 包，将自己的根证书填入这个数组，系统就会开始将其作为 OEM 根证书来信任。

### 为什么人工伪造的 Keybox 也能生效

即使是完全人工伪造的 `keybox.xml` 也能被接受，有三个关键原因：

1. **不向 Google 验证签名**：Android 框架在常规的 KeyAttestation 操作中，**不会**通过密码学方式验证根证书是否链回 Google 的官方认证根密钥。它只检查根证书是否存在于受信任的 OEM 证书数组中。
2. **默认无远程检查**：KeyAttestation 类应用通常只进行本地验证。它们检查证书链是否内部一致（每个证书由下一个证书签名），以及根证书是否在系统信任库中。除非显式配置，否则它们**不会**联系 Google 服务器验证真实性。
3. **信任数组完全可覆盖**：因为 RRO 可以用任何有效的 PEM 证书覆盖 `vendor_required_attestation_certificates`，而系统会信任该数组中的任何内容，所以你可以注入一个完全自签名、与任何真实厂商或 Google 毫无关系的根证书。

**简而言之：系统信任你放进 OEM 信任数组里的任何东西。没有任何背景检查。**

### 项目工作流

```text
keybox.xml ──> [02_extract_cert.sh] ──> ca.crt (PEM 证书)
                                              │
                                              ▼
                                    [03_build_overlay.sh]
                                              │
                                              ├── aapt2 compile ──> compiled.flata
                                              ├── aapt2 link ────> unsigned.apk
                                              └── apksigner ─────> MyOemOverlay.apk
                                                                        │
                                                                        ▼
                                                              [04_package_module.sh]
                                                                        │
                                                                        ▼
                                                              MyOemOverlay.zip
                                                                        │
                                                                        ▼
                                                          通过 KernelSU / Magisk / APatch 刷入
                                                                        │
                                                                        ▼
                                                          重启 ──> OEM 根证书受信任
```

---

项目结构

```text
AnyKeybox/
├── scripts/                   # Shell 脚本目录
│   ├── run_all.sh             # 一键执行总脚本
│   ├── 01_setup_env.sh        # 环境准备（Termux / Linux 双兼容）
│   ├── 02_extract_cert.sh     # 解析 keybox.xml 提取证书
│   ├── 03_build_overlay.sh    # 编译并签名 RRO Overlay APK
│   └── 04_package_module.sh   # 打包成 KernelSU/Magisk/APatch 模块
│
├── keybox_input/              # ⭐ 将 keybox.xml 放入此文件夹
│   └── keybox.xml             # 文件名必须严格为 keybox.xml
│
├── keys/                      # (自动生成) 提取出的证书
├── overlay_build/             # (自动生成) APK 编译中间产物
├── output/                    # (自动生成) 最终输出的 MyOemOverlay.zip
│
├── LICENSE                    # AGPL-3.0 许可证
└── README.md                  # 本文件（中文版）
```

---

快速开始

Android 设备（Termux）

```bash
# 1. 从 F-Droid 安装 Termux（不要用 Google Play 版）
# 2. 授予 Root 权限
# 3. 克隆并运行
git clone https://github.com/RGWS-LiuLai/AnyKeybox.git
cd AnyKeybox
cp /sdcard/Download/keybox.xml keybox_input/keybox.xml
chmod +x scripts/*.sh
bash scripts/run_all.sh
```

Linux 电脑（Ubuntu / Debian / Fedora）

```bash
# 1. 安装系统依赖
sudo apt install -y openjdk-17-jdk python3 zip openssl git  # Debian/Ubuntu
sudo dnf install -y java-17-openjdk python3 zip openssl git  # Fedora

# 2. 安装 aapt2 和 apksigner（来自 Android SDK Build-Tools）

# 3. 将 framework-res.apk 放入 overlay_build/
cp /path/to/framework-res.apk overlay_build/

# 4. 克隆并运行
git clone https://github.com/RGWS-LiuLai/AnyKeybox.git
cd AnyKeybox
cp /path/to/your/keybox.xml keybox_input/keybox.xml
chmod +x scripts/*.sh
bash scripts/run_all.sh
```

---

手把手教程

Android 教程

前置条件：

· 已 Root 的 Android 设备（KernelSU、Magisk 或 APatch）
· 从 F-Droid 安装的 Termux
· 准备好一个 keybox.xml（可以是从网上下载的，也可以是自己伪造的）

步骤 1：安装 Termux 并授予 Root 权限

从 F-Droid 下载并安装 Termux（Google Play 版已停止更新）。打开 Termux 运行：

```bash
su -c "echo Root OK"
```

如果输出 Root OK，即可继续。如果失败，请检查 Root 管理器的授权设置。

步骤 2：安装 git 并克隆项目

```bash
pkg install git -y
git clone https://github.com/RGWS-LiuLai/AnyKeybox.git
cd AnyKeybox
```

步骤 3：放入 keybox.xml

将你的 keybox.xml 复制到 keybox_input/ 文件夹。文件名必须严格为 keybox.xml。

```bash
cp /sdcard/Download/keybox.xml keybox_input/keybox.xml
```

如果你手头还没有 keybox.xml，可以使用标准的 OpenSSL 命令自行生成，或从网上下载。即便是完全伪造的也能生效。

步骤 4：运行一键脚本

```bash
chmod +x scripts/*.sh
bash scripts/run_all.sh
```

脚本会自动完成：

1. 检测并安装缺失依赖（首次运行会询问是否切换国内镜像源）
2. 从 keybox_input/keybox.xml 提取所有证书
3. 编译并签名 RRO Overlay APK（V1+V2+V3）
4. 打包成 KernelSU / Magisk / APatch 模块

步骤 5：刷入模块

运行完成后，在 output/ 目录下找到 MyOemOverlay.zip。打开 KernelSU / Magisk / APatch 管理器，选择“从本地安装”，刷入该 ZIP，先不要重启手机。

步骤 6：导入

使用Oh My Keymint / TEESimulator / TEESimulator-RS / Tricky Store OSS / Tricky Store 等 TEE 模拟/伪装模块导入要使其信任的 Keybox.xml （推荐），或者烧录要使其信任的 Keybox.xml （不推荐），然后重启手机。

步骤 7：验证

重启后打开 KeyAttestation，检查根证书状态是否变为：

“本设备信任该根证书，但其他设备可能不信任。”

<img width="1262" height="968" alt="1000012487" src="https://github.com/user-attachments/assets/1e7765e4-15df-43fe-a3aa-ba75648c6214" />

---

Linux 教程

步骤 1：安装系统依赖

```bash
# Debian / Ubuntu
sudo apt update
sudo apt install -y openjdk-17-jdk python3 zip openssl git

# Fedora
sudo dnf install -y java-17-openjdk python3 zip openssl git
```

步骤 2：安装 aapt2 和 apksigner

这两个工具属于 Android SDK Build-Tools。你可以：

方式 A — 使用发行版包管理器（最简单）：

```bash
sudo apt install -y android-sdk-build-tools aapt2 apksigner  # Debian/Ubuntu
```

方式 B — 手动下载：

1. 从 Android SDK Build-Tools 下载 build-tools_rXX.X.X-linux.zip
2. 解压并加入 PATH：

```bash
unzip build-tools_r34.0.0-linux.zip -d ~/android-build-tools
echo 'export PATH=$PATH:~/android-build-tools/34.0.0' >> ~/.bashrc
source ~/.bashrc
```

验证安装：

```bash
aapt2 version
apksigner version
```

步骤 3：准备 framework-res.apk

Linux 环境无法自动从手机提取 framework-res.apk，需要手动提供：

· 从任意 Android 设备的系统分区中提取 /system/framework/framework-res.apk（可以通过 MT 管理器等 Root 文件管理器，也可以从官方固件包中解压）
· 将其放入项目的 overlay_build/ 目录

步骤 4：克隆并运行

```bash
git clone https://github.com/RGWS-LiuLai/AnyKeybox.git
cd AnyKeybox
cp /path/to/your/keybox.xml keybox_input/keybox.xml
chmod +x scripts/*.sh
bash scripts/run_all.sh
```

脚本会自动检测 Linux 环境，跳过 pkg install 和 su 逻辑。

步骤 5：部署模块

将 output/MyOemOverlay.zip 传输到已 Root 的 Android 设备，通过 KernelSU / Magisk / APatch 刷入。

步骤 6：导入

使用Oh My Keymint / TEESimulator / TEESimulator-RS / Tricky Store OSS / Tricky Store 等 TEE 模拟/伪装模块导入要使其信任的 Keybox.xml （推荐），或者烧录要使其信任的 Keybox.xml （不推荐），然后重启手机。

---

模块管理

刷入模块

生成的 MyOemOverlay.zip 符合 KernelSU、Magisk 和 APatch 通用的模块格式。其结构如下：

```text
MyOemOverlay.zip
├── module.prop                # 模块元数据（id、名称、版本、作者）
└── system/
    └── product/
        └── overlay/
            └── MyOemOverlay.apk   # 已签名的 RRO Overlay APK
```

通过 Root 管理器的模块安装界面刷入即可。

验证是否生效

重启后，打开 KeyAttestation 检查根证书状态。成功的结果显示：

“本设备信任该根证书，但其他设备可能不信任。”

你还可以通过命令行验证 Overlay 是否启用：

```bash
su -c "cmd overlay list --user current | grep my_oem_overlay"
```

· [x] = 已启用并生效
· [ ] = 已安装但未启用

手动启用：

```bash
su -c "cmd overlay enable --user current com.my.oem.overlay"
```

卸载与回退

所有修改都存储在模块目录中，而非系统分区。要恢复原状：

1. 通过 KernelSU / Magisk / APatch 管理器：禁用或删除 my_oem_overlay 模块，然后重启。
2. 通过 TWRP（如果无法开机）：挂载 Data 分区，打开终端，运行：
   ```bash
   rm -rf /data/adb/modules/my_oem_overlay
   ```
3. 通过 KernelSU 安全模式：开机时按住音量减键，禁用所有模块。

你的数据（照片、聊天记录、应用数据）完全不会被触碰。只是移除了 Overlay 挂载。

---

常见问题（FAQ）

Q：这个会变砖吗？
A：不会。RRO Overlay 是 Android 官方支持的机制。即使 Overlay 配置无效，系统也只会忽略它。最坏的情况是无限重启，但通过 TWRP 或 KernelSU 安全模式删除模块文件夹即可轻松恢复。

Q：能通过 Google Play Integrity / SafetyNet 认证吗？
A：不能。证书是自签名的或来自泄露的 keybox，无法链回 Google 的认证根密钥。它无法通过硬件级认证检查。仅供研究和测试使用。

Q：如果我的 keybox.xml 是人工伪造的，完全没有任何官方来源，能行吗？
A：完全没问题。设备不会向任何外部机构验证根证书的来源。只要证书是有效的 PEM 编码证书，并通过 RRO 放入 OEM 信任数组，系统就会信任它。这正是本工具即使对完全伪造的 keybox 也能生效的原因。

Q：需要特定格式的 keybox.xml 吗？
A：脚本支持标准的 <AndroidAttestation> XML 格式。它会提取所有包含 PEM 编码证书的 <Certificate> 标签。

Q：支持 Android 16 / API 36 吗？
A：支持。RRO 的 vendor_required_attestation_certificates 资源自 Android 10 (API 29) 起就存在，并且在 Android 16 上依然有效。

Q：非 Root 设备能用吗？
A：不能。你需要 Root 权限（KernelSU、Magisk 或 APatch）来安装模块和挂载 Overlay。

---

故障排查

问题 可能原因 解决方案
运行脚本提示 Permission denied 文件所有者为 root 运行 su -c "chown -R $(whoami):$(whoami) /path/to/AnyKeybox"
pkg: command not found 在 MT 管理器终端而不是 Termux 里运行 打开真正的 Termux 应用
aapt2 link 报错 No such file or directory 缺少 framework-res.apk Termux：检查 Root 权限。Linux：手动将 framework-res.apk 放入 overlay_build/
apksigner 失败 缺少 Java 运行环境 安装 openjdk-21（Termux）或 openjdk-17-jdk（Linux）
刷入模块后 KeyAttestation 无变化 Overlay 未启用或缓存了旧结果 清除 KeyAttestation 缓存，重启，或手动启用 Overlay
刷入后无限重启 Overlay 与 ROM 冲突 进入 TWRP 或 KernelSU 安全模式，删除 /data/adb/modules/my_oem_overlay/

---

致谢名单

· ITxiao6666（酷安：阿奎亚）
  · GitHub: https://github.com/ITxiao6666
  · 酷安主页: https://www.coolapk.com/u/31943847
  · 感谢捐赠三星 keybox.xml 供个人使用喵（未参与开发）

---

开源协议

本项目采用 GNU Affero General Public License v3.0 (AGPL-3.0) 开源协议。

你可以自由使用、修改和分发本项目的代码，但必须遵守以下核心条件：

· 任何修改后的版本也必须以 AGPL-3.0 协议开源
· 如果通过网络提供服务（如搭建在线版），必须向用户公开源代码

详见 LICENSE 文件。

---

作者

RGWS-LiuLai

· GitHub: https://github.com/RGWS-LiuLai
· 酷安: 恋勿思
· 酷安主页: https://www.coolapk.com/u/28676823

---

本项目仅供学习研究，请勿用于非法用途。
