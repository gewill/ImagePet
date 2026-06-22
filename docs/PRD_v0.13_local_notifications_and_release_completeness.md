# ImagePet PRD v0.13: 本地通知与发布完整性闭环

## 1. 版本定位

v0.11 已补齐离线 Help Center、设置分区、菜单整理与可自定义全局快捷键。v0.12 已把 ImagePet 推进到系统级工作流：CLI、文件夹监听、Finder Quick Action 与 Shortcuts。

v0.13 不继续扩大图片格式、压缩算法或系统入口范围。它的目标是把已有入口变成一个可长期使用、可理解、可恢复、可发布的 macOS app：

```text
当 ImagePet 在后台、Finder、Shortcuts 或监听文件夹中工作时，用户能明确知道发生了什么、结果在哪里、需要处理什么，并且所有提示都尊重 macOS 通知权限、沙盒权限和用户的打扰边界。
```

v0.13 的产品承诺是：

```text
ImagePet becomes trustworthy as a background utility: quiet by default, explicit when needed, and complete enough for release-candidate validation.
```

## 2. 当前基线

截至 2026-06-15，仓库当前状态：

- `ImagePetCore`、GUI、CLI、Help Center、KeyboardShortcuts、Folder Watching、Finder Quick Action、Shortcuts 集成均已有实现或规划记录。
- `ImagePetApp.swift` 已注册 `NSApp.servicesProvider`，Finder Quick Action 可把文件加入队列。
- `FolderWatchManager` 与 `FolderMonitor` 已存在，设置页已有文件夹监听管理入口。
- 当前 PRD 与进度文档尚未定义完整的本地通知策略。
- 当前没有专门的 `LocalNotificationManager`、通知权限设置区、通知动作、通知节流、通知验收清单或通知 UI 测试策略。
- 发布前残余事项仍包括 Developer ID notarization workflow、真实全局快捷键 smoke、长期文件夹监听资源验证、系统入口手工验收。

因此 v0.13 应把“后台发生了什么”讲清楚，并把发布前完整性问题收束到可验收清单，而不是继续新增大功能。

## 3. 最终范围

### P0

- 新增完整本地通知能力，覆盖后台压缩完成、部分失败、需要授权、监听暂停、Finder/Shortcuts 入口结果。
- 新增通知权限申请与设置页说明，默认不在首次启动时强行弹权限框。
- 新增通知点击与动作处理：Reveal in Finder、Open ImagePet、Review Failed。
- 新增通知节流和批量摘要，避免文件夹监听或批量压缩产生通知风暴。
- 新增通知文案规范，保持短、明确、非营销。
- 新增后台任务状态补偿：当通知不可用时，App 内仍能在设置页或主界面看到最近一次后台结果。
- 新增发布前完整性验收清单：notarization、sandbox、login item、global shortcut、Finder Quick Action、Shortcuts、folder watching、local notifications。
- 补充自动化测试和手工验收清单。

### P1 / v0.13.x

- Notification Center actions 的更细粒度入口，例如直接打开输出文件夹或重新压缩失败项。
- 最近后台任务历史列表。
- Copy Diagnostics / Support Summary。
- 设置页中的通知预览。
- 对长时间运行任务显示阶段性通知，例如 100+ 文件批量任务的中途摘要。

### v1.0+

- Sparkle 或其他自动更新方案。
- 崩溃报告、反馈上传或遥测。
- App Store / Developer ID 双分发策略。
- 菜单栏常驻模式。
- 多语言帮助与通知文案。

## 4. 非目标

v0.13 明确不做：

- 不新增 AVIF、JPEG XL、GIF、PDF、TIFF 或新的输出格式。
- 不新增压缩参数、codec 调优、AI 决策或云处理。
- 不改动 `ImagePetCore` 的压缩职责边界。
- 不让通知绕过沙盒授权、输出目录授权或覆盖原图二次确认。
- 不在首次启动立即请求通知权限。
- 不用通知替代主界面错误展示。
- 不发送网络通知、push notification、远程分析事件或遥测。
- 不为了通知引入菜单栏常驻 app 范式。

## 5. 本地通知产品要求

### 5.1 通知触发场景

P0 通知覆盖以下场景：

| 场景 | 触发条件 | 通知级别 | 默认行为 |
| --- | --- | --- | --- |
| 后台批量压缩完成 | App 不在前台，且至少 1 个文件成功 | 成功摘要 | 显示成功数、节省体积、输出位置 |
| 后台批量部分失败 | 至少 1 个成功且至少 1 个失败 | 警告摘要 | 显示成功/失败数，提供 Review Failed |
| 后台批量全部失败 | 没有成功项 | 错误摘要 | 显示短错误与 Open ImagePet |
| Finder Quick Action 完成 | 从 Finder 服务入口触发 | 成功/警告/错误 | 显示结果并提供 Reveal in Finder |
| Shortcuts 动作完成 | Shortcuts 在后台调用 ImagePet | 成功/警告/错误 | 通知应尊重 Shortcuts 运行上下文，避免重复提示 |
| 文件夹监听完成 | 监听文件夹自动压缩新文件 | 摘要 | 以防抖窗口聚合成一条通知 |
| 需要输出目录授权 | designated output folder 缺失或 bookmark 失效 | 需要操作 | 提供 Open ImagePet |
| 监听暂停 | 监听目录权限丢失或配置无效 | 需要操作 | 提供 Open Settings |

### 5.2 不应触发通知的场景

- App 主窗口处于前台且用户正在看压缩结果。
- 用户刚通过普通拖拽或 Add Images 在主界面主动操作，且结果已经在 UI 上可见。
- 单个文件失败已经在前台 UI 中明确展示。
- 重复失败在短时间内连续出现，且原因、入口和文件夹相同。
- 用户在设置中关闭对应通知类别。

### 5.3 权限策略

通知权限必须由用户主动触发：

- 设置页显示 `Notifications` 分区。
- 当系统权限尚未确定时，提供 `Enable Notifications` 按钮。
- 用户点击后才调用 `UNUserNotificationCenter.current().requestAuthorization(...)`。
- 如果权限被拒绝，显示系统设置引导，但不反复弹窗。
- 通知权限状态应在 app 激活或设置页显示时刷新。

默认通知设置：

```text
Notify when background compression finishes: on
Notify when attention is needed: on
Notify for foreground compression: off
Play completion sound: follow existing sound setting
```

如果系统权限尚未授权，这些开关只代表 ImagePet 内部偏好，不代表系统可实际投递通知。

### 5.4 通知文案

文案必须短、明确、可行动：

成功：

```text
Title: ImagePet finished compressing 8 images
Body: Saved 14.2 MB. Output: Designated folder.
```

部分失败：

```text
Title: ImagePet compressed 6 of 8 images
Body: 2 need attention. Open ImagePet to review.
```

需要授权：

```text
Title: ImagePet needs an output folder
Body: Choose a folder before background compression can continue.
```

监听暂停：

```text
Title: Folder watching paused
Body: ImagePet lost access to a watched folder.
```

文案规则：

- 不使用可爱化或营销式语气。
- 不显示完整绝对路径，除非用户点击进入 App。
- 不把隐私敏感文件名批量列入通知正文。
- 文件名最多显示 1 个，并优先在 App 内展示完整细节。
- 数量、节省体积、失败数优先于技术原因。

### 5.5 通知动作

P0 actions：

```text
Reveal in Finder
Open ImagePet
Review Failed
Open Settings
```

动作规则：

- `Reveal in Finder` 只在有单一明确输出目录或输出文件时显示。
- `Review Failed` 打开主窗口并保留失败任务列表。
- `Open Settings` 打开设置页对应分区，例如 Folder Watching 或 Notifications。
- 所有动作必须在主线程恢复 UI 状态。
- 动作不得直接重新执行压缩或覆盖原图。

### 5.6 节流与聚合

为避免通知风暴：

- 同一个后台批次最多投递 1 条完成通知。
- 文件夹监听在 2 秒聚合窗口内的新文件结果合并为 1 条摘要。
- 同一个监听目录的同类权限失败在 10 分钟内最多通知 1 次。
- Finder Quick Action 的同一次服务调用最多投递 1 条摘要。
- Shortcuts 如果已经把结果返回给系统动作链，ImagePet 通知可默认降级或不投递，具体实现阶段通过 spike 确认。

## 6. 技术形状

### 6.1 新增服务边界

建议新增 GUI-only 服务：

```text
Sources/ImagePet/Services/LocalNotificationManager.swift
```

职责：

- 管理 `UNUserNotificationCenter` 权限状态。
- 注册 notification categories 和 actions。
- 将 app 内部 task summary 映射为通知内容。
- 执行节流和聚合。
- 处理通知点击后的 UI routing。

禁止：

- `ImagePetCore` 依赖 `UserNotifications`。
- 在压缩核心内直接投递通知。
- 通知服务直接读取或写入图片。

### 6.2 任务摘要模型

建议新增轻量模型，放在 GUI 层：

```text
BackgroundCompressionSummary
```

字段建议：

```text
source: manual | folderWatching | finderService | shortcuts
successfulCount
failedCount
totalInputBytes
totalOutputBytes
outputDirectory
representativeOutputURL
requiresUserAction
primaryErrorMessage
completedAt
```

该模型用于：

- 通知文案。
- 最近后台结果展示。
- 手工验收日志。
- 将 Finder / Shortcuts / folder watching 入口的结果归一。

### 6.3 设置页调整

在 `AppSettingsView` 中新增 `Notifications` 分区：

- 系统权限状态。
- Enable Notifications / Open System Settings。
- 后台完成通知开关。
- 需要操作通知开关。
- 前台通知开关，默认 off。
- 最近一次通知投递状态，便于手工验收。

设置页不应显得像系统说明书；说明文案保持一两句，避免占据主要界面。

### 6.4 AppDelegate / routing

`AppDelegate` 或独立 coordinator 需要处理：

- `UNUserNotificationCenterDelegate`。
- 用户点击通知时打开主窗口。
- 根据 action identifier 打开 Finder、失败列表或设置页。
- App 启动早期注册 categories，但不请求权限。

实现阶段应避免把 `AppDelegate` 变成大杂烩；如果逻辑超过简单转发，应把行为放到 `LocalNotificationManager` 或 routing coordinator。

## 7. App 完整性补齐

v0.13 同时收束以下发布前完整性事项：

### 7.1 系统入口一致性

- 普通拖拽、Add Images、Finder Quick Action、Shortcuts、Folder Watching 的完成结果应使用一致摘要模型。
- 失败文案应继续使用既有短错误消息：
  - `Unsupported image format`
  - `Permission denied`
  - `Output folder unavailable`
  - `Failed to decode image`
  - `Failed to write output file`
  - `Not enough disk space`
  - `Unknown error`
- 所有后台入口在需要用户授权时打开主窗口，而不是静默失败。

### 7.2 Release Candidate 验收清单

v0.13 完成后，必须具备一份可重复执行的 RC 手工验收清单，覆盖：

- 首次启动。
- 拖拽压缩。
- Add Images。
- 指定输出目录、原目录保存、覆盖原图。
- Help Center。
- Desktop Pet 显示、隐藏、Mini / Full、Launch at Login。
- Global shortcuts 录制与触发。
- CLI。
- Folder Watching 长时间运行。
- Finder Quick Action。
- Shortcuts。
- Local Notifications 权限、成功、失败、动作、拒绝权限状态。
- Sandbox 文件权限恢复。
- Developer ID codesign / notarization / Gatekeeper 打开 smoke。

### 7.3 隐私与信任

- Help Center 的 Privacy 内容需要补充后台入口与通知说明。
- 通知不应泄露完整路径或过多文件名。
- App 不上传图片、不发送远程通知、不引入遥测。

## 8. 非功能要求

- 通知投递不得阻塞压缩流程。
- 通知权限检查不得造成主线程卡顿。
- 后台监听空闲状态仍应保持 `0.0%` CPU 目标。
- 通知聚合状态不得无限增长，App 退出或任务完成后应释放。
- 沙盒和 user-selected read-write entitlement 必须保持启用。
- 通知功能必须在系统权限拒绝时优雅降级。

## 9. 测试与验证计划

### 9.1 自动化测试

- `LocalNotificationManagerTests`
  - 权限未授权时不投递通知。
  - 关闭对应类别时不投递通知。
  - 成功、部分失败、全部失败文案生成正确。
  - 同一批次只生成一条摘要。
  - 同一监听目录权限失败在节流窗口内只生成一条通知请求。
- Store / routing tests
  - 后台完成摘要可由 folder watching / Finder service 入口创建。
  - Review Failed action 保留失败任务。
  - Open Settings action 跳转到正确设置分区。
- UI tests
  - Settings 中 Notifications 分区可见。
  - 权限拒绝状态有清晰恢复入口。
  - 最近后台结果摘要可见。

### 9.2 手工验收

- 在设置页点击 Enable Notifications，系统权限弹窗只出现一次。
- 允许权限后，用 Finder Quick Action 压缩 3 张图片，确认只出现 1 条摘要通知。
- 点击 `Reveal in Finder`，Finder 打开正确输出位置。
- 混入 1 张坏文件，确认通知显示成功/失败数量，点击 `Review Failed` 后主窗口显示失败项。
- 拒绝系统通知权限后，后台压缩仍完成，App 内最近结果可见。
- 文件夹监听连续拖入 10 张图片，确认通知按聚合窗口摘要，不逐张刷屏。
- 删除或移动授权输出目录后触发后台压缩，确认通知要求用户打开 App 授权。
- 在 App 前台执行普通拖拽压缩，默认不投递完成通知。

## 10. 实施顺序建议

1. 先做通知技术 spike：确认 macOS sandbox + `UNUserNotificationCenter` + notification actions 在 Debug/App bundle 中的行为。
2. 建立 `BackgroundCompressionSummary`，把现有后台入口结果汇总到同一模型。
3. 新增 `LocalNotificationManager`，先实现文案生成与权限状态，不接真实投递。
4. 接入真实通知投递、actions 和设置页。
5. 接入 Folder Watching / Finder / Shortcuts 完成路径。
6. 补自动化测试。
7. 执行 RC 手工验收清单并回写 `docs/PROGRESS.md`。

## 11. Open Questions

- Shortcuts 场景是否默认投递通知，还是只在失败或需要授权时投递？
- `Reveal in Finder` 在多输出目录情况下是否隐藏，还是打开最近输出目录？
- Notification action routing 是否应复用现有 `AppNavigation`，还是引入独立 routing coordinator？
- 最近后台结果是否只保留 1 条，还是保留一个短历史列表？
- 发布前是否需要把 RC 手工验收清单拆成单独 `docs/RELEASE_CHECKLIST.md`？
