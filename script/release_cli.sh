#!/usr/bin/env bash
# ImagePet CLI - Sign and Notarize Script
# This script is 100% secret-free and can be safely committed to git.
# It reads credentials from your environment or macOS Keychain.

set -euo pipefail

# === 默认配置与环境变量说明 ===
# 你可以通过环境变量传递这些配置，或者在终端直接运行：
# CODESIGN_IDENTITY="Developer ID Application: Your Name" ./script/release_cli.sh
#
# 1. 签名证书名称 (Code Signing Identity)
#    环境变量: CODESIGN_IDENTITY
#    默认值: 尝试自动查找 "Developer ID Application:" 证书
#
# 2. 公证凭证 (Notarization Credentials)
#    推荐方式 (Keychain Profile):
#      在终端运行一次以下命令存储凭证到系统钥匙串中：
#      xcrun notarytool store-credentials "imagepet-notary-profile" --apple-id "your-apple-id@email.com" --team-id "YOUR_TEAM_ID" --password "xxxx-xxxx-xxxx-xxxx"
#      然后设置环境变量: NOTARY_PROFILE="imagepet-notary-profile"
#
#    备选方式 (环境变量):
#      NOTARY_APPLE_ID: Apple ID 邮箱
#      NOTARY_PASSWORD: App 专用密码 (App-Specific Password)
#      NOTARY_TEAM_ID: Apple Developer Team ID
# ==========================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# 1. 确定签名证书
CERTIFICATE_NAME="${CODESIGN_IDENTITY:-}"
if [[ -z "$CERTIFICATE_NAME" ]]; then
  # 尝试在 Keychain 中自动查找一个有效的 Developer ID Application 证书
  echo "🔍 尝试自动查找 Developer ID Application 证书..."
  # 提取证书 Common Name
  CERTIFICATE_NAME=$(security find-certificate -a -c "Developer ID Application" | grep "alis" | head -n 1 | cut -d '"' -f 4 || true)
fi

if [[ -z "$CERTIFICATE_NAME" ]]; then
  echo "❌ Error: 未找到 Developer ID Application 证书。请设置 CODESIGN_IDENTITY 环境变量。"
  echo "例如: export CODESIGN_IDENTITY=\"Developer ID Application: Your Name (TEAM_ID)\""
  exit 1
fi
echo "✅ 使用签名证书: $CERTIFICATE_NAME"

# 2. 准备编译
echo "=== 1. 正在编译 Release 版本 CLI ==="
swift build -c release --product imagepet

echo "=== 2. 正在进行 Hardened Runtime 签名 ==="
codesign --force \
  --options runtime \
  --sign "$CERTIFICATE_NAME" \
  .build/release/imagepet

echo "=== 3. 正在打包 ZIP ==="
cd .build/release
rm -f imagepet-cli.zip
zip -r imagepet-cli.zip imagepet

# 3. 提交公证
echo "=== 4. 正在提交苹果服务器公证 (Notarization) ==="
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ -n "$NOTARY_PROFILE" ]]; then
  echo "👉 使用 Keychain 凭证 Profile: $NOTARY_PROFILE"
  xcrun notarytool submit imagepet-cli.zip \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
else
  # 检查是否提供了备选的环境变量
  NOTARY_APPLE_ID="${NOTARY_APPLE_ID:-}"
  NOTARY_PASSWORD="${NOTARY_PASSWORD:-}"
  NOTARY_TEAM_ID="${NOTARY_TEAM_ID:-}"

  if [[ -z "$NOTARY_APPLE_ID" ]] || [[ -z "$NOTARY_PASSWORD" ]] || [[ -z "$NOTARY_TEAM_ID" ]]; then
    echo "❌ Error: 未配置公证凭证。"
    echo "请设置 NOTARY_PROFILE 环境变量（推荐使用 Keychain 存储）或设置以下环境变量："
    echo "- NOTARY_APPLE_ID"
    echo "- NOTARY_PASSWORD"
    echo "- NOTARY_TEAM_ID"
    exit 1
  fi

  echo "👉 使用环境变量公证..."
  xcrun notarytool submit imagepet-cli.zip \
    --apple-id "$NOTARY_APPLE_ID" \
    --password "$NOTARY_PASSWORD" \
    --team-id "$NOTARY_TEAM_ID" \
    --wait
fi

echo "=== 5. 正在验证公证结果 ==="
spctl -a -vvv -t install imagepet-cli.zip

echo "=== 6. 正在验证本地二进制签名 ==="
codesign --verify --strict --verbose=2 imagepet
codesign -dv --verbose=4 imagepet

echo "=== 🎉 完成：CLI 已签名并通过 Notarization ==="
