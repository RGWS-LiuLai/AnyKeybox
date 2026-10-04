# AnyKeybox

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Linux-green.svg)](https://github.com/RGWS-LiuLai/AnyKeybox)

> **English** | [简体中文](./README_ZH.md)

> Convert any existing `keybox.xml` — including artificially fabricated ones — into an OEM-trusted RRO module for Android.

## What is AnyKeybox?

AnyKeybox is a pure-script tool designed for security researchers and Android enthusiasts. It parses **any** `keybox.xml` file — whether extracted from another device, downloaded from the internet, or **artificially fabricated from scratch** — extracts the embedded certificate chain, and automatically compiles, signs, and packages it into a KernelSU / Magisk / APatch module.

Once flashed, your Android device will treat the root certificate from the `keybox.xml` as an **OEM-trusted certificate**, causing tools like [KeyAttestation](https://github.com/vvb2060/KeyAttestation) to display the legitimate status:

> *"This device trusts this root certificate, but it may not be trusted by others."*

**Crucially, this works even if the keybox.xml is completely artificial.** There is no signature verification against Google's official root, and no remote check is performed. The device simply trusts whatever root certificate is placed into the system's OEM trust array.

---

## Disclaimer

This project is **intended solely for personal learning, security research, and technical exchange**. Any illegal use, including but not limited to bypassing financial payment authentication, identity forgery, or privacy infringement, is strictly prohibited. Users assume all legal risks arising from the use of this project. The author is not responsible for any misuse.

---

## Key Features

- **Pure Script Driven**: No Android Studio required. Complete the entire workflow in Termux or any Linux terminal.
- **Cross-Platform Compatible**: Works on both Android (Termux) and standard Linux distributions.
- **One-Click Operation**: Place your `keybox.xml` into the designated folder, run a single command, and get a flashable module.
- **Works with Fabricated Keyboxes**: Even a completely artificial `keybox.xml` with no official origin can make the device trust its root certificate.
- **V1 + V2 + V3 Full Signing**: Automatically performs multi-scheme APK signing to ensure maximum compatibility across Android versions.
- **Fully Reversible**: All modifications are mounted via KernelSU / Magisk / APatch module system. Uninstall the module and reboot — everything returns to stock.
- **Bilingual Documentation**: Full English and Chinese documentation provided.

---

## How It Works

### Android Key Attestation Background

Android Key Attestation is a security mechanism that allows an app to verify that an asymmetric key pair is **hardware-backed** (stored in TEE or StrongBox) and that the device is in a **trusted state**. When a key is generated inside the secure environment, KeyMint (the modern replacement for Keymaster) produces a **certificate chain**:

1. **Attestation certificate** — contains the public key and attestation extensions (device state, security level, etc.)
2. **Intermediate certificate(s)** — signed by the vendor's intermediate CA
3. **Root certificate** — the ultimate trust anchor, typically signed by Google's attestation root key

The trustworthiness of the entire attestation depends on whether the verifier recognizes the **root certificate** as a trusted anchor. On stock Android, the system trusts root certificates signed by Google or the device manufacturer (OEM).

### The RRO Overlay Mechanism

Android's **Runtime Resource Overlay (RRO)** framework allows a package to override resource values of another package at runtime — without modifying the target package's APK. The resource we target is:

```

vendor_required_attestation_certificates

```

This is a `string-array` resource defined in `framework-res.apk` (the system framework resource package). It contains PEM-encoded root certificates that the system trusts for attestation verification.

On most devices, this array is **empty or absent** by default. By creating a static RRO package that populates this array with your own root certificate, the system will begin to trust it as an OEM root.

### Why Even Fabricated Keyboxes Work

There are three critical reasons why even an artificially fabricated `keybox.xml` will be accepted:

1. **No Signature Verification Against Google**: The Android framework does not cryptographically verify that the root certificate chains back to Google's official attestation root key during normal KeyAttestation operations. It simply checks whether the root certificate is present in the trusted OEM certificate array.

2. **No Remote Check by Default**: KeyAttestation apps typically perform local validation only. They check whether the certificate chain is internally consistent (each certificate is signed by the next) and whether the root is in the system trust store. They do not contact Google servers to verify authenticity unless explicitly configured to do so.

3. **The Trust Array is Fully Overridable**: Because RRO can override `vendor_required_attestation_certificates` with any valid PEM certificate, and the system trusts whatever is in that array, you can inject an entirely self-signed root that has no relationship to any real manufacturer or Google.

**In short: the system trusts whatever you put into the OEM trust array. There is no background check.**

### Project Workflow

```text
keybox.xml ──> [02_extract_cert.sh] ──> ca.crt (PEM certificates)
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
                                                          Flash via KernelSU / Magisk / APatch
                                                                        │
                                                                        ▼
                                                          Reboot ──> OEM Root Trusted
```

---

Project Structure

```text
AnyKeybox/
├── scripts/                   # Shell scripts directory
│   ├── run_all.sh             # One-click master script
│   ├── 01_setup_env.sh        # Environment setup (Termux / Linux dual-compatible)
│   ├── 02_extract_cert.sh     # Parse keybox.xml and extract certificates
│   ├── 03_build_overlay.sh    # Compile and sign RRO Overlay APK
│   └── 04_package_module.sh   # Package into KernelSU/Magisk/APatch module
│
├── keybox_input/              # ⭐ Place your keybox.xml here
│   └── keybox.xml             # Filename must be exactly keybox.xml
│
├── keys/                      # (Auto-created) Extracted certificates
├── overlay_build/             # (Auto-created) APK compilation artifacts
├── output/                    # (Auto-created) Final MyOemOverlay.zip
│
├── LICENSE                    # AGPL-3.0 License
└── README.md                  # This file
```

---

Quick Start

Android (Termux)

```bash
# 1. Install Termux from F-Droid (NOT Google Play)
# 2. Grant Root access when prompted
# 3. Clone and run
git clone https://github.com/RGWS-LiuLai/AnyKeybox.git
cd AnyKeybox
cp /sdcard/Download/keybox.xml keybox_input/keybox.xml
chmod +x scripts/*.sh
bash scripts/run_all.sh
```

Linux (Ubuntu / Debian / Fedora)

```bash
# 1. Install dependencies
sudo apt install -y openjdk-17-jdk python3 zip openssl git  # Debian/Ubuntu
sudo dnf install -y java-17-openjdk python3 zip openssl git  # Fedora

# 2. Install aapt2 and apksigner (from Android SDK Build-Tools)

# 3. Place framework-res.apk into overlay_build/
cp /path/to/framework-res.apk overlay_build/

# 4. Run
git clone https://github.com/RGWS-LiuLai/AnyKeybox.git
cd AnyKeybox
cp /path/to/your/keybox.xml keybox_input/keybox.xml
chmod +x scripts/*.sh
bash scripts/run_all.sh
```

---

Step-by-Step Tutorial

Android Tutorial

Prerequisites:

· A rooted Android device (KernelSU, Magisk, or APatch)
· Termux installed from F-Droid
· A keybox.xml file ready (it can be artificial — a self-generated one works too)

Step 1: Install Termux and grant Root access

Download Termux from F-Droid (the Google Play version is outdated). Open Termux and run:

```bash
su -c "echo Root OK"
```

If you see Root OK, proceed. If not, check your root manager's authorization settings.

Step 2: Install the package git and clone the repository

```bash
pkg install git -y
git clone https://github.com/RGWS-LiuLai/AnyKeybox.git
cd AnyKeybox
```

Step 3: Place your keybox.xml

Copy your keybox.xml into the keybox_input/ folder. The filename must be exactly keybox.xml.

```bash
cp /sdcard/Download/keybox.xml keybox_input/keybox.xml
```

If you do not have a keybox.xml yet, you can generate one yourself using standard OpenSSL commands, or download one from the internet. Even a completely fabricated one will work.

Step 4: Run the one-click script

```bash
chmod +x scripts/*.sh
bash scripts/run_all.sh
```

The script will:

1. Detect and install missing dependencies (you will be asked whether to switch to a Chinese mirror)
2. Extract all certificates from keybox_input/keybox.xml
3. Compile and sign the RRO Overlay APK (V1 + V2 + V3)
4. Package everything into a KernelSU / Magisk / APatch module

Step 5: Flash the module

After the script completes, find output/MyOemOverlay.zip. Open your root manager (KernelSU / Magisk / APatch), go to Modules → Install from local, select the ZIP. Do not reboot yet.

Step 6: Import

Use TEE simulation/spoofing modules such as Oh My Keymint / TEESimulator / TEESimulator-RS / Tricky Store OSS / Tricky Store to import the Keybox.xml that you want them to trust (recommended), or flash the Keybox.xml that you want them to trust (not recommended). After completing this step, reboot your device.

Step 7: Verify

Open KeyAttestation. You should see:

"This device trusts this root certificate, but it may not be trusted by others."

<img width="1262" height="968" alt="1000012546" src="https://github.com/user-attachments/assets/7cf9c66a-9aac-4cef-8fe1-798135f3b660" />

---

Linux Tutorial

Step 1: Install system dependencies

```bash
# Debian / Ubuntu
sudo apt update
sudo apt install -y openjdk-17-jdk python3 zip openssl git

# Fedora
sudo dnf install -y java-17-openjdk python3 zip openssl git
```

Step 2: Install aapt2 and apksigner

These tools are part of the Android SDK Build-Tools. You can either:

Option A — Use distro packages (easiest):

```bash
sudo apt install -y android-sdk-build-tools aapt2 apksigner  # Debian/Ubuntu
```

Option B — Manual download:

1. Download build-tools_rXX.X.X-linux.zip from Android SDK Build-Tools
2. Extract and add to PATH:

```bash
unzip build-tools_r34.0.0-linux.zip -d ~/android-build-tools
echo 'export PATH=$PATH:~/android-build-tools/34.0.0' >> ~/.bashrc
source ~/.bashrc
```

Verify:

```bash
aapt2 version
apksigner version
```

Step 3: Prepare framework-res.apk

Linux cannot extract framework-res.apk from a connected device automatically. You must obtain it manually:

· Extract /system/framework/framework-res.apk from any Android device (via a root file manager like MT Manager, or from an official firmware package)
· Place it into the overlay_build/ directory of the project

Step 4: Clone and run

```bash
git clone https://github.com/RGWS-LiuLai/AnyKeybox.git
cd AnyKeybox
cp /path/to/your/keybox.xml keybox_input/keybox.xml
chmod +x scripts/*.sh
bash scripts/run_all.sh
```

The script will automatically detect the Linux environment and skip the pkg install and su logic.

Step 5: Deploy the module

Transfer output/MyOemOverlay.zip to your rooted Android device and flash it via KernelSU / Magisk / APatch.

---

Module Management

Flashing the Module

The generated MyOemOverlay.zip follows the standard module format used by KernelSU, Magisk, and APatch. It contains:

```text
MyOemOverlay.zip
├── module.prop                # Module metadata (id, name, version, author)
└── system/
    └── product/
        └── overlay/
            └── MyOemOverlay.apk   # The signed RRO Overlay APK
```

Flash it through your root manager's module installation interface.

Verifying Success

After rebooting, open KeyAttestation and check the root certificate status. A successful result displays:

"This device trusts this root certificate, but it may not be trusted by others."

You can also verify the Overlay is active:

```bash
su -c "cmd overlay list --user current | grep my_oem_overlay"
```

· [x] = enabled and active
· [ ] = installed but not enabled

To manually enable:

```bash
su -c "cmd overlay enable --user current com.my.oem.overlay"
```

Uninstalling / Reverting

All modifications are stored in the module directory, not in the system partition. To revert:

1. Via KernelSU / Magisk / APatch Manager: Disable or delete the my_oem_overlay module, then reboot.
2. Via TWRP (if boot loop): Mount Data, open Terminal, and run:
   ```bash
   rm -rf /data/adb/modules/my_oem_overlay
   ```
3. Via KernelSU Safe Mode: Hold Volume Down during boot to disable all modules.

Your data (photos, messages, app data) is never touched. Only the Overlay mount is removed.

---

Frequently Asked Questions (FAQ)

Q: Will this brick my device?
A: No. RRO Overlays are an officially supported Android mechanism. Even if the Overlay configuration is invalid, the system will simply ignore it. The worst case is a boot loop, which is easily recoverable by removing the module folder via TWRP or KernelSU Safe Mode.

Q: Can this pass Google Play Integrity / SafetyNet?
A: No. The certificate is self-signed or comes from a leaked keybox; it does not chain back to Google's attestation root key. It cannot pass hardware-backed attestation checks. It is intended for research and testing purposes only.

Q: What if my keybox.xml is artificially fabricated and has no official origin?
A: That is perfectly fine. The device does not verify the origin of the root certificate against any external authority. As long as the certificate is a valid PEM-encoded certificate and is placed into the OEM trust array via RRO, the system will trust it. This is precisely why this tool works even with completely artificial keyboxes.

Q: Do I need a specific keybox.xml format?
A: The script supports the standard <AndroidAttestation> XML format. It extracts all <Certificate> tags containing PEM-encoded certificates.

Q: Does this work on Android 16 / API 36?
A: Yes. The RRO vendor_required_attestation_certificates resource has been present since Android 10 (API 29) and continues to work on Android 16.

Q: Can I use this on a non-rooted device?
A: No. You need root access (KernelSU, Magisk, or APatch) to install the module and mount the Overlay.

---

Troubleshooting

Problem Likely Cause Solution
Permission denied when running scripts Files owned by root Run su -c "chown -R $(whoami):$(whoami) /path/to/AnyKeybox"
pkg: command not found Running in MT Manager terminal instead of Termux Open the actual Termux app
aapt2 link fails: No such file or directory Missing framework-res.apk Termux: check root access. Linux: manually place framework-res.apk in overlay_build/
apksigner fails Missing Java runtime Install openjdk-21 (Termux) or openjdk-17-jdk (Linux)
Module flashes but KeyAttestation unchanged Overlay not enabled or cached result Clear KeyAttestation cache, reboot, or manually enable the Overlay
Boot loop after flashing Overlay conflicts with ROM Enter TWRP or KernelSU Safe Mode, delete /data/adb/modules/my_oem_overlay/

---

Acknowledgements

· ITxiao6666 (Coolapk: 阿奎亚)
  · GitHub: https://github.com/ITxiao6666
  · Coolapk: https://www.coolapk.com/u/31943847
  · For donating a Samsung keybox.xml for personal use. (Not involved in development.)

---

License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

You are free to use, modify, and distribute this project, provided that:

· Any modified version is also released under AGPL-3.0
· If you provide the software as a network service, you must make the source code available to users

See the LICENSE file for full terms.

---

Author

RGWS-LiuLai

· GitHub: https://github.com/RGWS-LiuLai
· Coolapk: 恋勿思
· Coolapk Profile: https://www.coolapk.com/u/28676823

---

This project is for educational and research purposes only. Do not use it for illegal activities.
