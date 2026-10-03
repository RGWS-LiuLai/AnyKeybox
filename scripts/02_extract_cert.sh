#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEYBOX_FILE="$SCRIPT_DIR/keybox_input/keybox.xml"

echo "正在解析 $KEYBOX_FILE ... / Parsing $KEYBOX_FILE ..."
mkdir -p "$SCRIPT_DIR/keys"

python3 - "$KEYBOX_FILE" "$SCRIPT_DIR/keys/ca.crt" << 'PYEOF'
import sys
import xml.etree.ElementTree as ET
import re

xml_path = sys.argv[1]
out_path = sys.argv[2]

try:
    tree = ET.parse(xml_path)
    root = tree.getroot()
except Exception as e:
    print(f"XML 解析失败 / XML parse failed: {e}")
    sys.exit(1)

certs = root.findall(".//Certificate")
if not certs:
    print("错误: keybox.xml 中未找到 <Certificate> 标签！ / Error: No <Certificate> tags found in keybox.xml!")
    sys.exit(1)

output_certs = []
for cert in certs:
    text = cert.text
    if text:
        match = re.search(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', text, re.DOTALL)
        if match:
            output_certs.append(match.group(0).strip())

if not output_certs:
    print("错误: 未能提取到有效的 PEM 证书！ / Error: Failed to extract valid PEM certificates!")
    sys.exit(1)

with open(out_path, 'w') as f:
    for cert in output_certs:
        f.write(cert + "\n")

print(f"成功提取 {len(output_certs)} 个证书！ / Successfully extracted {len(output_certs)} certificates!")
PYEOF