# ImagePet MVP Progress

更新日期：2026-06-14

## 当前状态

MVP 工程骨架和 V0.3 核心 workflow 已经实现，当前更适合进入手工验收、性能验收和发布前打包阶段。

已完成：

- SwiftUI macOS app scaffold
- `ImagePetCore` 压缩核心
- GUI 拖拽、队列、状态展示和输出目录选择
- `Add Images` 菜单/按钮输入入口
- 桌面宠物小窗第一版
- 桌面 Pet UI、动效和轻量交互优化
- V0.3 输出格式、保存位置、覆盖确认、尺寸限制和元数据剥离选项
- 单张压缩结果显示原始大小、输出大小和节省比例
- App Sandbox entitlements
- committed `ImagePet.xcodeproj`
- SwiftPM 和 Xcode build/test 路径
- 本地 Apple 测试素材 fixture
- 真实图片批量拖入与压缩的手工 GUI 验收

尚未完成验收：

- Developer ID notarization workflow

已自动化验证：

- 性能与鲁棒性验收：已实现自动化并发压缩测试，跑完 20 张大图，最近一次总耗时 0.22 秒，内存峰值约 161.6 MB（限制为 1.5GB），且单图失败不会崩溃（由 `PerformanceAndRobustnessTests` 验证）。
- UI 与交互验收：已实现 XCUITest 自动化 UI 测试，包含首屏加载、质量预设更改、桌面宠物小窗开关、桌面宠物返回主窗口、完成态动作、失败重试、覆盖确认、以及批量压缩完整流程（由 `ImagePetUITests` 验证）。

## 追踪入口

- 产品需求基线：[PRD.md](PRD.md)
- V0.3 扩展需求：[PRD_v0.3.md](PRD_v0.3.md)
- V0.4 桌面 Pet 规划：[PRD_v0.4_desktop_pet.md](PRD_v0.4_desktop_pet.md)
- V0.5 桌面 Pet 双态规划：[PRD_v0.5_desktop_pet_dual_state.md](PRD_v0.5_desktop_pet_dual_state.md)
- 项目说明与架构：[../README.md](../README.md)
- Agent 协作规则：[../AGENTS.md](../AGENTS.md)

## 功能追踪

| 模块 | 状态 | 证据 | 下一步 |
| --- | --- | --- | --- |
| JPG / JPEG / PNG / HEIC 输入 | 已实现 | `SupportedImageFormat` + ImageIO 解码；fixture 覆盖 JPG/PNG/HEIC | 用真实 iPhone HEIC 做手工验收 |
| Original / JPEG / PNG / HEIC 输出 | 已实现 | `OutputFormat` + ImageIO 写出；覆盖模式强制保持原格式 | 检查输出色彩和方向样本 |
| WebP / AVIF 不做 | 已锁定 | PRD 和 README 明确排除 | 保持范围，不引入新格式 |
| 3 个压缩预设 | 已实现 | `CompressionPreset.high/balanced/small` | UI 里继续保持默认 Balanced |
| 最大边长限制 | 已实现 | `MaxDimensionLimit` + compressor 单测覆盖缩放 | 用真实大图做视觉验收 |
| 元数据剥离 | 已实现 | `stripMetadata` 默认开启；保留模式复制基础 source properties | 手工检查 EXIF/GPS 样本 |
| 批量拖拽 / Add Images | 已实现 | SwiftUI drop destination 接收多 URL；`NSOpenPanel` 选择多张支持格式图片 | 需要手工拖拽和菜单选择验证 |
| 输出目录选择 / 原目录保存 / 覆盖原图 | 已实现 | 指定目录 bookmark；原目录授权；覆盖模式二次确认并写临时文件后替换 | 验证 bookmark 失效后的提示 |
| Security-scoped bookmark | 已实现 | `OutputDirectoryBookmarkStore`，原目录模式按请求目录保存授权 key | 手工验证跨启动恢复 |
| App Sandbox | 已实现并验证 | entitlements 包含 sandbox + user-selected read-write | 保持 CI 检查 |
| maxConcurrentJobs = 2 | 已实现 | `ImagePetStore` 队列 worker 限制 | 性能测试时观察吞吐和内存 |
| autoreleasepool | 已实现 | `ImageCompressor` decode/encode/write 包裹 | 压测确认峰值内存 |
| 每张图即时更新 UI | 已实现 | 每个 job 完成后更新状态、size 和 saved ratio | GUI 手工检查状态变化 |
| 桌面 Pet 第一版 | 已实现 | `DesktopPetWindowController` + `DesktopPetView`，可通过主界面或菜单显示/隐藏、返回主窗口并跟随状态变化 | 手工验证窗口拖动、跨 Space 和状态同步 |
| 桌面 Pet UI / 动效 / 交互优化 | 已实现 | Pet 小窗扩展到 `192x176`，增加状态色、状态徽章、主动作按钮、处理中进度条、拖拽高亮、hover 反馈和 Reduce Motion 分支 | 手工验证 Light/Dark、Reduce Motion、拖拽追加和 VoiceOver 读出 |
| 桌面 Pet Mini / Full 双态规划 | 已规划 | `docs/PRD_v0.5_desktop_pet_dual_state.md` 明确 Mini 只显示 Pet、Full 负责解释和操作、阻塞状态自动展开 | 进入 P0 双态实现前评审 Done / Issues / 自动收回策略 |
| 非覆盖模式不覆盖原文件 | 已实现 | `OutputNameAllocator` + 单测覆盖冲突和后缀清洗 | 覆盖同名真实文件场景 |
| 覆盖模式保护 | 已实现 | UI 强制原格式、二次确认、临时文件替换；单测覆盖格式保持 | 手工验证取消和确认路径 |
| Core 失败路径 | 已实现 | 单测覆盖不支持格式、坏图解码失败、输出目录不可用；格式边界测试锁定 GIF/WebP/PDF 不支持 | GUI 混合批次仍需手工验证 |
| 总计 Ate / Pooped / Saved | 已实现 | `ImagePetStore` 汇总，GUI 展示 | 手工核对展示 |
| Reveal in Finder | 已实现 | GUI 调用 Finder reveal/open | 手工点击验证 |
| Retry Failed | 已实现 | 失败任务重置后重跑 | 用坏文件混入批次验证 |
| Compress More | 已实现 | 清空队列并保留设置 | 手工验证设置保留 |
| Committed Xcode project | 已完成 | `ImagePet.xcodeproj` 已入库 | CI 后续直接用 Xcode project |
| 自动化 UI 测试 | 已实现 | `ImagePetUITests` 覆盖 8 个核心交互与功能用例 | 持续集成持续验证 |

## 已验证

最近一次验证结果：

```text
swift test
结果：通过
测试数：19
性能与鲁棒性验证：通过（20张并行压缩，耗时 0.22 秒，峰值内存 159 MB）
```

```text
xcodebuild -project ImagePet.xcodeproj \
  -scheme ImagePet \
  -configuration Debug \
  -derivedDataPath DerivedData \
  -destination 'platform=macOS' \
  test
结果：通过
测试数：27 (19 Unit Tests + 8 UI Tests)
性能与鲁棒性验证：通过（20张并行压缩，耗时 0.22 秒，峰值内存 161.6 MB）
```

```text
./script/build_and_run.sh --verify
结果：通过
```

Apple fixture 压缩测试：

```text
fixture 数量：16
原始总大小：4.8 MB
输出总大小：2.6 MB
节省：2.2 MB / 45.8%
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
- 选择 Balanced，按需切换输出格式、最大边长和元数据剥离选项。
- 分别验证 Designated Folder、Original Folder 和 Overwrite Original 三种保存模式。
- 覆盖模式下确认二次确认弹窗，且输出保持每张图片的原始格式。
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
- V0.4 桌面 Pet 产品化剩余验收
- V0.5 桌面 Pet Mini / Full 双态实现
- 更复杂宠物动画资源
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
