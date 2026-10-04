#!/data/data/com.termux/files/usr/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../overlay_build"
cd "$BUILD_DIR"

echo "准备 Overlay 源码... / Preparing Overlay source code..."
mkdir -p res/values res/xml

# 通过Base64解码生成 AndroidManifest.xml，完美避开手机粘贴换行错误
echo "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KPG1hbmlmZXN0IHhtbG5zOmFuZHJvaWQ9Imh0dHA6Ly9zY2hlbWFzLmFuZHJvaWQuY29tL2Fway9yZXMvYW5kcm9pZCIKICAgIHBhY2thZ2U9ImNvbS5teS5vZW0ub3ZlcmxheSI+CiAgICA8YXBwbGljYXRpb24gYW5kcm9pZDpoYXNDb2RlPSJmYWxzZSIgLz4KICAgIDxvdmVybGF5CiAgICAgICAgYW5kcm9pZDp0YXJnZXRQYWNrYWdlPSJhbmRyb2lkIgogICAgICAgIGFuZHJvaWQ6dGFyZ2V0TmFtZT0iZnJhbWV3b3JrLXJlcyIKICAgICAgICBhbmRyb2lkOnJlc291cmNlc01hcD0iQHhtbC9vdmVybGF5cyIKICAgICAgICBhbmRyb2lkOmlzU3RhdGljPSJ0cnVlIiAvPgo8L21hbmlmZXN0Pg==" | base64 -d > AndroidManifest.xml

# 通过Base64解码生成 overlays.xml
echo "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KPG92ZXJsYXkgeG1sbnM6YW5kcm9pZD0iaHR0cDovL3NjaGVtYXMuYW5kcm9pZC5jb20vYXBrL3Jlcy9hbmRyb2lkIj4KICAgIDxpdGVtIHRhcmdldD0iYXJyYXkvdmVuZG9yX3JlcXVpcmVkX2F0dGVzdGF0aW9uX2NlcnRpZmljYXRlcyIKICAgICAgICAgIHZhbHVlPSJAYXJyYXkvdmVuZG9yX3JlcXVpcmVkX2F0dGVzdGF0aW9uX2NlcnRpZmljYXRlcyIgLz4KPC9vdmVybGF5Pg==" | base64 -d > res/xml/overlays.xml

# 动态生成 arrays.xml 并注入提取出来的证书
echo '<?xml version="1.0" encoding="utf-8"?>' > res/values/arrays.xml
echo '<resources>' >> res/values/arrays.xml
echo '    <string-array name="vendor_required_attestation_certificates">' >> res/values/arrays.xml

while IFS= read -r line || [ -n "$line" ]; do
    if [ -n "$line" ]; then
        echo '        <item>' >> res/values/arrays.xml
        echo "$line" >> res/values/arrays.xml
        echo '        </item>' >> res/values/arrays.xml
    fi
done < "$SCRIPT_DIR/../keys/ca.crt"

echo '    </string-array>' >> res/values/arrays.xml
echo '</resources>' >> res/values/arrays.xml

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
