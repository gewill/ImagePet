#!/usr/bin/env bash
# ImagePet CLI - Build, sign, notarize, and package script.
# This script is secret-free and reads credentials only from your environment or macOS Keychain.

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

PRODUCT_NAME="imagepet"
RELEASE_VERSION="${RELEASE_VERSION:-v1.0}"
SKIP_CODESIGN="${SKIP_CODESIGN:-0}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"
DIST_DIR="${DIST_DIR:-$PROJECT_DIR/dist/cli/$RELEASE_VERSION}"
WORK_DIR="$DIST_DIR/work"
ARCH_NAME="$(uname -m)"
ARCHIVE_NAME="${PRODUCT_NAME}-cli-${RELEASE_VERSION}-macos-${ARCH_NAME}.zip"
ARCHIVE_PATH="$DIST_DIR/$ARCHIVE_NAME"
SHA_PATH="$ARCHIVE_PATH.sha256"
MANIFEST_PATH="$DIST_DIR/${PRODUCT_NAME}-cli-${RELEASE_VERSION}-manifest.json"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "=== 1. 正在编译 Release 版本 CLI ==="
swift build -c release --product imagepet

cp ".build/release/$PRODUCT_NAME" "$WORK_DIR/$PRODUCT_NAME"

if [[ "$SKIP_CODESIGN" == "1" ]]; then
  echo "=== 2. 已跳过 Developer ID 签名 (SKIP_CODESIGN=1) ==="
else
  CERTIFICATE_NAME="${CODESIGN_IDENTITY:-}"
  if [[ -z "$CERTIFICATE_NAME" ]]; then
    echo "🔍 尝试自动查找 Developer ID Application 证书..."
    CERTIFICATE_NAME=$(security find-certificate -a -c "Developer ID Application" | grep "alis" | head -n 1 | cut -d '"' -f 4 || true)
  fi

  if [[ -z "$CERTIFICATE_NAME" ]]; then
    echo "❌ Error: 未找到 Developer ID Application 证书。请设置 CODESIGN_IDENTITY 环境变量。"
    echo "例如: export CODESIGN_IDENTITY=\"Developer ID Application: Your Name (TEAM_ID)\""
    echo "本地 dry-run 可使用: SKIP_CODESIGN=1 SKIP_NOTARIZATION=1 ./script/release_cli.sh"
    exit 1
  fi
  echo "✅ 使用签名证书: $CERTIFICATE_NAME"

  echo "=== 2. 正在进行 Hardened Runtime 签名 ==="
  codesign --force \
    --options runtime \
    --timestamp \
    --sign "$CERTIFICATE_NAME" \
    "$WORK_DIR/$PRODUCT_NAME"
fi

echo "=== 3. 正在打包 ZIP ==="
rm -f "$ARCHIVE_PATH" "$SHA_PATH" "$MANIFEST_PATH"
(
  cd "$WORK_DIR"
  ditto -c -k --keepParent "$PRODUCT_NAME" "$ARCHIVE_PATH"
)

ARCHIVE_SHA256="$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')"
printf "%s  %s\n" "$ARCHIVE_SHA256" "$ARCHIVE_NAME" > "$SHA_PATH"

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "=== 4. 已跳过苹果公证 (SKIP_NOTARIZATION=1) ==="
else
  echo "=== 4. 正在提交苹果服务器公证 (Notarization) ==="
  NOTARY_PROFILE="${NOTARY_PROFILE:-}"

  if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "👉 使用 Keychain 凭证 Profile: $NOTARY_PROFILE"
    xcrun notarytool submit "$ARCHIVE_PATH" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait
  else
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
    xcrun notarytool submit "$ARCHIVE_PATH" \
      --apple-id "$NOTARY_APPLE_ID" \
      --password "$NOTARY_PASSWORD" \
      --team-id "$NOTARY_TEAM_ID" \
      --wait
  fi
fi

echo "=== 5. 正在验证本地二进制 ==="
"$WORK_DIR/$PRODUCT_NAME" --version

if [[ "$SKIP_CODESIGN" == "1" ]]; then
  echo "=== 6. 已跳过签名验证 (SKIP_CODESIGN=1) ==="
else
  echo "=== 6. 正在验证本地二进制签名 ==="
  codesign --verify --strict --verbose=2 "$WORK_DIR/$PRODUCT_NAME"
  codesign -dv --verbose=4 "$WORK_DIR/$PRODUCT_NAME"
fi

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "=== 7. 已跳过公证验证 (SKIP_NOTARIZATION=1) ==="
else
  echo "=== 7. 正在验证公证结果 ==="
  spctl -a -vvv -t install "$ARCHIVE_PATH"
fi

GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "$MANIFEST_PATH" <<JSON
{
  "product": "$PRODUCT_NAME",
  "version": "$RELEASE_VERSION",
  "archive": "$ARCHIVE_NAME",
  "sha256": "$ARCHIVE_SHA256",
  "arch": "$ARCH_NAME",
  "gitCommit": "$GIT_COMMIT",
  "codesigned": $([[ "$SKIP_CODESIGN" == "1" ]] && echo "false" || echo "true"),
  "notarized": $([[ "$SKIP_NOTARIZATION" == "1" ]] && echo "false" || echo "true"),
  "createdAt": "$CREATED_AT"
}
JSON

echo "=== 完成：CLI 发布产物已生成 ==="
echo "Archive:  $ARCHIVE_PATH"
echo "SHA256:   $ARCHIVE_SHA256"
echo "Manifest: $MANIFEST_PATH"
