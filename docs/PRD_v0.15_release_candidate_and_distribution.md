# ImagePet PRD v0.15: Release Candidate 与上线准备

## 1. 版本定位

v0.15 是 ImagePet 的 Mac App Store 上线准备小版本。它不扩大压缩格式、压缩引擎、系统入口或桌面 Pet 能力范围，而是把 v0.14 的主窗口重设计和 v0.13 的后台反馈能力收束成可通过 Xcode Cloud 打包、可提交 App Store Connect、可被 App Review 理解的 Release Candidate。

本版本的产品承诺是：

```text
ImagePet is ready for Mac App Store submission: Xcode Cloud builds it, App Store Connect explains it, and App Review can verify the local-first compression workflow.
```

## 2. 背景

截至 v0.14：

- 核心压缩、WebP、Advanced JPEG、GUI 队列、桌面 Pet、Help Center、全局快捷键、Finder Quick Action、Shortcuts、Folder Watching、本地通知与 Soft Native 主窗口重设计已经实现。
- `swift test`、`xcodebuild ... test`、`./script/build_and_run.sh --verify` 在本机已有通过记录。
- Xcode Cloud 已部署，提交 `build*` 开头的分支会自动触发打包，打包路径基本跑通。
- 当前上线缺口集中在 App Store Connect metadata、截图、隐私信息、App Review notes、真实全局快捷键触发、系统入口手工 smoke、长时间 Folder Watching 和真实图片视觉检查。

v0.15 的核心不是继续加功能，而是把“可以在本机跑、Xcode Cloud 可以打包”推进到“可以提交 MAS 并让真实用户理解它是什么”。

## 3. P0 范围

### 3.1 Release Candidate 验收冻结

v0.15 需要把当前功能冻结为 RC 候选：

- 冻结 `ImagePet.xcodeproj` 作为本地验证和 Xcode Cloud 发布构建入口。
- 确认 `Package.resolved`、第三方 notice、bundle id、entitlements、deployment target 和版本号一致。
- 建立 RC build 命名规则，并确保 `build*` 分支触发出的 ASC build 可追溯到 git commit。
- RC 阶段只允许修复 P0/P1 bug、文案错误、签名公证问题、发布阻断测试失败。

验收：

- `docs/PROGRESS.md` 明确当前 RC 版本、构建日期、验证命令和阻断项。
- `docs/RELEASE_CHECKLIST.md` 可以从头到尾执行，并能记录 pass/fail/evidence。
- Xcode Cloud 对 `build*` 分支的触发规则和最新可用 build 状态写入进度文档。

### 3.2 Xcode Cloud 与 ASC build 验收

v0.15 必须把打包链路固定为 MAS 提交流程：

- 提交 `build*` 分支触发 Xcode Cloud。
- 确认 Xcode Cloud 产物出现在 App Store Connect / TestFlight 或可选版本 build 列表中。
- 确认 build number、version、bundle id、sandbox entitlement、App Sandbox capability 与提交计划一致。
- 使用 ASC/TestFlight 可安装 build 做最终手工 smoke，而不是只验证本地 Debug build。

验收：

- 最新 RC build 可在 ASC 中被选中用于提交审核。
- `docs/PROGRESS.md` 记录 build 分支、commit、version、build number 和 Xcode Cloud 结果。
- 本地验证和云端打包使用同一份提交的 `ImagePet.xcodeproj`。
- 没有依赖本机未提交文件、临时 fixture 或 DerivedData。

### 3.3 App Store Connect metadata

v0.15 的主要新增交付物是 ASC metadata，而不是新功能。需要建立并维护：

- app name、subtitle、category、age rating。
- description、promotional text、keywords、what's new。
- support URL、privacy policy URL。
- app privacy answers。
- App Review notes。
- screenshot plan 与最终截图清单。
- price and availability。
- export compliance / encryption answers。

首版 metadata 工作源：

- `metadata/`
- `docs/APP_STORE_METADATA.md` 仅作为 ASC 字段索引，不再复制一份独立文案源。

验收：

- ASC 所有必填 metadata 均已填写。
- metadata 不承诺未上线功能，不暗示云端压缩或 AI 能力。
- 隐私表述与实际 binary / dependencies 一致。
- App Review notes 能让 reviewer 在无账号、无后端、无测试素材预置的情况下完成基本验证。

参考：

- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple App Store Connect Help: Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Apple App Store Connect Help: Upload app previews and screenshots: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
- Apple App Store Connect Help: Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

### 3.4 MAS 安装与 TestFlight / review build 体验

v0.15 首发以 Mac App Store 为目标，不再把 Developer ID zip/dmg 作为 P0。需要验证：

- 从 ASC/TestFlight 安装的 build 可以首次启动。
- sandbox、用户选择文件读写、输出目录 bookmark、Shortcuts、Finder Services、notifications 在 MAS build 中行为正确。
- 没有 Debug-only UI 泄漏到 release build，除非明确只在 Debug compilation condition 下出现。
- CLI 不作为首发 MAS 独立分发承诺。

### 3.5 Release checklist 补齐

现有 `docs/RELEASE_CHECKLIST.md` 已覆盖权限、通知、Folder Watching、Shortcuts、sandbox/bookmark。v0.15 需要补齐上线向条目：

- Soft Native 主窗口视觉验收。
- 真实 iPhone HEIC / PNG / JPG / WebP 输入输出验收。
- Advanced JPEG 输出的 Preview / Safari / Chrome 打开验证。
- WebP 输出的 Preview / Safari / Chrome 打开验证。
- Global shortcut 真实录制和触发。
- Finder Quick Action 从 Finder 多选文件触发。
- 长时间 Folder Watching 运行，例如 30-60 分钟。
- Xcode Cloud build / ASC build / TestFlight 或 review build 验收。
- 干净用户目录首次启动和权限提示验收。
- ASC metadata、privacy、age rating、review notes、screenshots 验收。

验收：

- checklist 每项有 pass/fail、日期、执行人、证据路径或备注。
- 未通过项必须进入明确 bug list，不能只留在 checklist 注释里。

### 3.6 发布说明与用户文档

v0.15 需要让真实用户知道：

- ImagePet 做什么。
- 支持哪些输入/输出格式。
- 图片只在本地处理。
- 覆盖原图需要确认。
- Folder Watching、Shortcuts、Finder Quick Action、通知权限分别何时需要用户授权。
- 已知限制和推荐回退方式。

需要更新：

- `README.md`：当前版本状态、下载/运行说明、隐私与权限边界、验证命令。
- `docs/PROGRESS.md`：RC 状态和发布阻断项。
- `docs/RELEASE_CHECKLIST.md`：上线验收条目。
- `metadata/`：ASC 与网站共享的结构化 metadata 工作源。
- `docs/APP_STORE_METADATA.md`：ASC metadata 字段索引。
- 可选新增 `docs/RELEASE_NOTES_v0.15.md`：面向用户的变更说明。

### 3.7 崩溃、反馈与回滚闭环

v0.15 不引入在线遥测，但必须定义发布后问题处理方式：

- 用户如何反馈问题：GitHub issue、邮件或其他明确入口。
- 反馈模板包含 macOS 版本、ImagePet 版本、输入格式、输出格式、保存模式、是否启用 Folder Watching / Shortcuts / Advanced JPEG。
- 明确回滚策略：保留上一个可用 release artifact，严重问题时撤下当前下载链接并标记 known issue。
- 本地隐私边界：不自动上传图片、不自动上传日志。

验收：

- README 或 release notes 中有反馈入口。
- release checklist 中包含“回滚包可用”和“known issues 已检查”。
- ASC support URL 页面可承载基本支持和隐私说明。

## 4. P1 范围

- 增加 ASC metadata automation，例如后续用 App Store Connect API / fastlane 管理截图和文案。
- 增加 screenshots / short demo gif，用于 README 或 release 页面。
- 增加第二语言 metadata，例如 `zh-Hans`。
- 在一台非开发主力机或干净用户账户中执行完整 MAS/TestFlight RC 验收。
- 保留 Developer ID zip/dmg 作为未来站外分发 P1，不影响 MAS 首发。

## 5. 非目标

v0.15 明确不做：

- 不新增 AVIF、PDF、水印、云同步、登录、AI 决策。
- 不改变 `ImagePetCore` 的压缩策略，除非修复发布阻断 bug。
- 不重做 v0.14 之外的新视觉方向。
- 不引入自动遥测、崩溃自动上传或联网分析。
- 不做 Sparkle 自动更新。
- 不把 CLI 作为首发独立分发产品；CLI 只保持构建和测试通过。
- 不把 Developer ID zip/dmg 作为 v0.15 P0。

## 6. 技术与文档形状

建议拆成三个短提交边界：

1. `docs(release): plan v0.15 release candidate scope`
2. `docs(store): add app store metadata draft`
3. `fix(app): close rc blockers`

## 7. 验证命令

每个 RC 至少运行：

```bash
swift test
xcodebuild -project ImagePet.xcodeproj -scheme ImagePet -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' test
./script/build_and_run.sh --verify
git diff --check
```

发布构建额外验证以 Xcode Cloud / ASC build 为准，至少记录：

```text
build branch
git commit
version
build number
Xcode Cloud status
ASC/TestFlight availability
```

## 8. 完成标准

v0.15 可以标记为完成，当且仅当：

- 自动化验证全部通过。
- `docs/RELEASE_CHECKLIST.md` 的 P0 RC 项全部通过或有明确豁免。
- Xcode Cloud `build*` 分支产物可在 ASC 中选中并用于提交审核。
- `metadata/` 中的 ASC 字段已进入 ASC，截图、隐私、年龄分级、review notes、support URL 和 privacy policy URL 均完整。
- README、ASC metadata 和 release notes 能准确说明功能、权限、隐私、已知限制和反馈入口。
- 至少一次真实图片批量压缩、系统入口、通知、global shortcut、Folder Watching、Shortcuts、Finder Quick Action 手工验收通过。
- 发现的 P0/P1 bug 已修复或决定延期发布。

## 9. 待确认问题

- ASC primary language 使用 English 还是 Simplified Chinese？
- Support URL 和 Privacy Policy URL 使用哪个公开页面？
- 首发价格免费还是付费？
- 是否先只提交 English metadata，中文本地化留到 0.15.x？
- `build*` 分支触发规则是否需要记录在 `docs/PROGRESS.md` 的固定位置？
