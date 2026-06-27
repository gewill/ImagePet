# ImagePet CLI v1.1 独立发布与 Homebrew 指南

本指南记录 `imagepet` 命令行工具作为独立无沙盒版本分发时的 v1.1 发布流程。GitHub Releases 使用签名/公证后的 ZIP 产物；Homebrew Tap 使用同一个 GitHub Release asset。

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

推荐使用仓库脚本统一编译、签名、打包、生成 SHA256 和 manifest。

### 本地 dry-run

没有 Developer ID 证书或公证凭证时，先跑本地 dry-run，验证 Release 构建、ZIP 和 SHA256 生成：

```bash
SKIP_CODESIGN=1 SKIP_NOTARIZATION=1 ./script/release_cli.sh
```

脚本默认要求 worktree clean，确保 manifest 里的 `gitCommit` 对应实际发布源码。仅本地试包且明确接受 dirty manifest 时，才使用：

```bash
ALLOW_DIRTY=1 SKIP_CODESIGN=1 SKIP_NOTARIZATION=1 ./script/release_cli.sh
```

脚本会生成：

```text
dist/cli/v1.1/imagepet-cli-v1.1-macos-<arch>.zip
dist/cli/v1.1/imagepet-cli-v1.1-macos-<arch>.zip.sha256
dist/cli/v1.1/imagepet-cli-v1.1-manifest.json
```

`dist/` 已被 `.gitignore` 排除，不要把本地构建产物提交进仓库。

### 正式签名与公证

正式发布时运行：

```bash
RELEASE_VERSION=v1.1 \
NOTARY_PROFILE="imagepet-notary-profile" \
./script/release_cli.sh
```

如果本机不止一个 Developer ID 证书，显式传入证书名称：

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
RELEASE_VERSION=v1.1 \
NOTARY_PROFILE="imagepet-notary-profile" \
./script/release_cli.sh
```

脚本会对二进制启用 Hardened Runtime 签名：

```bash
codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" imagepet
```

由于 `stapler` 只能应用于 `.app`、`.dmg` 或 `.pkg` 等打包/包格式，对于单独的命令行工具裸可执行文件（如 `imagepet` CLI），在公证成功后不需要也无法执行 staple。用户首次运行时，macOS Gatekeeper 会在线核对公证状态。

脚本内置以下验证：

```bash
imagepet --version
codesign --verify --strict --verbose=2 imagepet
spctl -a -vvv -t install imagepet-cli-v1.1-macos-<arch>.zip
```

### GitHub Release 上传项

v1.1 tag 创建后，将以下产物上传到 GitHub Release：

```text
imagepet-cli-v1.1-macos-<arch>.zip
imagepet-cli-v1.1-macos-<arch>.zip.sha256
imagepet-cli-v1.1-manifest.json
```

---

## 3. 自动化脚本 `script/release_cli.sh`

项目已包含签名与公证自动化脚本 `script/release_cli.sh`。该脚本不含任何硬编码密钥或证书，可在开源环境中安全公开。

### 运行方式

#### 运行选项 1：本地 dry-run

```bash
SKIP_CODESIGN=1 SKIP_NOTARIZATION=1 ./script/release_cli.sh
```

#### 运行选项 2：使用 Keychain 凭证（推荐）
在本地 Keychain 存好凭证后，只需要传入 Profile 名称运行：
```bash
NOTARY_PROFILE="imagepet-notary-profile" ./script/release_cli.sh
```

#### 运行选项 3：使用临时环境变量
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

## 4. Homebrew Tap

Homebrew v1.1 使用 GitHub Release 里的二进制 ZIP。当前 arm64 产物为：

```text
imagepet-cli-v1.1-macos-arm64.zip
sha256: 073ad3d82f2d8a266743389bd86797bece8d8ae677901079f52d35b03be45362
```

对应的下载 URL 是：

```bash
https://github.com/gewill/ImagePet/releases/download/v1.1/imagepet-cli-v1.1-macos-arm64.zip
```

发布流程：

1. 先把 CLI 产物上传到 GitHub Release：

```bash
gh release upload v1.1 \
  dist/cli/v1.1/imagepet-cli-v1.1-macos-arm64.zip \
  dist/cli/v1.1/imagepet-cli-v1.1-macos-arm64.zip.sha256 \
  dist/cli/v1.1/imagepet-cli-v1.1-manifest.json \
  --clobber
```

2. 确认 asset URL 可访问：

```bash
curl -L -o /tmp/imagepet-cli-v1.1-macos-arm64.zip \
  https://github.com/gewill/ImagePet/releases/download/v1.1/imagepet-cli-v1.1-macos-arm64.zip
shasum -a 256 /tmp/imagepet-cli-v1.1-macos-arm64.zip
```

输出必须等于：

```text
073ad3d82f2d8a266743389bd86797bece8d8ae677901079f52d35b03be45362
```

3. 如果本机还没有 tap，创建 tap：

```bash
brew tap-new gewill/tap
```

创建后，本地 tap 仓库位置是：

```text
/opt/homebrew/Library/Taps/gewill/homebrew-tap
```

也可以用命令获取，避免写死 Homebrew prefix：

```bash
brew --repo gewill/tap
```

4. 新版 Homebrew 需要先信任本地 tap：

```bash
brew trust gewill/tap
```

5. 复制 Formula 模板到 tap 仓库：

```bash
mkdir -p "$(brew --repo gewill/tap)/Formula"

cp packaging/homebrew/imagepet.rb \
  "$(brew --repo gewill/tap)/Formula/imagepet.rb"
```

6. 在 tap 仓库验证：

```bash
brew install --formula "$(brew --repo gewill/tap)/Formula/imagepet.rb"
brew test "$(brew --repo gewill/tap)/Formula/imagepet.rb"
brew audit --strict "$(brew --repo gewill/tap)/Formula/imagepet.rb"
```

7. 提交并推送 tap：

```bash
cd "$(brew --repo gewill/tap)"

git add Formula/imagepet.rb
git commit -m "feat(imagepet): update v1.1 formula"

gh repo create gewill/homebrew-tap --public --source=. --remote=origin --push
```

如果 GitHub repo 已经存在，改用：

```bash
cd "$(brew --repo gewill/tap)"

git remote add origin git@github.com:gewill/homebrew-tap.git
git push -u origin main
```

用户安装命令：

```bash
brew tap gewill/tap
brew trust gewill/tap
brew install gewill/tap/imagepet
```
