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
4. **存储公证凭证到 macOS 钥匙串中（强烈推荐）**：
   - 运行以下命令，将凭证安全地存储到本地系统中（命名为 `imagepet-notary-profile`）：
     ```bash
     xcrun notarytool store-credentials "imagepet-notary-profile" \
       --apple-id "your-apple-id-email@example.com" \
       --team-id "YOUR_TEAM_ID"
     ```
   - 系统会提示您输入刚刚生成的 App 专用密码。完成后，此凭证将以加密形式保存在本地 Keychain 中，无需在任何脚本或环境变量中暴露明文密码。

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
我们强烈推荐使用已配置的 Keychain profile 提交公证，以避免在命令行中暴露密码：
```bash
# 推荐方式：使用 Keychain Profile
xcrun notarytool submit imagepet-cli.zip \
  --keychain-profile "imagepet-notary-profile" \
  --wait

# 备选方式：直接在命令中传入凭证
xcrun notarytool submit imagepet-cli.zip \
  --apple-id "YOUR_APPLE_ID_EMAIL" \
  --password "YOUR_APP_SPECIFIC_PASSWORD" \
  --team-id "YOUR_TEAM_ID" \
  --wait
```
*`--wait` 参数会阻塞终端，并实时输出公证进度（通常耗时 1 到 3 分钟），直到服务器返回 `Accepted`（成功）或 `Invalid`（失败）。*

### 步骤 5：验证公证与签名结果
由于 `stapler` 只能应用于 `.app`、`.dmg` 或 `.pkg` 等打包/包格式，对于单独的命令行工具裸可执行文件（如 `imagepet` CLI），在公证成功后**不需要（也无法）执行 staple**。当用户首次在终端运行时，macOS Gatekeeper 会自动向苹果公证服务器在线核对公证状态。

你可以通过以下命令在本地验证签名与公证状态：
```bash
# 验证打包后的 ZIP 压缩包的公证状态
spctl -a -vvv -t install imagepet-cli.zip

# 验证本地解压出的二进制文件的签名状态
codesign --verify --strict --verbose=2 imagepet
codesign -dv --verbose=4 imagepet
```

---

## 3. 一键自动化脚本 `script/release_cli.sh`

项目已包含一键签名与公证的自动化脚本 [release_cli.sh](file:///Users/rxwill/git/MyApps/ImagePet/script/release_cli.sh)。该脚本**完全不含任何硬编码密钥或证书**，可在开源环境中安全公开。

### 运行方式

#### 运行选项 1：使用 Keychain 凭证（推荐）
在本地 Keychain 存好凭证后，只需要传入 Profile 名称运行：
```bash
NOTARY_PROFILE="imagepet-notary-profile" ./script/release_cli.sh
```

#### 运行选项 2：使用临时环境变量
如果不使用 Keychain，可通过环境变量传入必要凭证：
```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
NOTARY_APPLE_ID="your-email@example.com" \
NOTARY_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
NOTARY_TEAM_ID="YOUR_TEAM_ID" \
./script/release_cli.sh
```
*(注：如果本地 Keychain 只有一个 Developer ID 签名证书，可省略 `CODESIGN_IDENTITY` 环境变量，脚本会尝试自动检测)*


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
       url "https://github.com/gewill/ImagePet/releases/download/v1.0/imagepet-cli.zip"
       sha256 "ZIP文件的SHA256哈希值"
       license "MIT"

       def install
         bin.install "imagepet"
       end
     end
     ```
   - 用户只需在终端运行 `brew install gewill/tap/imagepet` 即可完成免检疫的安全安装。
