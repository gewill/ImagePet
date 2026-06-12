# ImagePet MVP Progress

更新日期：2026-06-12

## 当前状态

MVP 工程骨架和核心 workflow 已经实现，当前更适合进入手工验收和性能验收阶段。

已完成：

- SwiftUI macOS app scaffold
- `ImagePetCore` 压缩核心
- GUI 拖拽、队列、状态展示和输出目录选择
- `Add Images` 菜单/按钮输入入口
- 桌面宠物小窗第一版
- 单张压缩结果显示原始大小、输出大小和节省比例
- App Sandbox entitlements
- committed `ImagePet.xcodeproj`
- SwiftPM 和 Xcode build/test 路径
- 本地 Apple 测试素材 fixture

尚未完成验收：

- 真实拖入 20 张 iPhone HEIC 的手工 GUI 验收
- Developer ID notarization workflow

已自动化验证：

- 性能与鲁棒性验收：已实现自动化并发压缩测试，跑完 20 张大图，总耗时 0.24 秒，内存峰值约 155.6 MB（限制为 1.5GB），且单图失败不会崩溃（由 `PerformanceAndRobustnessTests` 验证）。

## 追踪入口

- 产品需求基线：[PRD.md](PRD.md)
- 项目说明与架构：[../README.md](../README.md)
- Agent 协作规则：[../AGENTS.md](../AGENTS.md)

## 功能追踪

| 模块 | 状态 | 证据 | 下一步 |
| --- | --- | --- | --- |
| JPG / JPEG / PNG / HEIC 输入 | 已实现 | `SupportedImageFormat` + ImageIO 解码；fixture 覆盖 JPG/PNG/HEIC | 用真实 iPhone HEIC 做手工验收 |
| JPG 输出 | 已实现 | `ImageCompressor` 统一写出 JPG | 检查输出色彩和方向样本 |
| WebP / AVIF 不做 | 已锁定 | PRD 和 README 明确排除 | 保持范围，不引入新格式 |
| 3 个压缩预设 | 已实现 | `CompressionPreset.high/balanced/small` | UI 里继续保持默认 Balanced |
| 批量拖拽 / Add Images | 已实现 | SwiftUI drop destination 接收多 URL；`NSOpenPanel` 选择多张支持格式图片 | 需要手工拖拽和菜单选择验证 |
| 输出目录选择 | 已实现 | `NSOpenPanel` 选择目录 | 验证 bookmark 失效后的提示 |
| Security-scoped bookmark | 已实现 | `OutputDirectoryBookmarkStore` | 手工验证跨启动恢复 |
| App Sandbox | 已实现并验证 | entitlements 包含 sandbox + user-selected read-write | 保持 CI 检查 |
| maxConcurrentJobs = 2 | 已实现 | `ImagePetStore` 队列 worker 限制 | 性能测试时观察吞吐和内存 |
| autoreleasepool | 已实现 | `ImageCompressor` decode/encode/write 包裹 | 压测确认峰值内存 |
| 每张图即时更新 UI | 已实现 | 每个 job 完成后更新状态、size 和 saved ratio | GUI 手工检查状态变化 |
| 桌面 Pet 第一版 | 已实现 | `DesktopPetWindowController` + `DesktopPetView`，可通过主界面或菜单显示/隐藏并跟随状态变化 | 手工验证窗口拖动、跨 Space 和状态同步 |
| 不覆盖原文件 | 已实现 | `OutputNameAllocator` + 单测覆盖冲突 | 覆盖同名真实文件场景 |
| Core 失败路径 | 已实现 | 单测覆盖不支持格式、坏图解码失败、输出目录不可用；格式边界测试锁定 GIF/WebP/PDF 不支持 | GUI 混合批次仍需手工验证 |
| 总计 Ate / Pooped / Saved | 已实现 | `ImagePetStore` 汇总，GUI 展示 | 手工核对展示 |
| Reveal in Finder | 已实现 | GUI 调用 Finder reveal/open | 手工点击验证 |
| Retry Failed | 已实现 | 失败任务重置后重跑 | 用坏文件混入批次验证 |
| Compress More | 已实现 | 清空队列并保留设置 | 手工验证设置保留 |
| Committed Xcode project | 已完成 | `ImagePet.xcodeproj` 已入库 | CI 后续直接用 Xcode project |

## 已验证

最近一次验证结果：

```text
swift test
结果：通过
测试数：11
性能与鲁棒性验证：通过（20张并行压缩，耗时 0.23 秒，峰值内存 151.6 MB）
```

```text
xcodebuild -project ImagePet.xcodeproj \
  -scheme ImagePet \
  -configuration Debug \
  -derivedDataPath DerivedData \
  -destination 'platform=macOS' \
  test
结果：通过
测试数：11
性能与鲁棒性验证：通过（20张并行压缩，耗时 0.24 秒，峰值内存 155.6 MB）
```

```text
./script/build_and_run.sh --verify
结果：通过
```

Apple fixture 压缩测试：

```text
fixture 数量：16
原始总大小：4.9 MB
输出总大小：2.8 MB
节省：2.2 MB / 43.5%
```

Entitlements 验证：

```text
com.apple.security.app-sandbox = true
com.apple.security.files.user-selected.read-write = true
```

Bundle ID：

```text
org.gewill.ImagePet
```

## 待验收

### 手工 GUI 验收

- 启动 app。
- 首次选择输出目录，建议命名为 `ImagePet Output`。
- 拖入或通过 `Add Images` 选择 20 张 iPhone HEIC / PNG / JPG。
- 选择 Balanced。
- 确认每张图显示：
  - 原始大小
  - 输出大小
  - 节省比例
  - 状态
  - 错误原因
- 确认总计显示：
  - Ate
  - Pooped
  - Saved
- 点击 `Reveal in Finder`，确认输出目录可打开。
- 点击 `Compress More`，确认队列清空，quality 和输出目录保留。
- 点击 `Show Pet`，确认桌面宠物小窗可显示、可拖动、可隐藏，并跟随压缩状态变化。

### 失败路径验收

- 混入损坏图片或不支持格式。
- 确认单个文件失败不会中断批次。
- 确认失败文件显示简短错误原因。
- 点击 `Retry Failed`，确认只重跑失败任务。

### 权限路径验收

- 删除或移动输出目录后启动。
- 确认 bookmark 失效时要求重新选择目录。
- 确认不会默认写入 `~/Pictures` 或其他未授权目录。

### 性能验收

测试条件：

- Apple Silicon Mac
- 20 张 12MP iPhone HEIC
- Balanced preset
- 输出 JPG

通过标准：

- 30 秒内完成
- App 内存峰值低于 1.5GB
- 单张失败不崩溃

## 未开始

- Developer ID signing / notarization
- Mac App Store packaging
- App icon
- 更复杂宠物动画
- Finder Extension
- Raycast Extension
- Shortcuts
- 文件夹监听
- CLI target

## Core 与 GUI 后续方向

`ImagePetCore` 已经是独立 target，后续可以基于它做命令行版本。

推荐后续 CLI 形态：

- Xcode target: `ImagePetCLI`
- SwiftPM executable product: `imagepet`
- 依赖：`ImagePetCore`
- 参数解析：Swift Argument Parser

CLI 不应该依赖 GUI 层的这些类型：

- `ImagePetStore`
- `ContentView`
- `OutputFolderPanel`
- `OutputDirectoryBookmarkStore`

这样后续可以保留同一套压缩核心，同时支持：

- GUI app
- CLI 批处理
- CI smoke test
- 未来 Automator / Shortcuts wrapper
