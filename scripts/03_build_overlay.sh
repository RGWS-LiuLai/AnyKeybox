#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../overlay_build"
cd "$BUILD_DIR"

if [ ! -f "$SCRIPT_DIR/../keys/ca.crt" ]; then
    echo "错误：找不到证书文件 $SCRIPT_DIR/../keys/ca.crt，请先运行 02_extract_cert.sh！ / Error: ca.crt not found!"
    exit 1
fi

echo "准备 Overlay 源码... / Preparing Overlay source code..."
mkdir -p res/values res/xml

# 清理上次构建的旧产物，避免失败后误用过期文件
rm -f compiled.flata unsigned.apk aligned.apk MyOemOverlay.apk

cat > AndroidManifest.xml << 'XMLEOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.my.oem.overlay"
    android:targetSdkVersion="28">
    <application android:hasCode="false" />
    <overlay
        android:targetPackage="android"
        android:priority="0"
        android:isStatic="true" />
</manifest>
XMLEOF

# 生成正确的 arrays.xml（按证书块而非行拆分，每张证书一个 <item>）
echo "生成 arrays.xml（提取证书并分块）..."
python3 - "$SCRIPT_DIR/../keys/ca.crt" "$BUILD_DIR/res/values/arrays.xml" <<'PYEOF'
import sys, re
with open(sys.argv[1], 'r', encoding='utf-8') as infile:
    certs = re.findall(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', infile.read(), re.S)
if not certs:
    print("错误: ca.crt 中未找到有效证书块！ / Error: No valid PEM blocks found in ca.crt!")
    sys.exit(1)
with open(sys.argv[2], 'w', encoding='utf-8') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string-array name="vendor_required_attestation_certificates">\n')
    for c in certs:
        f.write('        <item>%s</item>\n' % c.strip())
    f.write('    </string-array>\n</resources>\n')
PYEOF

echo "正在编译资源... / Compiling resources..."
aapt2 compile --dir res/ -o compiled.flata
aapt2 link -I framework-res.apk --manifest AndroidManifest.xml -o unsigned.apk compiled.flata

if [ ! -f unsigned.apk ]; then
    echo "错误：aapt2 link 失败，unsigned.apk 不存在！ / Error: aapt2 link failed!"
    exit 1
fi

echo "正在生成签名密钥... / Generating signature key..."
if [ ! -f my-release-key.jks ]; then
    keytool -genkey -v -keystore my-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mykey -storepass 123456 -keypass 123456 -dname "CN=MyOemOverlay, OU=Dev, O=My, L=City, S=State, C=CN"
fi

echo "正在签名 APK (V1+V2+V3)... / Signing APK (V1+V2+V3)..."
cp unsigned.apk aligned.apk
apksigner sign --ks my-release-key.jks --ks-key-alias mykey --ks-pass pass:123456 --key-pass pass:123456 --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --out MyOemOverlay.apk aligned.apk

if [ ! -f MyOemOverlay.apk ]; then
    echo "错误：APK 签名失败！ / Error: APK signing failed!"
    exit 1
fi
echo "APK 编译和签名完成！ / APK compilation and signing complete!"
echo "文件位置 / File location: $BUILD_DIR/MyOemOverlay.apk"
