# ImagePet PRD v0.4: Core Desktop Pet

## 1. 版本定位

ImagePet v0.3 已经完成从 MVP 到更完整压缩工具的扩展：主窗口支持输出格式、保存位置、覆盖确认、尺寸限制、元数据剥离和桌面 Pet 第一版。

v0.4 的重点不再继续扩张压缩能力，而是把桌面 Pet 从“附属小窗”推进为 ImagePet 的核心桌面入口：

```text
主窗口负责配置与审阅 -> 桌面 Pet 负责日常拖拽、状态反馈和轻量操作
```

一句话目标：

```text
让用户无需每次打开主窗口，也能在桌面上完成安全、可解释、低打扰的图片压缩流程。
```

## 2. 设计简报

- 产品对象：ImagePet macOS 桌面 Pet。
- 视觉来源：沿用当前 `DesktopPetView`、主窗口 SwiftUI 控件和 macOS 系统材质，不引入全新视觉系统。
- 交互级别：完整可用的产品功能，不做静态概念稿。
- 范围边界：只增强 GUI 层的桌面 Pet 体验，不改变 `ImagePetCore` 压缩算法和格式范围。

## 3. 当前实现基线

v0.4 规划基于当前仓库现状，而不是从零设计。

已存在能力：

- `DesktopPetWindowController` 创建无边框浮窗，使用 `.floating` 层级，并支持跨 Space 显示。
- 浮窗位置使用 `ImagePetDesktopPetWindow` autosave name 持久化。
- `DesktopPetView` 已支持拖入 URL、`Add Images`、隐藏 Pet、返回主应用。
- 浮窗表情和文案跟随 `ImagePetStore.petState` 更新。
- 压缩完成后，浮窗可显示 `Reveal in Finder`。
- 主窗口和菜单已支持 `Show/Hide Desktop Pet`、`Show Main Window`、`Add Images`、`Clear List`。
- XCUITest 已覆盖浮窗显示/隐藏、返回主窗口和基础压缩流程。

当前缺口：

- Pet 仍像一个状态镜像，缺少足够清晰的“桌面入口”职责。
- 完成、失败、权限缺失、覆盖确认等场景在 Pet 上的下一步操作不够完整。
- Pet 的状态文案较短，无法解释用户现在能做什么。
- 多窗口、主窗口关闭、输出目录不可用、失败重试等边界需要更明确的设计合同。
- 手工验收文档仍停留在 V0.2，桌面 Pet 的 V0.4 验收需要独立补齐。

## 4. 产品目标

### 4.1 核心目标

1. **桌面可达**：用户可以把 Pet 长期开在桌面上，把它当作最小压缩入口。
2. **低打扰**：Pet 不抢焦点、不弹出复杂配置，不把主窗口的所有设置搬到小窗里。
3. **状态可解释**：用户能在 Pet 上看懂当前是等待、处理中、成功、失败还是需要授权。
4. **操作闭环**：常用后续动作可直接完成，包括添加图片、打开主窗口、打开输出目录、重试失败、继续压缩。
5. **安全一致**：Pet 复用主窗口和 `ImagePetStore` 的权限、覆盖确认、队列和并发规则，不绕过 sandbox 约束。

### 4.2 非目标

v0.4 不做：

- 不新增 WebP、AVIF、PDF、文件夹监听、Shortcuts、Finder Extension、Raycast Extension。
- 不新增云上传、账号、同步、历史库。
- 不做 AI 自动格式判断或智能压缩建议。
- 不做复杂养成系统、积分、皮肤商店、成就、提醒推送。
- 不把 Pet 做成菜单栏应用替代品。
- 不允许 Pet 静默写入未经授权的目录。
- 不改变 `maxConcurrentJobs = 2`。

## 5. 目标用户场景

### 场景 A：Finder 中快速压缩

用户在 Finder 或桌面上选中几张图片，直接拖到浮窗 Pet 上。Pet 立即进入处理状态，显示进度和节省结果。用户不需要先找到主窗口。

### 场景 B：主窗口已关闭

用户只保留桌面 Pet。需要改压缩预设、输出格式或保存位置时，点击 Pet 顶部的主应用按钮，主窗口重新出现并激活。

### 场景 C：批量压缩完成

Pet 显示本次节省体积，并提供打开输出目录和继续压缩入口。用户可以直接从桌面完成“拖入 -> 等待 -> 打开结果”的闭环。

### 场景 D：部分失败

批次里混入损坏图片或不支持格式时，Pet 显示成功、跳过和失败数量。用户可以直接重试失败项；若仍失败，Pet 引导打开主窗口查看详细错误。

### 场景 E：需要授权

输出目录丢失、原目录模式需要父目录授权、覆盖模式需要二次确认时，Pet 不静默处理。它应显示需要用户确认的状态，并把用户带到主窗口或系统授权面板。

## 6. Pet 状态设计

Pet 状态继续由 GUI 层管理。`ImagePetCore` 不知道 Pet，也不新增 UI 依赖。

| 状态 | 触发条件 | 主文案 | 详情文案 | 首要动作 |
| --- | --- | --- | --- | --- |
| Idle | 没有任务且可接收图片 | `Ready` | `Drop images here` | `Add Images` |
| Needs Setup | 指定输出目录不可用 | `Needs folder` | `Choose output folder in app` | `Open App` |
| Eating | 存在处理中任务 | `Eating` | `3 / 12` | 无，保持进度反馈 |
| Done | 全部成功或仅有 skipped | `Done` | `Saved 2.1 MB` | `Reveal` |
| Issues | 存在失败任务 | `Issues` | `8 ok, 1 skip, 2 fail` | `Retry Failed` |
| Confirm | 覆盖原图等待确认 | `Confirm overwrite` | `Review in app` | `Open App` |
| Permission | 权限被拒绝或目录不可用 | `Permission needed` | `Open app to authorize` | `Open App` |

### 6.1 状态转换规则

- `Idle -> Eating`：用户拖入或选择的任务中至少有一个 pending job，并且无需先等待覆盖确认。
- `Idle -> Needs Setup`：保存模式为指定目录，且没有可用输出目录。
- `Eating -> Done`：所有任务完成，且没有 failed job。
- `Eating -> Issues`：所有任务完成，但存在 failed job。
- `Eating -> Permission`：权限检查失败或用户取消目录授权。
- `Idle/Eating -> Confirm`：覆盖原图模式下有 pending job，但用户尚未确认覆盖。
- `Done/Issues -> Idle`：用户点击 `Clear List` 或清空任务。

### 6.2 文案原则

- Pet 文案必须短，不超过一行。
- 状态文本优先告诉用户“现在发生了什么”，详情文本说明“结果或下一步”。
- 失败状态不在 Pet 上展开长错误列表；详细错误留在主窗口任务列表。
- 保留当前英文 UI 文案风格，后续如做本地化再统一抽取。

## 7. UI 与交互规格

### 7.1 窗口行为

- 默认尺寸保持小型桌面工具属性，建议范围：`168x156` 到 `192x176`。
- 圆角保持 `8px`，沿用当前 `.regularMaterial` 背景。
- 继续使用 `.floating` 层级和 `.canJoinAllSpaces`，但不得遮挡为全屏级工具窗。
- 用户可拖动窗口背景移动。
- 位置持久化；如果保存位置所在屏幕不存在，启动时自动夹到当前主屏可见区域。
- Pet 只能有一个实例。即使存在多个主窗口，也不得创建多个 Pet 浮窗。

### 7.2 布局结构

```text
+--------------------------+
| [Open App]          [x]   |
|                          |
|            Pet           |
|          Status          |
|          Detail          |
|                          |
| [Add] [Retry/Reveal/More]|
+--------------------------+
```

顶部区：

- 左侧：打开主窗口按钮，使用 `arrow.up.right.square` 或更贴近 macOS 窗口语义的 SF Symbol。
- 右侧：隐藏 Pet 按钮。
- 两个按钮都必须有 tooltip 和 accessibility identifier。

中部区：

- Pet 表情或图形状态保持为视觉焦点。
- `Eating` 状态允许轻量缩放动画，但动画不可改变布局尺寸。
- 状态和详情文本使用稳定高度，长文本用缩放或更短文案处理，不能挤压按钮区。

底部区：

- `Add Images` 始终可见，处理中可禁用或保持可用并追加队列；推荐保持可用以支持连续拖入/追加。
- `Reveal` 仅在有成功输出结果时显示。
- `Retry Failed` 仅在存在失败任务且未处理中时显示。
- `Clear List` 仅在当前批次完成后显示，可与 `Reveal` 二选一或通过更多菜单承载。
- 小窗不承载输出格式、质量预设、保存位置等复杂设置；这些设置留在主窗口。

### 7.3 拖拽反馈

- 拖入支持格式时，高亮边框和背景。
- 拖入不支持格式时，不在 hover 阶段做复杂校验；落下后通过失败状态反馈。
- 拖拽区域为整个 Pet 窗口，按钮仍保留自身点击能力。
- 拖拽过程中不改变窗口尺寸。

### 7.4 主窗口联动

Pet 的 `Open App` 行为必须满足：

1. 调用 `NSApp.activate(ignoringOtherApps: true)`。
2. 如果主窗口存在但最小化，执行 deminiaturize。
3. 如果主窗口已关闭，使用 `openWindow(id: "main")` 重新创建。
4. 新窗口出现后成为 key window。

### 7.5 Finder 联动

- `Reveal` 优先打开最近一次成功批次的输出目录。
- 如果保存模式为覆盖原图或原目录保存，且批次分布在多个目录，推荐打开第一个成功输出文件所在目录。
- 如果没有成功输出，`Reveal` 不显示。
- 如果目录不可访问，显示 `Permission needed` 并引导打开主窗口。

## 8. 功能需求

| 编号 | 需求 | 优先级 | 验收要点 |
| --- | --- | --- | --- |
| PET-01 | Pet 作为全局浮动桌面入口 | P0 | 可显示、隐藏、拖动、跨 Space，位置可恢复 |
| PET-02 | Pet 支持拖拽图片并追加队列 | P0 | 拖入 JPG/PNG/HEIC 后进入队列，仍遵守 2 并发 |
| PET-03 | Pet 支持从系统面板添加图片 | P0 | 点击 Add Images 与主窗口行为一致 |
| PET-04 | Pet 状态覆盖 Idle/Eating/Done/Issues/Permission/Confirm | P0 | 每种状态有短文案和明确下一步 |
| PET-05 | Pet 可重新打开主窗口 | P0 | 主窗口关闭、后台、最小化时均可恢复 |
| PET-06 | Pet 可在完成后打开结果位置 | P0 | 有成功输出时出现 Reveal，能打开对应目录 |
| PET-07 | Pet 可重试失败任务 | P1 | 批次完成且存在失败任务时出现 Retry Failed |
| PET-08 | Pet 可开始下一批 | P1 | 完成后支持 Clear List，并保留用户设置 |
| PET-09 | Pet 不绕过覆盖确认 | P0 | 覆盖模式从 Pet 拖入也必须二次确认 |
| PET-10 | Pet 不绕过 sandbox 授权 | P0 | 输出目录或原目录权限不足时必须请求授权或打开主窗口 |
| PET-11 | Pet 可访问性完整 | P1 | 关键按钮和状态可由 VoiceOver 识别 |
| PET-12 | Pet 在多窗口场景保持单例 | P1 | 多个 `ContentView` 不会创建多个浮窗 |

## 9. 技术设计

### 9.1 模块边界

保持架构边界：

- `ImagePetCore`：只负责压缩行为，不新增 Pet 类型。
- `ImagePetStore`：继续作为 GUI 状态、队列、任务操作和 Pet 状态来源。
- `DesktopPetWindowController`：只负责 macOS 窗口生命周期、位置、层级和显示隐藏。
- `DesktopPetView`：只负责小窗 UI 和动作触发。

不得让 `ImagePetCore` import SwiftUI 或 AppKit。

### 9.2 推荐新增 GUI 层类型

为了避免 `DesktopPetView` 直接散落复杂条件判断，建议新增一个轻量快照类型：

```swift
struct DesktopPetSnapshot: Equatable {
    let state: DesktopPetDisplayState
    let title: String
    let detail: String
    let primaryAction: DesktopPetAction?
    let secondaryActions: [DesktopPetAction]
    let canAcceptDrop: Bool
}
```

该类型可以放在 `Sources/ImagePet/Views` 或 `Sources/ImagePet/Stores`，但仍属于 GUI 层。它只从 `ImagePetStore` 当前状态派生，不持久化，不进入 Core。

### 9.3 动作模型

推荐把 Pet 动作收敛成明确枚举，便于 UI 测试和后续菜单化：

```swift
enum DesktopPetAction {
    case openMainApp
    case hidePet
    case addImages
    case revealOutput
    case retryFailed
    case clearList
}
```

动作最终仍调用 `ImagePetStore` 现有方法或新增窄方法。

### 9.4 权限与安全

- Pet 拖入文件后仍走 `ImagePetStore.addDroppedURLs(_:)`。
- 指定输出目录为空时，不应从 Pet 内静默选择默认目录；应打开主窗口或触发同一套 `NSOpenPanel`。
- 原目录保存需要父目录授权时，继续使用 `NSOpenPanel` 和 security-scoped bookmark。
- 覆盖原图模式必须保持二次确认，且确认文案明确不可撤销。
- Pet 不保存额外文件权限，不持有新的 bookmark store。

### 9.5 性能约束

- Pet 自身更新不得影响压缩并发。
- Pet 动画仅绑定轻量状态，不绑定每个 job 的频繁详细进度。
- 大批次处理时，Pet 只显示总进度和汇总，不渲染完整 job 列表。
- 压缩仍由 `ImagePetCore` 和现有队列执行，保持 `maxConcurrentJobs = 2`。

## 10. 边界条件

必须明确处理：

- 主窗口关闭后点击 `Open App`。
- 主窗口最小化后点击 `Open App`。
- 用户关闭 Pet 后重新从主窗口打开。
- 用户移动到另一块显示器后重启 App。
- 保存过的 Pet 位置超出当前屏幕可见区域。
- 输出目录 bookmark 失效。
- 原目录保存时多个输入文件来自多个父目录。
- 覆盖模式从 Pet 拖入文件。
- 拖入全部是不支持格式。
- 拖入正常图片、坏图和不支持格式混合批次。
- 处理中继续拖入更多图片。
- 处理完成后点击 `Clear List`。
- 处理完成后只有 skipped，没有成功输出。
- 多个主窗口同时存在时只显示一个 Pet。

## 11. 验收标准

### 11.1 自动化测试

建议新增或扩展 XCUITest：

1. `testDesktopPetAcceptsDroppedOrSelectedImages`
   - 打开 Pet。
   - 通过 Pet 的 `Add Images` 添加测试图片。
   - 验证主窗口任务列表更新，Pet 进入 `Eating`，完成后进入 `Done`。

2. `testDesktopPetShowsIssuesAndRetriesFailedJobs`
   - 添加包含坏图或不支持格式的批次。
   - 验证 Pet 显示 `Issues`。
   - 点击 `Retry Failed` 后只重置失败任务。

3. `testDesktopPetRequiresOverwriteConfirmation`
   - 切换到覆盖模式。
   - 从 Pet 添加图片。
   - 验证出现覆盖确认，取消后 pending job 变为失败或停止。

4. `testDesktopPetRevealsOutputAfterSuccess`
   - 完成压缩后点击 Pet 的 `Reveal`。
   - 在测试环境中可用 mock 或可观测状态确认调用路径。

5. `testDesktopPetSingleInstanceAcrossMainWindows`
   - 打开主窗口和 `Window("ImagePet", id: "main")`。
   - 多次触发 `Show Pet`。
   - 验证只存在一个 `DesktopPetWindow`。

仍需保留现有测试：

```bash
xcodebuild -project ImagePet.xcodeproj \
  -scheme ImagePet \
  -configuration Debug \
  -derivedDataPath DerivedData \
  -destination 'platform=macOS' \
  test
```

### 11.2 手工验收

手工验收必须覆盖：

- Pet 可显示、隐藏、拖动，重启后位置恢复。
- 跨 Space 显示符合预期。
- 主窗口关闭后，Pet 能重新打开主窗口。
- 从 Pet 拖入 20 张图片，进度、完成和节省体积正确。
- 完成后点击 `Reveal` 能打开结果目录。
- 混入坏图后，Pet 显示失败汇总，主窗口显示具体错误。
- 覆盖模式从 Pet 发起时必须弹出二次确认。
- 输出目录失效时，Pet 不继续处理并引导用户授权。
- VoiceOver 能读出 Pet 的主要状态和按钮。

### 11.3 回归测试

v0.4 不得破坏：

- 主窗口拖拽压缩。
- `Add Images` 主窗口入口。
- 输出格式、保存位置、后缀、尺寸限制、元数据剥离设置。
- 覆盖原图二次确认。
- `Reveal in Finder`、`Retry Failed`、`Clear List`。
- App Sandbox entitlements。
- `swift test` 和 Xcode project 测试路径。

## 12. 发布范围

### P0: v0.4 必须交付

- Pet 状态模型补齐。
- Pet 操作闭环：Open App、Add Images、Reveal、Retry Failed、Clear List、Hide。
- 主窗口关闭/最小化恢复稳定。
- 输出目录缺失、权限失败、覆盖确认的 Pet 状态处理。
- 多窗口单例保护。
- 自动化和手工验收更新。

### P1: v0.4 可选交付

- Pet 显示简短最近文件名，例如 `photo.heic done`。
- 完成后提供 `Copy Saved Summary`，复制 `Saved 2.1 MB from 4.8 MB`。
- Pet 动画节奏微调。
- 多显示器位置恢复更精细的屏幕选择。

### P2: v0.4 之后再评估

- 自定义 Pet 外观。
- 更丰富动画资源。
- 菜单栏模式。
- 历史批次面板。
- Finder Extension 或 Shortcuts。

## 13. 风险与取舍

### 风险一：Pet 变得过重

如果把主窗口设置全部搬进 Pet，小窗会失去“低打扰入口”的意义。v0.4 只允许轻量动作，复杂配置继续留在主窗口。

### 风险二：权限路径绕过主窗口

桌面 Pet 越独立，越容易诱导实现绕过现有授权流程。v0.4 要求 Pet 复用同一套 store、panel 和 bookmark 流程，不新增隐式写入路径。

### 风险三：多窗口导致多个 Pet

当前 `ContentView` 可被多个 window scene 承载。v0.4 必须保证浮窗 controller 是单例效果，避免每个主窗口都生成一个 Pet。

### 风险四：状态文案过短导致不可信

Pet 文案需要短，但不能只显示表情。失败、权限、确认这三类状态必须给出明确下一步。

## 14. 成功指标

定性指标：

- 用户可以把主窗口关闭，只保留 Pet 完成日常压缩。
- 失败和权限状态不会让用户困惑。
- Pet 看起来像 macOS 桌面工具，而不是主窗口缩小版。

定量指标：

- 从桌面拖入图片到 Pet 状态进入 `Eating` 的可感知延迟低于 300ms。
- 20 张图片批处理期间 Pet 动画和状态更新不卡顿。
- Pet 相关 UI 测试覆盖不少于 5 个核心场景。
- 不新增 `ImagePetCore` 对 SwiftUI/AppKit 的依赖。

## 15. 开放问题

1. Pet 完成后底部是否同时显示 `Reveal` 和 `Clear List`，还是优先 `Reveal` 并把 `Clear List` 放到主窗口？
2. `Retry Failed` 是直接在 Pet 上显示，还是失败时只引导打开主窗口？
3. 覆盖确认是否允许由 Pet 触发的系统 dialog 直接确认，还是必须打开主窗口上下文？
4. Pet 是否需要显示当前输出格式和保存位置的极短摘要，例如 `JPEG -> Output Folder`？
5. v0.4 是否同步更新 app icon 或 Pet 专用图形资产，还是继续使用当前表情占位？

