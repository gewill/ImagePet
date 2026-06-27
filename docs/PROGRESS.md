# ImagePet MVP Progress

更新日期：2026-06-24

## 当前状态

MVP 工程骨架、核心压缩 workflow、桌面 Pet、WebP / Advanced JPEG、V0.11 App 完整性、V0.12 系统级集成，以及 V0.13 本地通知与发布完整性闭环已经实现。V0.14 Soft Native 主窗口重设计已进入 DesignSpike 实现阶段，完成主窗口视觉重构、Desktop Pet 配色同步、窄屏控制项 2x2 响应式布局，以及主窗口激活稳定性修正。V0.15 Release Candidate 与 Mac App Store 上线准备已完成 PRD 规划；Xcode Cloud 已部署，提交 `build*` 开头的分支会自动触发打包，打包路径基本跑通。App Store Connect 与官网共享的结构化 metadata 源已建立在 `metadata/`，静态官网已建立在 `website/` 并可面向 Cloudflare Pages 构建。V0.16 桌面 Pet 主题生产与验证管线已落地 `theme.json` 包契约、离线 validator、contact sheet / preview QA 输出、主题规格更新、manifest-backed runtime metadata 加载，以及 bundled themes 模型视觉验收记录；仍不在 app 内引入 AI 生成。V1.1 任务控制、队列缩略图、主窗口队列管理、独立设置窗口、通知总开关、设置分区快捷键，以及 Apple 官方 ImageIO / UTType WebP 路线 spike 已实现并进入 RC 验收。当前版本号已推进到 `1.1` / build `11`；ASC `1.1` app store version 已创建并上传 metadata / `whatsNew`，ASC 已有一个 valid 的 `1.1` build `10` 作为现状参考，当前 RC 分支下一次 Xcode Cloud 构建应使用 build `11`。`swift test`、`xcodebuild ... test -skip-testing:ImagePetUITests`、`./script/build_and_run.sh --verify` 和 ASC metadata 校验已通过；完整 `xcodebuild ... test` 当前阻塞在本机 UI automation mode 初始化超时。下一步是等待/触发 build `11`、在 ASC attach build、完成真实批量图片、WebP 输出打开、MAS/release-like sandbox 和 App Store Connect 提交前手工验收。

已完成：

- SwiftUI macOS app scaffold
- `ImagePetCore` 压缩核心
- GUI 拖拽、队列、状态展示和输出目录选择
- `Add Images` 菜单/按钮输入入口
- 桌面宠物小窗第一版
- 桌面 Pet UI、动效和轻量交互优化
- 桌面 Pet 内置主题切换为 Dog / Pufferfish / Squirrel / Hamster / Cat / Rabbit / Clownfish，并新增 mini 自由缩放与主题默认 fps
- V0.3 输出格式、保存位置、覆盖确认、尺寸限制和元数据剥离选项
- V0.9 WebP 与自定义压缩质量
- V0.10 Advanced JPEG (mozjpeg) 并行双引擎
- V0.11 离线 Help Center、菜单整理、设置页分区和可自定义全局快捷键
- V0.12 系统级集成 (Finder 快速操作、文件夹监听、Shortcuts 快捷指令集成)
- V0.13 本地通知与发布完整性闭环 (Batch Summary 模型、Folder Watching 2秒防抖合并、Shortcuts/Folder Watching 智能静默与防骚扰策略、20条通知历史持久化与 Debug UI、独立发布 Checklists)
- V0.15 Release Candidate 与 Mac App Store 上线准备 PRD
- V0.16 桌面 Pet 主题生产与验证管线基础能力
- V1.1 任务控制、缩略图、队列布局与 WebP 性能优化实现
- App Store Connect / website 共享 metadata 源
- Cloudflare Pages 友好的静态官网
- App Sandbox entitlements
- committed `ImagePet.xcodeproj`
- SwiftPM 和 Xcode build/test 路径
- 本地 Apple 测试素材 fixture
- 真实图片批量拖入与压缩的手工 GUI 验收

尚未完成验收：

- V1.1 真实批量图片取消、单项删除、单项 Reveal in Finder 手工验收
- V1.1 WebP 输出在 Preview / Safari / Chrome 打开验证
- V1.1 MAS/release-like sandbox build smoke 与 App Store Connect 提交前材料
- 真实手工录制并触发 global shortcuts 的发布前 smoke

已自动化验证：

- 性能与鲁棒性验收：已实现自动化并发压缩测试，跑完 20 张大图，最近一次总耗时 0.21 秒，内存峰值约 168.1 MB（限制为 1.5GB），且单图失败不会崩溃（由 `PerformanceAndRobustnessTests` 验证）。
- v1.1 任务控制与缩略图验收：`TaskCancellationAndThumbnailTests` 覆盖取消后停止调度、缩略图生成与取消、缩略图尺寸调整不影响 job、单项删除清理统计/缓存、缺失文件 Reveal 错误。
- 通知设置验收：`LocalNotificationManagerTests` 覆盖通知历史、Shortcuts/Folder Watching 策略、10 分钟 attention throttle、Folder Watching debounce、App 内通知总开关持久化与关闭后阻止投递。
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
- V0.14 Soft Native 主窗口重设计方案：[PRD_v0.14_soft_native_main_window_redesign.md](PRD_v0.14_soft_native_main_window_redesign.md)
- V0.15 Release Candidate 与上线准备：[PRD_v0.15_release_candidate_and_distribution.md](PRD_v0.15_release_candidate_and_distribution.md)
- V0.16 桌面 Pet 主题生产与验证管线：[PRD_v0.16_desktop_pet_theme_authoring_pipeline.md](PRD_v0.16_desktop_pet_theme_authoring_pipeline.md)
- V1.1 任务控制、缩略图与 WebP 性能优化：[PRD_v1.1_task_control_thumbnails_webp_performance.md](PRD_v1.1_task_control_thumbnails_webp_performance.md)
- Metadata 数据源：[../metadata/README.md](../metadata/README.md)
- 静态官网：[../website/README.md](../website/README.md)
- App Store Connect Metadata 索引：[APP_STORE_METADATA.md](APP_STORE_METADATA.md)
- 项目说明与架构：[../README.md](../README.md)
- Agent 协作规则：[../AGENTS.md](../AGENTS.md)

## 功能追踪

| 模块 | 状态 | 证据 | 下一步 |
| --- | --- | --- | --- |
| JPG / JPEG / PNG / HEIC 输入 | 已实现 | `SupportedImageFormat` + ImageIO 解码；fixture 覆盖 JPG/PNG/HEIC | 用真实 iPhone HEIC 做手工验收 |
| Original / JPEG / PNG / HEIC 输出 | 已实现 | `OutputFormat` + ImageIO 写出；覆盖模式强制保持原格式 | 检查输出色彩和方向样本 |
| WebP | 已实现，本机验证通过 | SwiftWebP `0.7.0` + webp-spm `1.6.0`；`EncoderCapabilities` 分离 read/write；WebP encode/decode/bitstream inspection/alpha round-trip 单测覆盖；`Package.resolved` 与 `docs/THIRD_PARTY_NOTICES.md` 已归档 | 手工验证 Preview/Safari/Chrome 打开输出 WebP；补齐旧 macOS/CI/虚拟机验证；MAS review build smoke |
| WebP 性能优化 / Apple 官方路线 | 已评估 (不采用) | `WebPBenchmarkTests.swift` 证实当前本机环境下 `CGImageDestination` 不支持 WebP write。保留 SwiftWebP/libwebp 路线作为 write 主路径，ImageIO 作为 decode/inspect 快路径；`docs/WEBP_BENCHMARK_REPORT.md` 已记录 benchmark 结论。已添加 `AppleWebPEncodingEngine` 作未来备用 | 无 |
| Advanced JPEG / mozjpeg | 已实现，本机验证通过 | `awxkee/mozjpeg.swift` `1.1.3` 已接入；`EncoderCapabilities.jpegEncodingModes` 分离 standard/advanced；Advanced JPEG 只影响 JPEG 输出并由 smoke encode gate 控制；Third Party Notices 已扩展 | 补 benchmark fixture、Preview/Safari/Chrome 打开验证、MAS review build smoke |
| App 完整性 / 帮助中心 / 可自定义快捷键 | 已实现，本机验证通过 | `KeyboardShortcuts` `2.4.0` 只接入 GUI target；`HelpView` 离线帮助窗口、`AppSettingsView` 设置分区、`GlobalShortcutCoordinator` 默认 unset 全局快捷键、菜单分组与 Help window 已实现；XCUITest 覆盖 Help 与 Keyboard Shortcuts 设置入口；Settings 分区支持 `Command-1` 到 `Command-6` 切换 | 发布前手工录制并触发 Show Main Window / Show / Hide Desktop Pet global shortcuts |
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
| 中止任务 | 已实现，本机验证通过 | 支持 pending/processing cancel，在 `ImagePetStore` 提供 cancel 逻辑，单图失败/取消不破坏批次，UI 对应 Canceled 态；`TaskCancellationAndThumbnailTests` 覆盖取消后停止调度 | 真实 20 张混合图片手工中止验收 |
| 队列缩略图 | 已实现，本机验证通过 | 支持异步生成与限制 3 并发不阻塞 UI 线程；UI 支持 small / medium / large 缩略图尺寸；`TaskCancellationAndThumbnailTests` 覆盖缩略图生成、取消和尺寸调整 | 长列表滚动手工验收 |
| 桌面 Pet 第一版 | 已实现 | `DesktopPetWindowController` + `DesktopPetView`，可通过主界面或菜单显示/隐藏、返回主窗口并跟随状态变化 | 手工验证窗口拖动、跨 Space 和状态同步 |
| 桌面 Pet UI / 动效 / 交互优化 | 已实现 | Pet 小窗扩展到 `192x176`，增加状态色、状态徽章、主动作按钮、处理中进度条、拖拽高亮、hover 反馈和 Reduce Motion 分支 | 手工验证 Light/Dark、Reduce Motion、拖拽追加和 VoiceOver 读出 |
| 桌面 Pet Mini / Full 双态实现 | 已实现 | `docs/PRD_v0.5_desktop_pet_dual_state.md` 明确 Mini 只显示 Pet、Full 负责解释和操作、阻塞状态自动展开 | 自动化 UI 测试与单元测试已完全覆盖 |
| 桌面 Pet 内置主题扩展 | 已实现 | 内置主题已切换为 `Dog`、`Pufferfish`、`Squirrel`、`Hamster`、`Cat`、`Rabbit`、`Clownfish`；设置页主题卡、Help 文案、主题默认 fps 与资源规格测试已同步 | 继续把静态占位帧逐步替换为每个角色的正式动画序列 |
| 桌面 Pet 自由缩放 | 已实现 | 参考 Codex pet 的小桌宠可读范围，限制 mini Pet 视觉尺寸在 `64-256 px`；设置页不再提供尺寸 segment，用户仅在 mini 状态 hover Pet 后可拖拽右下角缩放手柄自由调整尺寸；full 面板保持固定尺寸；运行时和静态主题预览共用透明 padding 裁剪 | 手工验证不同屏幕与多 Space 下的尺寸切换、可见区域约束和主题预览观感 |
| 静默桌面 Pet 常驻与内置主题扩展规划 | 已规划 | `docs/PRD_v0.6_desktop_pet_animations.md` 与 `docs/PRD_v0.7_desktop_pet_expansion.md` 明确内置动画集、Launch at Login 静默启动、既有 Pet 直接拖拽验收、至少 1 套新增内置主题；自定义导入延后 | 进入 v0.7 技术设计评审 |
| 非覆盖模式不覆盖原文件 | 已实现 | `OutputNameAllocator` + 单测覆盖冲突和后缀清洗 | 覆盖同名真实文件场景 |
| 覆盖模式保护 | 已实现 | UI 强制原格式、二次确认、临时文件替换；单测覆盖格式保持 | 手工验证取消和确认路径 |
| Core 失败路径 | 已实现 | 单测覆盖不支持格式、坏图解码失败、输出目录不可用、WebP read/write capability 分离、WebP write 不可用的 skipped reason；GIF/PDF/SVG/TIFF 继续拒绝 | 补充真实 animated WebP fixture 拒绝测试 |
| 总计 Ate / Pooped / Saved | 已实现 | `ImagePetStore` 汇总，GUI 展示 | 手工核对展示 |
| Reveal in Finder | 已实现，本机验证通过 | GUI 调用 Finder reveal/open；单项 Reveal 和输出目录 Reveal 已接入，缺失文件短错误由 `TaskCancellationAndThumbnailTests` 覆盖 | 手工点击真实输入/输出文件验证 |
| Retry Failed | 已实现 | 失败任务重置后重跑 | 用坏文件混入批次验证 |
| Clear List | 已实现 | 清空队列并保留设置 | 手工验证设置保留 |
| Committed Xcode project | 已完成 | `ImagePet.xcodeproj` 已入库 | CI 后续直接用 Xcode project |
| 自动化 UI 测试 | 已实现 | `ImagePetUITests` 覆盖 17 个核心交互与功能用例 | 持续集成持续验证 |
| CLI 命令行工具 (`imagepet`) | 已实现 | `Sources/ImagePetCLI` + `swift-argument-parser` 接入完成并发布独立的可执行文件 | 加入 CI 测试构建流程 |
| 文件夹监听 (Folder Watching) | 已实现 | `FolderMonitor` + Security-scoped bookmarks 并在 `AppSettingsView` 提供管理界面 | 真实长期运行内存与泄漏验证 |
| Finder 快速操作 (Quick Actions) | 已实现 | Info.plist NSServices 声明与 AppDelegate 的 `handleServices` | 手工在 Finder 多选图片右键压缩验证 |
| 快捷指令 (Shortcuts) 集成 | 已实现 | `AppIntents` 编写 `CompressImagesIntent` 并注册 `ImagePetShortcuts` | 真实 Shortcuts app 内搜索动作和传参验证 |
| 本地通知与发布完整性闭环 | 已实现，本机验证通过 | 整合 `CompressionBatchSummary` 摘要模型、`LocalNotificationManager` 包含防抖合并、防骚扰限频与 Shortcuts/Folder Watching 静默成功策略、历史纪录持久化、设置页面通知控制项及 Debug UI、独立 `RELEASE_CHECKLIST.md` | 手工触发不同入口压缩检查通知展示与通知动作的 Finder 唤起 |
| Soft Native 主窗口重设计 | DesignSpike 已实现 | `DESIGN.md` + `docs/SoftNative.html` + `docs/PRD_v0.14_soft_native_main_window_redesign.md`；主窗口使用 Soft Native token、紧凑 header、响应式控制项、列表和 summary 视觉重构；Desktop Pet 配色同步 | `swift test`、`git diff --check`、`./script/build_and_run.sh --verify` 已通过；仍需手工视觉验收 |
| Release Candidate 与上线准备 | v1.1 RC 验收中 | `docs/PRD_v0.15_release_candidate_and_distribution.md` 已定义 RC 冻结、Xcode Cloud / ASC build、App Store Connect metadata、发布说明、反馈入口和回滚策略；`metadata/` 已建立 ASC 与网站共享 metadata 源，`website/` 已建立 Cloudflare Pages 友好的静态官网，`docs/APP_STORE_METADATA.md` 已改为 ASC 字段索引；当前 `marketingVersion=1.1`、`buildNumber=11`，ASC `1.1` version 已创建并上传 `whatsNew`，ASC 已有 valid 的 `1.1` build `10` 可作为现状参考 | 触发/等待 build `11`，在 ASC attach build，执行真实图片、WebP 打开、MAS sandbox、ASC metadata 与截图验收 |
| 桌面 Pet 主题生产与验证管线 | 基础能力已实现，本机验证通过 | `docs/PRD_v0.16_desktop_pet_theme_authoring_pipeline.md` 已定义 `theme.json` 包契约、离线 authoring run、validator、contact sheet / preview QA、visual QA 与 manifest-backed runtime 方向；当前可选内置主题已补齐 `theme.json`，`script/validate_pet_theme.py` 可离线生成 review JSON、contact sheet 与 GIF preview，运行时主题 metadata 由 manifest 优先加载并保留 fallback；`docs/theme-qa/v0.16/` 已记录 bundled themes 的 contact sheet、preview 和模型视觉验收 | 后续 PRD 再决定是否加入自定义主题导入；未来新增或替换主题时重新生成 visual QA |

## 已验证

最近一次验证结果：

```text
swift test
结果：通过
测试数：39
性能与鲁棒性验证：通过（21 个 job，10 个成功、1 个预期失败，耗时 0.21 秒，峰值内存 168.1 MB）
```

```text
xcodebuild -project ImagePet.xcodeproj \
  -scheme ImagePet \
  -configuration Debug \
  -derivedDataPath DerivedData \
  -destination 'platform=macOS' \
  test \
  -skip-testing:ImagePetUITests
结果：通过
测试数：17 ImagePetTests
任务控制与缩略图验证：通过（6 tests）
通知设置验证：通过（8 tests）
备注：完整 `xcodebuild ... test` 当前在本机 UI test runner 启用 automation mode 时超时，未进入 `ImagePetUITests` 业务用例。
```

```text
./script/build_and_run.sh --verify
结果：通过
Debug build：成功
签名与 sandbox entitlement smoke：通过
```

```text
python3 script/prepare_asc_metadata.py --asc-version 1.1
asc metadata validate --dir .codex/asc-metadata --output table
结果：通过
ASC metadata：v1.1 / whatsNew included
```

KeyboardShortcuts dependency spike：

```text
KeyboardShortcuts version: 2.4.0
revision: 1aef85578fdd4f9eaeeb8d53b7b4fc31bf08fe27
target boundary: ImagePet GUI target only; ImagePetCore remains dependency-free
global shortcut defaults: unset
settings UI: KeyboardShortcuts.Recorder renders for Show Main Window, Show / Hide Desktop Pet, Toggle Pet Mini / Full
settings section shortcuts: Command-1 through Command-6
handler smoke: UI-test registration disabled through IS_UI_TESTING to avoid global hotkey side effects
manual trigger smoke: pending before release candidate
license: MIT, archived in docs/THIRD_PARTY_NOTICES.md
```

Swift-WebP dependency spike：

```text
macOS version: 26.5.1 (25F80)
hardware / runner: local arm64 Mac
Swift / Xcode version: Swift 6.3.2 / Xcode 26.5 (17F42)
SwiftWebP version: 0.7.0
SwiftWebP revision: a85311f3d768a0ecbf4390d27d35071c840f6d77
webp-spm version: 1.6.0
webp-spm revision: c5d21d16f5d7cca8fd635869410644be9dd96522
SPM resolve: pass
swift test: pass
xcodebuild test: pass
app sandbox smoke: pass, sandbox entitlement present in Debug build
codesign smoke: pass, adhoc Debug signature
notarization smoke: not verified
SwiftWebP encode: yes
SwiftWebP decode: yes
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
ImagePet swift test: pass, 39 tests
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

- App Store Connect metadata 填写与提交
- 支持页面 URL 与隐私页面 URL 上线后回填 `metadata/app.json`
- MAS review build / TestFlight smoke
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
