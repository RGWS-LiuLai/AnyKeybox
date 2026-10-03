#!/data/data/com.termux/files/usr/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/overlay_build"
cd "$BUILD_DIR"

echo "准备 Overlay 源码... / Preparing Overlay source code..."
mkdir -p res/values res/xml

cat > AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.my.oem.overlay">
    <application android:hasCode="false" />
    <overlay
        android:targetPackage="android"
        android:targetName="framework-res"
        android:resourcesMap="@xml/overlays"
        android:isStatic="true" />
</manifest>
EOF

cat > res/xml/overlays.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<overlay xmlns:android="http://schemas.android.com/apk/res/android">
    <item target="array/vendor_required_attestation_certificates"
          value="@array/vendor_required_attestation_certificates" />
</overlay>
EOF

echo '<?xml version="1.0" encoding="utf-8"?>' > res/values/arrays.xml
echo '<resources>' >> res/values/arrays.xml
echo '    <string-array name="vendor_required_attestation_certificates">' >> res/values/arrays.xml

while IFS= read -r line || [ -n "$line" ]; do
    if [ -n "$line" ]; then
        echo '        <item>' >> res/values/arrays.xml
        echo "$line" >> res/values/arrays.xml
        echo '        </item>' >> res/values/arrays.xml
    fi
done < "$SCRIPT_DIR/keys/ca.crt"

echo '    </string-array>' >> res/values/arrays.xml
echo '</resources>' >> res/values/arrays.xml

echo "正在编译资源... / Compiling resources..."
aapt2 compile --dir res/ -o compiled.flata
aapt2 link -I framework-res.apk --manifest AndroidManifest.xml -o unsigned.apk compiled.flata

if [ ! -f unsigned.apk ]; then
    echo "错误：aapt2 link 失败，unsigned.apk 不存在！ / Error: aapt2 link failed, unsigned.apk not found!"
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