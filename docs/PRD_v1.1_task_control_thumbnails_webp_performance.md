# ImagePet PRD v1.1: 任务控制、队列布局、缩略图与 WebP 性能优化

## 1. 版本定位

v1.1 是 ImagePet 首发后的小版本修补与性能版本。它不扩大输入/输出格式范围，不引入 AVIF、PDF、云端能力或 AI 决策，而是把真实批量压缩时最影响体验的几个点收束起来：

```text
用户能看清正在处理什么，能中止不想继续的任务，能在长列表里高效管理单个文件，并让 WebP 在可用系统能力下更快、更稳。
```

本版本的核心不是重做压缩架构，而是补齐任务控制和结果可读性，并对 WebP 进行一次 Apple 官方 ImageIO / UTType 路线的可发布性 spike。如果 Apple 官方 WebP 在目标 macOS 版本上不满足读写、质量、alpha、动画拒绝和输出体积策略，v1.1 必须保留当前 Swift-WebP / libwebp 路线。

## 2. 当前基线

截至 v0.16：

- ImagePet 已支持 `JPG / JPEG / PNG / HEIC / WebP` 静态输入。
- 已支持 `Original / JPEG / PNG / HEIC / WebP` 输出。
- WebP 当前通过 Swift-WebP `0.6.1` + libwebp-Xcode `1.5.0` 实现，并通过 capability gate 分离 read/write。
- 队列当前限制 `maxConcurrentJobs = 2`，单图失败不会中断批次。
- GUI 已显示每张图的文件名、状态、原始大小、输出大小、节省比例和错误原因。
- 已有 Retry Failed、Clear List、Reveal in Finder、覆盖原图确认和保存位置选择。

v1.1 在此基础上处理三个问题：

- 用户开始大批量任务后缺少明确的中止能力。
- 队列中图片识别主要依赖文件名，真实批量素材不够直观。
- 主窗口长列表占用过多空间，缺少可收起的队列区域和单文件快速管理动作。
- WebP 依赖第三方 libwebp，发布包体积、维护、安全更新和性能仍有优化空间。

## 3. P0 范围

### 3.1 中止任务

用户必须能在批量处理中中止剩余任务。

要求：

- 主窗口在有 `pending` 或 `processing` job 时显示 `Cancel` 或等价明确动作。
- 中止后：
  - 尚未开始的任务标记为 `Canceled`。
  - 正在处理的任务尽力取消；如果底层编码无法抢占，允许当前文件完成，但不得继续启动新的 pending job。
  - 已完成的输出文件保留，不做自动删除。
  - 已失败的任务保持失败状态。
- 取消不等同于失败，不触发“单图失败”错误文案。
- 总结区域必须能区分 done / failed / canceled / skipped。
- 桌面 Pet 在取消后进入中性完成态或 issues 态，但文案必须说明是用户取消，不要显示为权限错误或压缩崩溃。
- `Retry Failed` 不应重跑 canceled jobs；若需要重跑，用户通过重新添加图片或明确的 `Retry Canceled` 后续能力处理。
- `Clear List` 仍可清空 canceled 队列。

Core 约束：

- `ImagePetCore` 不引入 SwiftUI/AppKit 依赖。
- 取消信号从 app 层传入队列和压缩服务，不能靠杀进程或抛弃 store 状态模拟。
- 安全写入仍使用临时文件替换策略；取消过程中不得留下半写入的目标文件。
- security-scoped access 必须继续用 `defer` 成对释放。

### 3.2 缩略图

队列每个 job 应显示轻量缩略图，帮助用户确认批量素材。

要求：

- 支持 JPG / PNG / HEIC / WebP 静态图片缩略图。
- 缩略图生成失败时显示稳定占位，不影响压缩任务。
- 缩略图不改变压缩结果、不写入输出文件、不修改 metadata。
- 缩略图必须异步生成，不能阻塞拖拽、Add Images 或主压缩队列。
- 大图缩略图必须有像素和内存上限，例如最长边不超过 `160 px`。
- 用户可以在界面中调整队列缩略图显示尺寸，至少提供 small / medium / large 三档或等价连续控制。
- 缩略图尺寸调整只影响当前 UI 展示，不改变压缩结果、输出 metadata 或 benchmark 数据。
- 缩略图尺寸设置必须有合理默认值，并在长列表下避免造成行高抖动或滚动性能明显下降。
- 缩略图缓存只保留当前队列所需的内存态结果；v1.1 不做持久缓存。
- 对 animated / multi-frame WebP 继续按当前不支持策略处理；缩略图不能让不支持输入看起来可压缩。

UI 验收：

- 队列列表在窄窗口下仍不拥挤，缩略图、文件名、状态、大小和动作不重叠。
- 缩略图尺寸切换后，已加载缩略图应稳定重排；未加载或失败缩略图继续显示稳定占位。
- VoiceOver 能读出文件名和状态；缩略图本身不需要重复读出装饰性内容。
- Reduce Motion 不影响缩略图显示。

### 3.3 主界面布局、设置窗口与单项管理

v1.1 需要改善长队列下的主窗口可用性，但不重做整体视觉系统。

要求：

- **左右布局与收起**：主窗口采用左右布局，左侧为参数设置与面板控制，右侧为队列列表、状态与统计。
  - 左侧为参数面板（`ControlsView`），并包含缩略图显示尺寸 picker。
  - 右侧为主内容区域（`HeaderView` 桌面 Pet、`DropZoneView` 拖拽区、`JobListView` 任务列表、`SummaryView` 统计与全局动作按钮）。
  - 左侧参数面板可以收起和展开，收起后右侧队列列表获得完整的窗口水平宽度。
  - 收起状态下必须在左侧保留轻量折叠条和展开入口（如 gearshape 图标或展开按钮）。
- **设置窗口独立化 (macOS HIG)**：
  - 依照 macOS HIG 最佳规范，应用的通用设置、文件夹监听、快捷键和通知设置（`AppSettingsView`）彻底从主窗口 TabView 中剥离，声明为 macOS 原生独立 Settings 场景窗口。
  - 用户可通过快捷键 `⌘,`、App Menu -> "Settings..." 或主窗口左侧面板底部的 Gear 按钮呼出独立设置窗口。主窗口去除 TabView 标签栏。
- **队列单项管理**：每个队列 item 必须提供单独删除动作：
  - 删除 pending / failed / skipped / canceled / done job 只从当前队列移除，不删除源文件或已输出文件。
  - processing job 不允许直接删除；可禁用删除动作并提示先取消批量任务，或等当前文件结束后再删除。
  - 删除单项后，统计、Pet 状态、缩略图缓存和后续 Retry Failed 行为必须同步更新。
- **单项 Reveal in Finder**：每个已知文件位置的队列 item 必须提供 `Reveal in Finder` / `Show in Folder` 等价动作：
  - 输入文件存在时优先显示输入文件。
  - 已完成输出文件存在且当前语境是结果查看时，可以显示输出文件。
  - 文件不存在或权限不可用时显示短错误（如提示“File not found”），不崩溃、不阻塞队列。
- **全局动作归口**：批量 `Clear List`、`Retry Failed`、`Reveal in Finder` 和 `Cancel` 动作按钮收拢在右侧底部的 `SummaryView` 中，与队列内容保持在一起。

UI 验收：

- 20 张以上图片的列表在默认窗口尺寸下可浏览、宽度自适应（尤其在左侧参数栏收起后）。
- 左侧收起/展开不应重置队列、取消状态、缩略图尺寸或当前输出设置。
- 单项删除后，列表选择、统计摘要、Retry Failed 和缩略图缓存状态一致。
- 单项 `Reveal in Finder` 能正确打开对应文件所在位置；失败时提示文案短且自动恢复。
- `⌘,` 快捷键能唤起独立的设置窗口，且各个设置模块的切换、绑定逻辑完全正常。

### 3.4 WebP Apple 官方路线 spike

v1.1 需要尝试 Apple 官方 WebP 路线，但必须以数据决策，而不是直接替换。

候选能力：

- `UniformTypeIdentifiers.UTType.webP`
- `CGImageSource` 读取 WebP
- `CGImageDestination` 写出 WebP
- ImageIO WebP properties 与 multi-frame / animation detection

Apple 官方参考：

- [UTType.webP](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/webp)
- [Image I/O](https://developer.apple.com/documentation/imageio)
- [CGImageDestination](https://developer.apple.com/documentation/imageio/cgimagedestination)
- [ImageIO WebP Data](https://developer.apple.com/documentation/imageio/webp-data)

必须验证：

- macOS 13 / 14 / 15 / 26 可获得环境下的 WebP read capability。
- macOS 13 / 14 / 15 / 26 可获得环境下的 WebP write capability。
- quality 参数是否对 WebP 输出有效。
- alpha round-trip 是否正确。
- static WebP 是否能被 Preview / Safari / Chrome 打开。
- animated / multi-frame WebP 是否能稳定检测并拒绝。
- 输出体积是否遵守现有 `output larger than source => skipped` 策略。
- 与当前 Swift-WebP 输出相比的耗时、峰值内存、输出大小和视觉回归。
- MAS sandbox、codesign、notarization smoke 是否正常。

决策：

- 如果 Apple ImageIO WebP 在目标系统上读写能力、质量控制、alpha、动画拒绝、输出体积和性能均满足要求，v1.1 可以新增 `AppleWebPEncodingEngine` 并优先使用 Apple 官方路线。
- 如果 Apple ImageIO 只能读不能写、质量不可控、alpha 不可靠、动画检测不稳定或旧系统能力不一致，v1.1 保留 Swift-WebP 为主路径，只把 Apple ImageIO 作为 decode/fixture comparison 或后续 fallback。
- 无论采用哪条路线，WebP read/write capability 必须继续分离，UI 继续受 capability gate 控制。

### 3.5 WebP 性能优化

WebP 优化必须先建立可重复 benchmark，再改实现。

benchmark 至少覆盖：

- JPEG -> WebP，PNG -> WebP，HEIC -> WebP，WebP -> WebP。
- 小图、常见手机图、大图。
- 有 alpha 的 PNG/WebP。
- 至少一组“输出变大”的样本。

记录指标：

- 单图耗时。
- 20 张混合批量总耗时。
- 峰值内存。
- 输出总大小。
- skipped / failed / canceled 计数。
- 所用引擎：Swift-WebP、Apple ImageIO 或 fallback。

性能目标：

- 不牺牲正确性和 sandbox 安全。
- 不突破 `maxConcurrentJobs = 2`。
- WebP 路径在同等质量下应比现状更快或更省内存；如果只带来依赖治理收益，也必须在 PRD 完成记录中明确说明。

## 4. P1 范围

- 单个 job 的取消按钮。
- `Retry Canceled`。
- 持久缩略图缓存。
- WebP lossless toggle。
- 更细的 WebP advanced options，例如 method、near-lossless、exact alpha。
- 自动选择 Swift-WebP 或 Apple ImageIO 的 per-file best engine。

## 5. 非目标

v1.1 明确不做：

- AVIF、JPEG XL、PDF、GIF 输出。
- 动画 WebP 支持。
- WebP Lossless 首发。
- 云端压缩、登录、同步、遥测。
- AI 格式判断或 AI 画质判断。
- 重做主窗口视觉系统。
- 多窗口队列管理、独立详情页或历史记录数据库。
- 改变覆盖原图确认规则。
- 把 CLI 扩展为完整任务控制 UI。
- 取消后自动删除已完成输出文件。

## 6. 数据模型与状态口径

建议扩展任务状态：

```swift
enum JobStatus: Equatable {
    case pending
    case processing
    case done
    case failed
    case skipped
    case canceled
}
```

取消状态文案：

```text
Canceled
```

WebP 输出不可用文案继续保持短句：

```text
WebP output is unavailable on this Mac
```

输出变大继续使用明确 skipped reason：

```text
Output would be larger than source
```

## 7. 技术边界

- `Sources/ImagePetCore` 只包含压缩、编码、缩略图生成所需的无 UI 逻辑。
- `Sources/ImagePet` 负责按钮、列表、Pet 状态、队列绑定和用户提示。
- `ImagePet.xcodeproj` 是 CI 和本地验证入口；如果新增 Swift 文件必须更新 Xcode project。
- `project.yml` 仍只是可选 scaffolding，不作为提交后唯一 source of truth。
- 继续保留 app sandbox 与 user-selected read/write entitlement。
- 不引入运行时下载 codec 或外部命令行工具依赖。

## 8. 验收标准

自动化：

```bash
swift test
xcodebuild -project ImagePet.xcodeproj -scheme ImagePet -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' test
./script/build_and_run.sh --verify
git diff --check
```

必须新增或更新测试覆盖：

- cancel pending jobs。
- cancel while processing，不启动后续 pending jobs。
- canceled 不被 `Retry Failed` 重跑。
- 取消后 security-scoped access 释放。
- 缩略图生成成功和失败占位。
- 缩略图生成不阻塞压缩队列。
- 缩略图尺寸调整不改变压缩结果或 job 状态。
- 单项删除会更新统计、Retry Failed 目标和缩略图缓存。
- 单项 `Reveal in Finder` 成功路径和文件缺失失败路径。
- Apple WebP capability probe。
- Apple WebP 与 Swift-WebP 的 read/write gate 分离。
- WebP benchmark fixture 至少能在本机跑出稳定记录。

手工验收：

- 拖入 20 张真实 JPG / PNG / HEIC / WebP，开始压缩后中止，确认已完成文件可用、未开始任务显示 canceled、没有继续写新文件。
- 混入坏图和不支持格式，中止后确认 failed / skipped / canceled 分别可读。
- 队列缩略图显示正常，滚动时不卡顿。
- 主窗口左右布局在默认窗口、窄窗口和较宽窗口下均可用；左侧队列可收起和恢复。
- 缩略图 small / medium / large 或等价控制可用，长列表滚动无明显卡顿。
- 单项删除不会删除磁盘文件，且不会让统计、Retry Failed 或 Pet 状态残留旧数据。
- 单项 `Reveal in Finder` / `Show in Folder` 能定位输入或输出文件。
- WebP 输出用 Preview / Safari / Chrome 打开。
- MAS sandbox 或 release-like build 下重复验证输出目录、原目录保存和覆盖确认。

## 9. 完成标准

v1.1 可以标记为完成，当且仅当：

- P0 任务控制、队列布局、单项管理、缩略图和 WebP benchmark / spike 均完成。
- Apple WebP 路线有明确采用或不采用结论，并写回 `docs/PROGRESS.md`。
- 自动化验证全部通过，或失败项有明确阻断记录。
- 真实批量图片手工验收通过。
- 没有引入 AVIF、动画 WebP、云端能力或 AI 决策等范围外功能。
