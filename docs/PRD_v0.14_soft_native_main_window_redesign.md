# ImagePet PRD v0.14: Soft Native 主窗口重设计方案

## 1. 版本定位

v0.14 是一次设计系统落地与主窗口重设计方案，不扩大 ImagePet 的压缩格式、系统入口或核心能力范围。

它的目标是把现有功能收束成一个更清晰、更可爱的 macOS 压缩工作台：

```text
ImagePet keeps the compression workflow native, soft, and focused: feed images to the pet, watch progress, and understand the result without dashboard noise.
```

本 PRD 只定义方案与验收标准。当前阶段不进入开发。

## 2. 设计输入

### 2.1 设计系统基线

以仓库根目录 `DESIGN.md` 作为 v0.14 的设计基线：

- Product: ImagePet
- Platform: macOS
- Personality: cute, lightweight, fast, trustworthy
- Visual metaphor: a small desktop pet that eats big images and outputs smaller files
- Style: native macOS, soft, playful, not childish
- Colors: warm cream background, mint green accent, soft orange secondary
- Typography: SF Pro, rounded feeling where appropriate
- Motion: small bounce when compression completes, subtle breathing idle pet
- Anti-patterns: no busy dashboard, no corporate SaaS look, no fake AI glow, no childish toy UI

### 2.2 Open Design 参考稿

参考本仓库内改版后的 Open Design Soft Native 主窗口：

```text
docs/SoftNative.html
```

采用的方向：

- `Soft Native` 视觉语言。
- warm cream 背景、半透明 macOS window surface、mint accent、soft orange 运行状态。
- 顶部 macOS window bar + 右侧 `Show Pet` / `Add Images` 行动区。
- hero 文案 + mascot tile。
- 横向 controls strip。
- dashed drop zone。
- table-like queue rows。
- 简短 summary metrics。

当前参考稿已删除：

- 左侧 sidebar / nav panel。
- 底部 `Compress` 按钮。

实现阶段仍不采用 Open Design 页面外层说明 chrome，例如 `Soft Native` 大标题、`Back to directions` 链接、stage wrapper。

## 3. 当前基线

截至 v0.13：

- 主窗口由 `ContentView` 驱动，当前顶层是 `TabView`，包含 `Compress` 与 `Settings`。
- `Compress` tab 内包含 `HeaderView`、`ControlsView`、`DropZoneView`、`JobListView`、`SummaryView`。
- 用户通过 `Add Images` 或拖拽添加图片，`ImagePetStore.addInputURLs(...)` 会自动触发 `startProcessingIfPossible()`。
- 覆盖原图模式仍通过主窗口 `confirmationDialog` 二次确认。
- 桌面 Pet 由 `DesktopPetPresenter` / `DesktopPetView` / `DesktopPetWindowController` 负责呈现，状态与动作仍由 `ImagePetStore` 统一管理。
- 设置页、帮助中心、全局快捷键、文件夹监听、通知历史等已存在。

v0.14 不重写业务状态机。重设计应尽量复用现有 store、状态、accessibility identifier 和验证路径。

## 4. P0 范围

### 4.1 主窗口布局：无左侧 panel 的单一工作台

主窗口第一屏应改为一个聚焦的 compression workspace：

```text
window bar
hero + pet tile
controls strip
drop zone
queue
summary / contextual actions
```

要求：

- 不引入左侧 nav / sidebar。
- 主压缩流程不被设置、快捷键、帮助入口挤占首屏。
- `Settings` 可以继续通过现有 tab、菜单或后续 native Settings 路径进入，但主压缩视图本身必须保持无左侧 panel。
- 主窗口最小尺寸继续适配现有 macOS app 使用场景，目标不小于当前 `780 x 640` 基线；实现阶段可评估提升到约 `860 x 640` 以容纳横向 controls strip。

### 4.2 顶部 window bar 与主要行动

顶部保留 macOS 原生窗口感：

- 左侧 traffic lights 由系统窗口提供，不自绘。
- 中心标题保持 `ImagePet`。
- 右侧保留两个稳定行动：
  - `Show Pet` / `Hide Pet`
  - `Add Images`

要求：

- `Add Images` 是唯一的常驻主按钮。
- `Show Pet` 是次级行动。
- 不新增常驻 `Compress` 按钮。
- 保留键盘快捷键：`Command-O` 添加图片、`Shift-Command-P` 切换 Pet。

### 4.3 Hero + mascot tile

参考稿的 hero 结构应转换为 SwiftUI native 组件：

- 标题：`Ready to shrink images` 或状态化短标题。
- 副标题：说明支持格式、输出行为或当前进度。
- 右侧 mascot tile 使用当前选中主题的 idle/eating/done/issues 静帧。

状态映射：

| 状态 | 标题方向 | Mascot |
| --- | --- | --- |
| 空队列 | Ready to shrink images | idle |
| 拖拽悬停 | Drop them here | dragHover 或 idle accent |
| 处理中 | Eating images | eating |
| 全部成功 | Saved space | done |
| 部分失败/跳过 | Done with issues | issues |
| 需要授权 | Choose an output folder | issues / permission copy |

要求：

- pet tile 是状态反馈，不是独立控制面板。
- 不把 mascot 变成大面积营销插画。
- Reduced Motion 开启时只切换静态帧，不播放 bounce。

### 4.4 Controls strip

参考稿的横向 controls strip 是 v0.14 的核心布局方向。P0 包含四个首屏控制组：

- Quality
- Format
- Max edge
- Save to

要求：

- 使用 macOS native segmented picker 或等价 SwiftUI 组件。
- 保持现有业务约束：PNG 输出时禁用 lossy quality；Overwrite 模式强制 Original format；处理中禁用会改变输出行为的控件。
- `Save to` 选择为 designated folder 时，输出目录选择与状态必须在同一控制区内可见。
- 文件名 suffix、metadata、Advanced JPEG 等二级选项可以保留在 controls strip 下方的 compact details 区，不能挤占首屏主路径。

### 4.5 Drop zone

drop zone 应保留参考稿的 warm dashed surface：

- 空队列：更高、更邀请式。
- 已有队列：降低高度，文案改为 `Drop more images`。
- 拖拽悬停：mint accent border、轻微 background tint、pet 状态进入期待感。

要求：

- 仍然支持窗口级拖拽。
- 文案必须说明支持格式：JPG / PNG / HEIC / WebP。
- 不通过 drop zone 触发任何额外确认，除非业务状态本来需要输出目录或覆盖确认。

### 4.6 Queue rows

queue 应参考稿的 table-like rows，但要保留当前失败详情和真实大小信息：

列建议：

```text
File | Status | Size | Saved
```

要求：

- 行高度稳定，处理状态更新不能造成明显 layout shift。
- 文件名中间截断。
- Size / Saved 使用 monospaced 或 tabular number 风格。
- 失败、跳过、处理中、完成状态不能只靠颜色区分，必须有文字和图标/形状提示。
- 保留每个 job 的完整状态语义，不能为了视觉简化丢失错误原因。

### 4.7 Summary：无底部 Compress 按钮

旧版参考稿底部 summary 中的 `Compress` 按钮已从 `docs/SoftNative.html` 删除，v0.14 实现阶段不得恢复该按钮。

原因：

- ImagePet 当前交互是添加图片后自动开始压缩。
- 新增 `Compress` 会暗示用户还需要二次启动，和现有行为冲突。
- 覆盖原图模式已经有专门的二次确认，不应再通过全局 Compress 按钮表达风险。

summary 应根据状态显示：

| 状态 | 内容 |
| --- | --- |
| 空队列 | Quality、Output 等当前默认摘要 |
| 处理中 | Processing `completed / total` |
| 成功完成 | Files、Ate、Pooped、Saved |
| 部分失败 | Success / skipped / failed + Retry Failed |
| 需要授权 | 当前问题 + Choose Folder |

允许的 contextual actions：

- `Reveal in Finder`：仅完成后显示。
- `Retry Failed`：仅有失败任务且未处理中显示。
- `Clear List`：仅队列完成或用户可安全清空时显示。
- `Choose Folder`：仅输出目录缺失或失效时显示。

这些 action 不能表现为常驻底部主按钮。

## 5. P1 范围

P1 可在 P0 主窗口方案通过后继续：

- Settings 页面视觉同步到 Soft Native token，但不改变设置的信息架构。
- Help Center 视觉同步，保留本地帮助内容。
- Desktop Pet full mode 与主窗口 hero/pet tile 的视觉语言统一。
- 通知历史 / Folder Watching 列表改成同一 row/card 语言。
- 提供设计 token 快照文档，便于后续 SwiftUI 实现复用。

## 6. 非目标

v0.14 明确不做：

- 不新增压缩格式、压缩引擎、系统入口或自动化能力。
- 不改变 `ImagePetCore`。
- 不改变 sandbox、security-scoped bookmark、覆盖原图保护或错误文案边界。
- 不新增左侧 sidebar / nav panel。
- 不新增底部 `Compress` 按钮。
- 不把主窗口做成 dashboard。
- 不引入 fake AI glow、AI 文案、霓虹渐变或儿童玩具 UI。
- 不为了视觉重设计删除现有 Help、Settings、Notifications、Folder Watching、Shortcuts 能力。

## 7. 技术形状建议

### 7.1 SwiftUI 结构

未来实现可优先拆分 `ContentView.swift` 内部组件，而不是引入全新架构：

```text
ContentView
├── MainCompressionWorkspace
│   ├── MainWindowHero
│   ├── CompressionControlsStrip
│   ├── OutputDetailsStrip
│   ├── ImageDropZone
│   ├── CompressionQueueTable
│   └── BatchSummaryBar
└── existing settings/help/window routing
```

要求：

- 保持 `ImagePetStore` 为主状态源。
- 保持 desktop pet thin，不让 pet tile 拥有业务逻辑。
- `ImagePetCore` 不引入 SwiftUI/AppKit UI 依赖。
- 尽量保留当前 UI test 需要的 accessibility identifiers；如必须改名，应同步更新 UI tests。

### 7.2 Token 转换

Open Design CSS 是视觉参考，不直接成为生产依赖。实现阶段应将其转为 SwiftUI token：

| 参考 token | SwiftUI 方向 |
| --- | --- |
| warm cream background | window/content background material + warm tint |
| mint accent | app accent / active drop / success affordance |
| soft orange | processing / queued / compression energy |
| 8-14px radius | native rounded rectangles，标准卡片不超过 8px，pet/drop 可更圆 |
| soft shadow | restrained macOS depth，不做 web-style heavy card stack |
| SF Pro | native `.system` text styles |

### 7.3 Auto-start 保持

实现阶段必须保留：

```text
Add Images / drop files -> create jobs -> automatically start processing when possible
```

只有以下情况可阻断自动开始：

- designated output folder 缺失，需要选择 folder。
- overwrite mode 需要二次确认。
- parent folder permission 缺失，需要授权。
- 当前已有 processing task。

## 8. 验收标准

### 8.1 视觉验收

- 主压缩窗口没有左侧 panel。
- 主压缩窗口底部没有常驻 `Compress` 按钮。
- 第一屏能看到 hero、pet tile、controls strip、drop zone 或 queue 的核心区域。
- 视觉方向明显接近 Open Design direction A：warm cream、mint accent、soft orange、native material、soft but not childish。
- 没有 dashboard 化的统计卡片堆叠。
- 没有 fake AI glow 或营销式效果。

### 8.2 交互验收

- `Add Images` 和拖拽仍会自动开始压缩。
- 拖拽悬停有明确视觉反馈。
- 处理中 controls 正确禁用。
- 输出目录缺失时，用户能明确看到需要选择 folder。
- 覆盖原图模式仍触发现有二次确认。
- 完成后可以 Reveal in Finder、Retry Failed、Clear List。
- `Show Pet` / `Hide Pet` 行为保持不变。

### 8.3 可访问性验收

- 所有关键状态有文字，不只依赖颜色。
- keyboard shortcuts 保持可用。
- Reduce Motion 下不播放 bounce / breathing 类动效。
- VoiceOver 能读出 drop zone、queue row、summary、pet state。
- Focus ring 保持可见。

### 8.4 回归验证

进入实现阶段后，至少运行：

```bash
swift test
xcodebuild -project ImagePet.xcodeproj -scheme ImagePet -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' test
./script/build_and_run.sh --verify
git diff --check
```

如 UI test identifiers 或视觉结构发生变化，必须同步更新 `ImagePetUITests`。

## 9. 待评审问题

默认建议：

- 主压缩窗口不引入左侧 nav。
- `Compress` 行动继续由 Add/Drop 自动触发，不新增按钮。
- Settings 暂时不纳入 P0 重设计，避免范围扩散。

需要评审确认：

- 主窗口顶层是否继续保留 `TabView`，还是把 Settings 移到更 native 的 Settings scene / menu path。
- v0.14 是否只重做 `Compress` tab，还是顺手统一 Settings 的外观 token。
- hero 文案最终使用 `Ready to shrink images`，还是保留更有品牌感的 `Drop images here` / `Eat more, poop less.`。
- 是否需要把 Open Design mascot asset 纳入 repo，或完全使用现有 `ThemeCache` 内置主题帧。
