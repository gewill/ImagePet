# ImagePet CLI 独立发布与公证指南 (方案 A)

本指南详细介绍了当需要将 `imagepet` 命令行工具 (CLI) 作为独立无沙盒版本分发（通过 GitHub Releases 或 Homebrew）时的打包、签名、公证 (Notarization) 以及凭证附着 (Staple) 的完整流程。

---

## 1. 准备工作 (Prerequisites)

在开始命令行签名与公证之前，你需要准备好以下材料：

1. **苹果开发者账号 (Apple Developer Program)**。
2. **Developer ID Application 证书**：
   - 登录 [Apple Developer 证书后台](https://developer.apple.com/account/resources/certificates/list)。
   - 创建并下载 **Developer ID Application** 证书，双击导入你 Mac 的 Keychain Access（钥匙串访问）。
   - 记下证书名称，格式通常为：`Developer ID Application: Your Name (TEAM_ID)`。
3. **App 专用密码 (App-Specific Password)**：
   - 登录你的 Apple ID 账户管理页面 ([appleid.apple.com](https://appleid.apple.com))。
   - 在“登录和安全”中，点击“App 专用密码”，生成一个专门用于公证的密码并保存。

---

## 2. 核心打包与公证步骤

我们推荐使用 Swift Package Manager (SPM) 编译 Release 版本的二进制文件，并直接对编译产物进行 Hardened Runtime 签名和公证。

### 步骤 1：本地编译 Release 二进制文件
在项目根目录下，执行以下命令编译出优化后的 Release 版本 CLI：
```bash
swift build -c release --product imagepet
```
*编译产物将存放在：`.build/release/imagepet`。*

### 步骤 2：使用 Developer ID 证书签名
由于 CLI 运行在沙盒之外，为了通过 macOS 安全防护，**必须启用 Hardened Runtime** (`--options runtime`) 并签名：
```bash
codesign --force \
  --options runtime \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  .build/release/imagepet
```

### 步骤 3：压制成 ZIP 文件
苹果公证服务只接收归档压缩包 (ZIP) 或磁盘镜像 (DMG)，不能直接上传独立的二进制文件：
```bash
# 压缩 imagepet 二进制文件
cd .build/release
zip -r imagepet-cli.zip imagepet
```

### 步骤 4：提交至苹果公证服务器
使用 `notarytool` 命令行工具提交你的 ZIP 包：
```bash
xcrun notarytool submit imagepet-cli.zip \
  --apple-id "YOUR_APPLE_ID_EMAIL" \
  --password "YOUR_APP_SPECIFIC_PASSWORD" \
  --team-id "YOUR_TEAM_ID" \
  --wait
```
*`--wait` 参数会阻塞终端，并实时输出公证进度（通常耗时 1 到 3 分钟），直到服务器返回 `Accepted`（成功）或 `Invalid`（失败）。*

### 步骤 5：附着公证凭证 (Staple)
当公证成功后，你需要将苹果的公证凭证（Ticket）附着在你的二进制文件上，这称为 Staple。这样用户即使在断网状态下首次双击运行，系统也能识别出已通过安全扫描：
```bash
# 注意：stapler 必须直接作用在 imagepet 二进制文件本身上，而不是 ZIP 上
xcrun stapler staple imagepet
```

---

## 3. 一键自动化脚本 `script/release_cli.sh`

为了免去每次手动输入命令，你可以创建并运行如下的自动化脚本。

在 `script/release_cli.sh` 中写入：

```bash
#!/usr/bin/env bash
# ImagePet CLI - Sign and Notarize Script (Option A)
set -euo pipefail

# === 配置区 ===
CERTIFICATE_NAME="Developer ID Application: Your Name (TEAM_ID)"
APPLE_ID="your-email@example.com"
APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
TEAM_ID="YOUR_TEAM_ID"
# ==============

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

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

echo "=== 4. 正在提交苹果服务器公证 (Notarization) ==="
xcrun notarytool submit imagepet-cli.zip \
  --apple-id "$APPLE_ID" \
  --password "$APP_SPECIFIC_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait

echo "=== 5. 正在附着公证凭证 (Stapling) ==="
xcrun stapler staple imagepet

echo "=== 🎉 CLI 发布准备完成！二进制文件已签名公证完毕 ==="
```
运行脚本即可自动完成全套流程。

---

## 4. 社区分发推荐 (GitHub Releases & Homebrew)

完成上述步骤后，你可以把经过公证的 `imagepet` 可执行二进制文件发布给社区：

1. **GitHub Releases**：直接将生成的 `imagepet`（或打包好的 `imagepet-cli.zip`）上传为 GitHub Tag Release 的 Asset。
2. **Homebrew Tap 分发**：
   - 编写一个你个人 Tap 的 Homebrew Formula：
     ```ruby
     class Imagepet < Formula
       desc "Local-first macOS batch image compressor"
       homepage "https://imagepet.gewill.org/"
       url "https://github.com/gewill/ImagePet/releases/download/v1.0.0/imagepet-cli.zip"
       sha256 "ZIP文件的SHA256哈希值"
       license "MIT"

       def install
         bin.install "imagepet"
       end
     end
     ```
   - 用户只需在终端运行 `brew install gewill/tap/imagepet` 即可完成免检疫的安全安装。
