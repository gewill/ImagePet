# ASC V1.1 Metadata 提交计划

本文档用于规划 ImagePet V1.1 的 App Store Connect metadata 提交流程。提交流程使用 `asc metadata` 的 canonical JSON 工作流。

## 目标

只提交与 App Store Connect 中选定二进制完全一致的 V1.1 Mac App Store metadata。

当前版本号口径：

- Xcode / bundle marketing version：`1.1`
- App Store Connect app store version：`1.1`

## 当前源文件

- 产品、版本、URL、隐私基线：`metadata/app.json`
- 英文 App Store 文案：`metadata/locales/en-US.json`
- App Store 字段映射、分类、截图计划、提交 checklist：`metadata/channels/mac-app-store.json`
- 人工索引文档：`docs/APP_STORE_METADATA.md`

## 提交前阻断检查

上传前必须确认 metadata 宣称的能力与提交的 V1.1 二进制一致。

V1.1 metadata 可以声明 WebP 支持，但文案必须准确表达当前能力边界：

- 支持 JPG / JPEG / PNG / HEIC / WebP 输入。
- 支持 Original / JPEG / PNG / HEIC / WebP 输出，具体可用性受本机 encoder capability 保护。
- WebP 仅承诺静态图片输入/输出；不要承诺动画 WebP、WebP Lossless 或 AVIF。
- Finder Quick Action / Services、Shortcuts、Folder Watching、本地通知、桌面 Pet 等能力必须只在提交二进制实际可用时出现。
- 不得宣称云端上传、AI 自动格式决策、未验证 benchmark 或未发布能力。

## 本地脚本准备

从仓库 metadata 源生成 ASC canonical metadata：

```bash
./script/prepare_asc_metadata.py
```

默认输出：

```text
.codex/asc-metadata/app-info/en-US.json
.codex/asc-metadata/version/1.1/en-US.json
```

如果 ASC 后台版本号变化，可以临时覆盖：

```bash
./script/prepare_asc_metadata.py --asc-version "1.1"
```

如果字段超过 ASC 限制，脚本会在本地失败：

- name：30
- subtitle：30
- keywords：100
- description：4000
- what's new：4000
- promotional text：170

V1.1 更新版本默认生成 `whatsNew` 字段。ASC 在某些版本状态下可能临时拒绝编辑该字段，并返回：

```text
Attribute 'whatsNew' cannot be edited at this time
```

如果目标 ASC 版本临时锁定 What's New，再显式省略：

```bash
./script/prepare_asc_metadata.py --omit-whats-new
```

## ASC Dry Run 流程

先解析 App Store Connect 中的 app、app-info 和版本：

```bash
asc apps list --output table
asc apps info list --app "6780180225" --output table
asc versions list --app "6780180225" --platform MAC_OS --output table
```

应用本地变更前，先拉取当前 ASC 状态用于对比：

```bash
asc metadata pull --app "6780180225" --version "1.1" --platform MAC_OS --dir ".codex/asc-metadata-current"
```

校验本地生成的 metadata：

```bash
asc metadata validate --dir ".codex/asc-metadata" --output table
```

预览远端变更，不写入 ASC：

```bash
asc metadata push --app "6780180225" --version "1.1" --platform MAC_OS --dir ".codex/asc-metadata" --dry-run --output table
```

确认 dry run 计划无误后再实际写入：

```bash
asc metadata push --app "6780180225" --version "1.1" --platform MAC_OS --dir ".codex/asc-metadata"
```

## `asc metadata` 之外的字段

`asc metadata` canonical 命令只覆盖 app-info 和 version localization 字段。以下内容需要单独处理：

- 分类：primary `Graphics & Design`，secondary `Utilities`
- 年龄分级问卷
- 内容版权声明
- App Privacy 答案
- 截图
- 价格和可用地区
- Export compliance / encryption
- Review details 和附件
- Copyright

Copyright 命令形式：

```bash
asc versions update --version-id "VERSION_ID" --copyright "2026 Gewill"
```

## 提交前 readiness gate

metadata 和截图准备完成后执行：

```bash
asc validate --app "6780180225" --version "1.0" --platform MAC_OS --strict --output table
```

只有该检查通过，或每个 warning 都有明确人工决策后，才进入 review submit。
