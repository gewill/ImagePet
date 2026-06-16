# ImagePet MVP Progress

更新日期：2026-06-16

## 当前状态

MVP 工程骨架、核心压缩 workflow、桌面 Pet、WebP / Advanced JPEG、V0.11 App 完整性、V0.12 系统级集成，以及 V0.13 本地通知与发布完整性闭环已经实现。当前所有自动化 Unit Tests / UI Tests 均已全量通过，可以进入发布前的手工验收、性能验收和分发签名准备。

已完成：

- SwiftUI macOS app scaffold
- `ImagePetCore` 压缩核心
- GUI 拖拽、队列、状态展示和输出目录选择
- `Add Images` 菜单/按钮输入入口
- 桌面宠物小窗第一版
- 桌面 Pet UI、动效和轻量交互优化
- 桌面 Pet 可爱内置主题扩展（Mochi Bunny）
- V0.3 输出格式、保存位置、覆盖确认、尺寸限制和元数据剥离选项
- V0.9 WebP 与自定义压缩质量
- V0.10 Advanced JPEG (mozjpeg) 并行双引擎
- V0.11 离线 Help Center、菜单整理、设置页分区和可自定义全局快捷键
- V0.12 系统级集成 (Finder 快速操作、文件夹监听、Shortcuts 快捷指令集成)
- V0.13 本地通知与发布完整性闭环 (Batch Summary 模型、Folder Watching 2秒防抖合并、Shortcuts/Folder Watching 智能静默与防骚扰策略、20条通知历史持久化与 Debug UI、独立发布 Checklists)
- App Sandbox entitlements
- committed `ImagePet.xcodeproj`
- SwiftPM 和 Xcode build/test 路径
- 本地 Apple 测试素材 fixture
- 真实图片批量拖入与压缩的手工 GUI 验收

尚未完成验收：

- Developer ID notarization workflow
- 真实手工录制并触发 global shortcuts 的发布前 smoke

已自动化验证：

- 性能与鲁棒性验收：已实现自动化并发压缩测试，跑完 20 张大图，最近一次总耗时 0.22 秒，内存峰值约 174.2 MB（限制为 1.5GB），且单图失败不会崩溃（由 `PerformanceAndRobustnessTests` 验证）。
- UI 与交互验收：已实现 XCUITest 自动化 UI 测试，包含首屏加载、质量预设更改、桌面宠物小窗开关、桌面宠物返回主窗口、完成态动作、失败重试、覆盖确认、批量压缩完整流程、Help Center 和 Keyboard Shortcuts 设置区（由 `ImagePetUITests` 验证）。

## 追踪入口

- 产品需求基线：[PRD.md](PRD.md)
- V0.3 扩展需求：[PRD_v0.3.md](PRD_v0.3.md)
- V0.4 桌面 Pet 规划：[PRD_v0.4_desktop_pet.md](PRD_v0.4_desktop_pet.md)
- V0.5 桌面 Pet 双态规划：[PRD_v0.5_desktop_pet_dual_state.md](PRD_v0.5_desktop_pet_dual_state.md)
- V0.7 静默桌面 Pet 常驻与主题扩展规划：[PRD_v0.7_desktop_pet_expansion.md](PRD_v0.7_desktop_pet_expansion.md)
- V0.9 WebP 与自定义压缩质量规划：[PRD_v0.9_webp_custom_quality.md](PRD_v0.9_webp_custom_quality.md)
- V0.10 Advanced JPEG 与 mozjpeg 规划：[PRD_v0.10_advanced_jpeg_mozjpeg.md](PRD_v0.10_advanced_jpeg_mozjpeg.md)
- V0.11 App 完整性、帮助中心与可自定义快捷键规划：[PRD_v0.11_app_completeness.md](PRD_v0.11_app_completeness.md)
- V0.12 系统级集成与自动化工作流规划：[PRD_v0.12_system_integration.md](PRD_v0.12_system_integration.md)
- V0.13 本地通知与发布完整性闭环规划：[PRD_v0.13_local_notifications_and_release_completeness.md](PRD_v0.13_local_notifications_and_release_completeness.md)
- 项目说明与架构：[../README.md](../README.md)
- Agent 协作规则：[../AGENTS.md](../AGENTS.md)

## 功能追踪

| 模块 | 状态 | 证据 | 下一步 |
| --- | --- | --- | --- |
| JPG / JPEG / PNG / HEIC 输入 | 已实现 | `SupportedImageFormat` + ImageIO 解码；fixture 覆盖 JPG/PNG/HEIC | 用真实 iPhone HEIC 做手工验收 |
| Original / JPEG / PNG / HEIC 输出 | 已实现 | `OutputFormat` + ImageIO 写出；覆盖模式强制保持原格式 | 检查输出色彩和方向样本 |
| WebP | 已实现，本机验证通过 | Swift-WebP `0.6.1` + libwebp-Xcode `1.5.0`；`EncoderCapabilities` 分离 read/write；WebP encode/decode/bitstream inspection/alpha round-trip 单测覆盖；`Package.resolved` 与 `docs/THIRD_PARTY_NOTICES.md` 已归档 | 手工验证 Preview/Safari/Chrome 打开输出 WebP；补齐旧 macOS/CI/虚拟机验证；Developer ID/notarization 发布前 smoke |
| Advanced JPEG / mozjpeg | 已实现，本机验证通过 | `awxkee/mozjpeg.swift` `1.1.3` 已接入；`EncoderCapabilities.jpegEncodingModes` 分离 standard/advanced；Advanced JPEG 只影响 JPEG 输出并由 smoke encode gate 控制；Third Party Notices 已扩展 | 补 benchmark fixture、Preview/Safari/Chrome 打开验证、Developer ID/notarization smoke |
| App 完整性 / 帮助中心 / 可自定义快捷键 | 已实现，本机验证通过 | `KeyboardShortcuts` `3.0.0` 只接入 GUI target；`HelpView` 离线帮助窗口、`AppSettingsView` 设置分区、`GlobalShortcutCoordinator` 默认 unset 全局快捷键、菜单分组与 Help window 已实现；XCUITest 覆盖 Help 与 Keyboard Shortcuts 设置入口 | 发布前手工录制并触发 Show Main Window / Toggle Desktop Pet global shortcuts |
| AVIF 不做 | 已锁定 | V0.9 仍明确排除 AVIF，避免格式范围失控 | 保持范围，不引入 AVIF |
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
| 桌面 Pet Mini / Full 双态实现 | 已实现 | `docs/PRD_v0.5_desktop_pet_dual_state.md` 明确 Mini 只显示 Pet、Full 负责解释和操作、阻塞状态自动展开 | 自动化 UI 测试与单元测试已完全覆盖 |
| 桌面 Pet 内置主题扩展 | 已实现 | 新增 `MochiBunny` 76 帧透明 PNG 主题；设置页主题卡、Help 文案和内置主题资源规格测试已同步 | 手工检查 Mini / Full 尺寸下兔子轮廓、长耳朵和状态动画是否清晰 |
| 静默桌面 Pet 常驻与内置主题扩展规划 | 已规划 | `docs/PRD_v0.6_desktop_pet_animations.md` 与 `docs/PRD_v0.7_desktop_pet_expansion.md` 明确内置动画集、Launch at Login 静默启动、既有 Pet 直接拖拽验收、至少 1 套新增内置主题；自定义导入延后 | 进入 v0.7 技术设计评审 |
| 非覆盖模式不覆盖原文件 | 已实现 | `OutputNameAllocator` + 单测覆盖冲突和后缀清洗 | 覆盖同名真实文件场景 |
| 覆盖模式保护 | 已实现 | UI 强制原格式、二次确认、临时文件替换；单测覆盖格式保持 | 手工验证取消和确认路径 |
| Core 失败路径 | 已实现 | 单测覆盖不支持格式、坏图解码失败、输出目录不可用、WebP read/write capability 分离、WebP write 不可用的 skipped reason；GIF/PDF/SVG/TIFF 继续拒绝 | 补充真实 animated WebP fixture 拒绝测试 |
| 总计 Ate / Pooped / Saved | 已实现 | `ImagePetStore` 汇总，GUI 展示 | 手工核对展示 |
| Reveal in Finder | 已实现 | GUI 调用 Finder reveal/open | 手工点击验证 |
| Retry Failed | 已实现 | 失败任务重置后重跑 | 用坏文件混入批次验证 |
| Clear List | 已实现 | 清空队列并保留设置 | 手工验证设置保留 |
| Committed Xcode project | 已完成 | `ImagePet.xcodeproj` 已入库 | CI 后续直接用 Xcode project |
| 自动化 UI 测试 | 已实现 | `ImagePetUITests` 覆盖 17 个核心交互与功能用例 | 持续集成持续验证 |
| CLI 命令行工具 (`imagepet`) | 已实现 | `Sources/ImagePetCLI` + `swift-argument-parser` 接入完成并发布独立的可执行文件 | 加入 CI 测试构建流程 |
| 文件夹监听 (Folder Watching) | 已实现 | `FolderMonitor` + Security-scoped bookmarks 并在 `AppSettingsView` 提供管理界面 | 真实长期运行内存与泄漏验证 |
| Finder 快速操作 (Quick Actions) | 已实现 | Info.plist NSServices 声明与 AppDelegate 的 `handleServices` | 手工在 Finder 多选图片右键压缩验证 |
| 快捷指令 (Shortcuts) 集成 | 已实现 | `AppIntents` 编写 `CompressImagesIntent` 并注册 `ImagePetShortcuts` | 真实 Shortcuts app 内搜索动作和传参验证 |
| 本地通知与发布完整性闭环 | 已实现，本机验证通过 | 整合 `CompressionBatchSummary` 摘要模型、`LocalNotificationManager` 包含防抖合并、防骚扰限频与 Shortcuts/Folder Watching 静默成功策略、历史纪录持久化、设置页面通知控制项及 Debug UI、独立 `RELEASE_CHECKLIST.md` | 手工触发不同入口压缩检查通知展示与通知动作的 Finder 唤起 |

## 已验证

最近一次验证结果：

```text
swift test
结果：通过
测试数：46
性能与鲁棒性验证：通过（21 个 job，18 个成功、1 个预期失败，耗时 0.21 秒，峰值内存 169.6 MB）
```

```text
xcodebuild -project ImagePet.xcodeproj \
  -scheme ImagePet \
  -configuration Debug \
  -derivedDataPath DerivedData/UserBuild \
  -destination 'platform=macOS' \
  test
结果：通过
测试数：65 (46 Unit Tests + 19 UI Tests)
性能与鲁棒性验证：通过（21 个 job，18 个成功、1 个预期失败，耗时 0.22 秒，峰值内存 174.2 MB）
UI suite：通过（19 tests，196.522 秒）
```

KeyboardShortcuts dependency spike：

```text
KeyboardShortcuts version: 3.0.0
revision: f7d08ba4109d5ca025e1a64165be169cdf089206
target boundary: ImagePet GUI target only; ImagePetCore remains dependency-free
global shortcut defaults: unset
settings UI: KeyboardShortcuts.Recorder renders for Show Main Window, Toggle Desktop Pet, Toggle Pet Mini / Full
handler smoke: UI-test registration disabled through IS_UI_TESTING to avoid global hotkey side effects
manual trigger smoke: pending before release candidate
license: MIT, archived in docs/THIRD_PARTY_NOTICES.md
```

Swift-WebP dependency spike：

```text
macOS version: 26.5.1 (25F80)
hardware / runner: local arm64 Mac
Swift / Xcode version: Swift 6.3.2 / Xcode 26.5 (17F42)
Swift-WebP version: 0.6.1
libwebp-Xcode version: 1.5.0
SPM resolve: pass
swift test: pass
xcodebuild test: pass
app sandbox smoke: pass, sandbox entitlement present in Debug build
codesign smoke: pass, adhoc Debug signature
notarization smoke: not verified
Swift-WebP encode: yes
Swift-WebP decode: yes
bitstream inspection: yes
alpha: pass, 100% transparent and 50% alpha fixtures covered
animated/multi-frame rejection: not verified with real animated fixture
Preview open: not verified
Safari open: not verified
Chrome open: not verified
ImageIO fixture comparison: not verified
notes: WebP write/read capability is injectable for tests; WebP write unavailable maps to a skipped result reason.
```

mozjpeg.swift dependency spike：

```text
macOS version: 26.5.1 (25F80)
hardware / runner: local arm64 Mac
Swift / Xcode version: Swift 6.3.2 / Xcode 26.5 (17F42)
mozjpeg.swift version: 1.1.3
mozjpeg.swift revision: 42aaf0105aa7cd5640397306577bda756863003a
bundled libturbojpeg artifact: Sources/libturbojpeg.xcframework
macOS artifact architecture: arm64 + x86_64
reported header version: LIBJPEG_TURBO_VERSION 4.1.0
SPM resolve: pass
standalone mozjpeg.swift swift test: pass, 1 placeholder test
ImagePet swift test: pass, 38 tests
Advanced JPEG smoke encode: pass
ImageIO decode of Advanced JPEG output: pass in unit test
xcodebuild targeted Desktop Pet overwrite UI regression: pass
xcodebuild test: pass, 38 unit tests + 19 UI tests
./script/build_and_run.sh --verify: pass
app sandbox smoke: pass in local Debug build entitlement inspection
codesign smoke: pass with local ad-hoc signing
notarization smoke: not verified
benchmark fixture: pending
Preview open: not verified
Safari open: not verified
Chrome open: not verified
notes: mozjpeg.swift README still lists file handling and tests as TODO, so ImagePet keeps capability gate and its own integration tests.
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
- 点击 `Clear List`，确认队列清空，quality 和输出目录保留。
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
- V0.6 桌面 Pet 富动画与自定义资产开发
- Raycast Extension

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
