# ImagePet PRD v0.5: Desktop Pet Mini / Full Dual State

## 1. 版本定位

ImagePet v0.4 已经把桌面 Pet 从简单状态镜像推进为可操作的桌面入口：

- Pet 面板支持状态色、状态徽章、主动作按钮和处理中进度条。
- 拖拽 hover 有明确视觉反馈。
- 处理中允许继续 `Add Images` 追加队列。
- `Permission`、`Confirm`、`Issues`、`Done` 等状态仍复用 `ImagePetStore` 的统一状态和动作路径。
- 覆盖确认、权限授权、失败重试仍不绕过主窗口和 sandbox 约束。

v0.5 的目标不是继续加功能按钮，而是把桌面 Pet 的长期驻留体验拆成双态：

```text
Mini = 桌面陪伴与拖拽入口
Full = 状态解释与轻量操作面板
```

一句话目标：

```text
让用户可以长期只保留一个低打扰的 Pet，同时在需要理解、确认或操作时快速展开完整面板。
```

## 2. 设计简报

- 产品对象：ImagePet macOS 桌面 Pet。
- 设计对象：桌面 Pet 的 Mini / Full 双态、状态切换、拖拽反馈和阻塞状态处理。
- 视觉来源：沿用当前 `DesktopPetView`、macOS 系统材质、语义色和现有 Pet 表情，不引入全新视觉系统。
- 交互级别：可落地的产品需求，不是静态概念稿。
- 技术范围：只增强 `Sources/ImagePet` GUI 层，不改变 `ImagePetCore` 压缩算法、格式范围或并发约束。

## 3. 当前实现基线

v0.5 基于当前仓库状态和今天已完成的桌面 Pet polish。

已存在能力：

- `DesktopPetWindowController` 创建单例浮窗，支持 `.floating`、跨 Space、透明背景、位置 autosave 和 off-screen 恢复。
- Full 面板尺寸已扩展到 `192x176`，保持 8px 圆角和 `.regularMaterial`。
- `DesktopPetView` 已显示：
  - Pet 表情
  - 状态色
  - 状态徽章
  - 标题和详情
  - 主动作按钮
  - `Eating` 进度条
  - 拖拽 hover 高亮
  - hover 反馈
  - Reduce Motion 降级
- `ImagePetStore.petSnapshot` 已覆盖 `idle`、`needsSetup`、`eating`、`done`、`issues`、`confirm`、`permission`。
- `Eating` 状态已保留 `Add Images` 入口，支持处理中追加任务。
- XCUITest 已覆盖 Pet 开关、返回主窗口、完成态动作、失败重试、覆盖确认和批量压缩流程。

当前缺口：

- Pet 仍然只有 Full 面板形态，长期放在桌面上存在感偏重。
- Mini “只有 Pet”的低打扰入口尚未实现。
- Mini 和 Full 的切换规则、自动展开规则、自动收回规则没有产品合同。
- `Done`、`Issues` 是否自动展开/收回还需要明确。
- 拖拽到 Mini 后的处理状态展示策略尚未定义。
- 右键菜单、VoiceOver 双态描述、Reduce Motion 双态动画边界尚未成体系。

## 4. 产品目标

### 4.1 核心目标

1. **低打扰驻留**：用户可以长期只保留 Mini Pet，不被按钮、文字和面板干扰。
2. **快速可达**：Mini 仍然是有效拖拽入口，用户可以直接把图片拖给 Pet。
3. **按需解释**：用户点击 Mini 或遇到阻塞状态时，Pet 展开 Full 解释当前状态和下一步。
4. **操作闭环**：Full 保留 v0.4 已有轻量动作：Add、Reveal、Retry、More、Open App、Hide。
5. **安全一致**：双态只改变展示层，不改变权限、覆盖确认、队列、并发和 sandbox 路径。
6. **辅助功能完整**：Mini / Full 都必须有 VoiceOver 描述，所有动画遵守 Reduce Motion。

### 4.2 非目标

v0.5 不做：

- 不新增 WebP、AVIF、PDF、文件夹监听、Shortcuts、Finder Extension、Raycast Extension。
- 不新增云上传、账号、同步、历史库。
- 不做 AI 自动格式判断。
- 不做复杂养成系统、积分、皮肤商店、成就。
- 不把 Mini 做成菜单栏替代品。
- 不把 Full 做成主窗口替代品。
- 不在 Mini 显示文字、按钮、角标、进度环或结果卡片。
- 不允许 Pet 静默写入未经授权的目录。
- 不改变 `maxConcurrentJobs = 2`。

## 5. 用户场景

### 场景 A：长期桌面驻留

用户不希望桌面上一直有一个控制面板，但愿意保留一个小 Pet。Pet 默认以 Mini 形态存在，仅显示 Pet 本体。用户需要操作时点击展开。

### 场景 B：从 Finder 快速投喂

用户从 Finder 拖入 JPG、PNG 或 HEIC 到 Mini。Mini 进入 drag-hover 姿态，松手后直接添加任务并进入 `Eating`。

### 场景 C：处理中查看进度

用户拖入后 Pet 可保持 Mini 进行轻量处理动画。用户点击 Mini 后展开 Full，看到 `Eating`、`3 / 12` 和进度条。

### 场景 D：批量完成

如果任务由 Mini 发起且用户没有主动展开，完成后 Mini 播放短完成动画，然后回到 Ready 姿态。如果用户已经在 Full 中查看进度，完成后 Full 保持展开，显示 `Saved 2.1 MB` 和 `Reveal`。

### 场景 E：部分失败

混入坏图或不支持格式时，Mini 进入异常表情但不默认打断用户。用户点击 Mini 展开 Full 后看到 `Issues`、失败汇总和 `Retry`。

### 场景 F：阻塞状态

需要覆盖确认或权限授权时，Mini 不让用户猜。Pet 自动展开 Full，并按现有流程激活主窗口或引导 `Open App`。

## 6. 核心概念

### 6.1 Display State

Display State 是业务状态，继续由 `ImagePetStore.petSnapshot` 派生。

| 状态 | 含义 |
| --- | --- |
| `idle` | 可接收图片 |
| `needsSetup` | 指定输出目录缺失或不可用 |
| `eating` | 有任务处理中 |
| `done` | 批次完成且没有 failed job |
| `issues` | 批次完成但存在 failed job |
| `confirm` | 覆盖模式等待确认 |
| `permission` | 权限不足或授权被拒绝 |

### 6.2 View Mode

View Mode 是展示形态，是 v0.5 新增的产品概念。

| 模式 | 定义 |
| --- | --- |
| `mini` | 只显示 Pet 本体，用于长期驻留、拖拽入口和状态暗示 |
| `full` | 显示状态、详情、进度和轻量动作，用于解释和操作 |

Display State 和 View Mode 应保持解耦：

```text
业务状态决定 Pet 表情、标题、详情和可用动作
展示模式决定这些信息是否显示，以及显示多少
```

## 7. Mini 规格

Mini 必须满足“只有 Pet”的约束。

### 7.1 视觉结构

Mini 显示：

- Pet 表情或 Pet 图形。
- 透明或极弱背景热区。
- 可选轻微 shadow。

Mini 不显示：

- 标题文字。
- 详情文字。
- 状态 badge。
- 进度条。
- 动作按钮。
- 结果摘要。
- 错误数量。
- 输出目录或格式信息。

建议尺寸：

```text
64x64 到 88x88
```

Mini 的热区可以略大于视觉 Pet，以保证拖拽和点击容易命中，但视觉上不应像一个面板。

### 7.2 Mini 状态表现

| Display State | Mini 表现 | 是否自动展开 |
| --- | --- | --- |
| `idle` | 默认 Pet，轻微呼吸 | 否 |
| `eating` | 咀嚼或轻弹动 | 否 |
| `done` | 短暂开心动画，然后回 Ready 姿态 | 否 |
| `issues` | 困惑或晕表情，轻微摇头可选 | 默认否 |
| `needsSetup` | 警觉或疑问表情 | 是 |
| `confirm` | 严肃或警告表情 | 是 |
| `permission` | 锁定或警觉表情 | 是 |

### 7.3 Mini 交互

| 操作 | 行为 |
| --- | --- |
| 单击 Mini | 展开 Full |
| 拖入图片 | 接收 URL，走 `ImagePetStore.addDroppedURLs(_:)` |
| 拖拽 hover | Pet 进入可接收姿态，不做复杂格式预校验 |
| 右键 Mini | 显示 `Show Panel`、`Open App`、`Hide Pet` |
| 拖动 Mini | 移动 Pet 窗口位置并保持 autosave |

不建议使用双击作为核心操作，避免和单击展开冲突。

## 8. Full 规格

Full 是当前 v0.4 Pet 面板的延续和收纳态，不是主窗口替代品。

### 8.1 Full 显示内容

Full 显示：

- Pet 表情或图形。
- 状态标题。
- 一行详情。
- `Eating` 进度条。
- 主动作按钮。
- 次要动作按钮。
- Open App。
- Hide 或 Collapse。

Full 不显示：

- 质量预设。
- 输出格式选择。
- 保存位置选择。
- 覆盖模式设置。
- 元数据剥离设置。
- 完整错误列表。
- 历史批次。

复杂配置继续留在主窗口。

### 8.2 Full 操作区

| 动作 | 显示条件 | 行为 |
| --- | --- | --- |
| `Add` | `idle`、`eating`、`done`、`issues` | 与主窗口 Add Images 一致 |
| `Reveal` | 有成功输出 | 打开输出位置 |
| `Retry` | 有 failed job 且未处理中 | 只重试 failed job |
| `More` | 当前批次完成 | 清空队列，保留设置 |
| `Open App` | 始终可达 | 激活或重开主窗口 |
| `Collapse` | Full 模式 | 收回 Mini |
| `Hide` | Mini 或 Full | 隐藏整个 Pet |

### 8.3 Collapse 与 Hide 的区别

`Collapse`：

- 只从 Full 收回 Mini。
- Pet 仍然存在。
- 用户仍可拖拽到 Mini。

`Hide`：

- 关闭或隐藏整个 Pet 窗口。
- 需要从主窗口或菜单重新显示。

Full 右上角建议使用 Collapse，而不是只提供 Hide。Hide 可以放在右键菜单或次级入口。

## 9. 切换规则

### 9.1 用户主动切换

| 触发 | 结果 |
| --- | --- |
| 点击 Mini | `mini -> full` |
| 点击 Full 的 Collapse | `full -> mini` |
| 右键 Mini 选择 Show Panel | `mini -> full` |
| 右键选择 Hide | 隐藏 Pet |

### 9.2 系统自动切换

| 触发 | 结果 |
| --- | --- |
| App 启动且 Pet 已开启 | 默认进入 Mini |
| `needsSetup` | 自动展开 Full |
| `confirm` | 自动展开 Full，并按现有逻辑激活主窗口确认 |
| `permission` | 自动展开 Full，并引导 Open App 或授权 |
| Mini 发起任务完成且全成功 | 保持 Mini，播放短完成动画 |
| Full 中任务完成且全成功 | 保持 Full，显示 Saved 和 Reveal |
| 普通 `issues` | 默认保持当前模式 |
| 全部失败或覆盖取消 | 建议展开 Full |
| Full 非阻塞状态长时间无交互 | 可自动收回 Mini，默认 30 秒，P1 可调 |

### 9.3 Done 决策

`Done` 不应无条件自动收回。

推荐规则：

- 如果用户一直在 Mini：完成后保持 Mini，只播放短完成动效。
- 如果用户已经展开 Full：完成后保持 Full，方便点击 `Reveal`。
- 如果 Full 无交互 30 秒：可自动收回 Mini。

原因：无条件收回会打断用户点击 `Reveal` 或阅读节省结果。

### 9.4 Issues 决策

普通 `Issues` 不应无条件自动展开。

推荐规则：

- 部分失败：保持当前模式，Mini 用异常表情提示。
- 全部失败：展开 Full。
- 权限类失败：进入 `permission`，展开 Full。
- 覆盖取消：展开 Full，显示 `Issues` 和 `Compress More`。

原因：部分失败不一定需要立即打断用户，但阻塞或完全失败必须解释。

## 10. 拖拽规则

### 10.1 拖拽 hover

Mini 和 Full 都应支持拖拽 hover。

hover 反馈：

- Mini：Pet 轻微放大或张嘴。
- Full：边框、背景或 Pet 区域高亮。

不做：

- hover 阶段不做复杂格式预校验。
- hover 阶段不显示长错误。
- hover 阶段不改变窗口尺寸。

### 10.2 Drop 后流程

```text
drop URLs
-> ImagePetStore.addDroppedURLs(_:)
-> pending job 入队
-> 如需 Confirm/Permission，进入阻塞状态
-> 否则进入 Eating
-> Done 或 Issues
```

### 10.3 Mini drop 后是否展开

默认不展开。

例外：

- 进入 `confirm`：展开 Full / 激活主窗口。
- 进入 `permission` 或 `needsSetup`：展开 Full。
- 全部输入失败：展开 Full。

## 11. 动效规格

### 11.1 P0 动效

| 状态 | 动效 |
| --- | --- |
| Mini idle | 极轻呼吸 |
| Mini drag hover | 放大或张嘴 |
| Eating | 咀嚼或轻弹 |
| Done | 短庆祝，约 1 秒内结束 |
| Issues | 静态异常表情，轻微摇头可作为 P1 |
| Full 展开/收回 | 小幅 scale + opacity |

### 11.2 P1 动效

- `Done` 可针对批量任务增加稍长庆祝窗口。
- `Issues` 可增加低频轻摇，但不能循环打扰。
- Pet 自定义图形资产可替代表情。

### 11.3 Reduce Motion

当 Reduce Motion 开启：

- 取消循环呼吸。
- 取消 hover 缩放。
- 取消咀嚼循环。
- 展开/收回使用简单 opacity 或直接切换。
- 状态仍必须可通过表情、文字和 VoiceOver 理解。

## 12. 可访问性

Mini：

- VoiceOver label 应包含产品和状态，例如 `ImagePet desktop pet, ready, drop images or click to show controls`。
- Mini 必须暴露为可点击控件。
- Mini 必须支持拖拽以外的替代路径：右键菜单或主窗口菜单。

Full：

- 每个动作按钮必须有 accessibility label。
- 状态标题和详情必须可读。
- 进度条必须表达 `completed / total`。
- `Confirm`、`Permission` 不得只靠颜色表达。

视觉：

- 继续支持 Light / Dark。
- 使用语义色或系统材质。
- 避免轻字体。
- 不创建 app 自己的独立深浅色模式。

## 13. 技术设计

### 13.1 边界

保持现有架构：

- `ImagePetCore`：无 Pet 依赖。
- `ImagePetStore`：状态、队列、权限、覆盖确认、动作路由中心。
- `DesktopPetWindowController`：窗口生命周期、位置、层级、尺寸。
- `DesktopPetView`：展示 Mini / Full 和触发 store action。

### 13.2 推荐新增 GUI 状态

建议新增 GUI-only 展示模式：

```swift
enum DesktopPetViewMode: Equatable {
    case mini
    case full
}
```

该状态属于 GUI 层，不进入 `ImagePetCore`。

持久化策略：

- P0：Pet 显示时默认 Mini，不持久化 mode。
- P1：可记住用户是否偏好 Full，但阻塞状态仍可覆盖。

### 13.3 Snapshot 扩展方向

现有 `DesktopPetSnapshot` 可继续作为业务状态来源。

可考虑增加只读派生属性或 helper：

- `isBlocking`
- `shouldForceFull`
- `miniAccessibilityLabel`
- `fullPrimaryAction`

但不要把窗口控制或权限逻辑放进 snapshot。

### 13.4 进度更新

真实实现不需要绑定每个 job 的细粒度变化。

推荐原则：

- 进度显示来自 `completedCount / jobs.count`。
- 大批量任务时可以节流 UI 更新，避免抖动。
- 具体节流间隔由实现和测试决定，不在 PRD 固定为 250ms 或 500ms。

## 14. 功能需求

| 编号 | 需求 | 优先级 | 验收要点 |
| --- | --- | --- | --- |
| PET5-01 | Pet 支持 Mini / Full 双态 | P0 | Mini 只显示 Pet；Full 显示状态和动作 |
| PET5-02 | Mini 可点击展开 Full | P0 | 点击 Mini 后出现 Full 面板 |
| PET5-03 | Full 可收回 Mini | P0 | 点击 Collapse 后只保留 Pet |
| PET5-04 | Mini 支持拖拽图片 | P0 | 拖入支持图片后进入现有队列 |
| PET5-05 | Mini 拖拽 hover 有明确反馈 | P0 | Pet 有可见姿态变化，窗口尺寸不变 |
| PET5-06 | 阻塞状态自动展开 Full | P0 | `needsSetup`、`confirm`、`permission` 不停留在纯 Mini |
| PET5-07 | Done 不无条件收回 | P0 | Mini 发起保持 Mini；Full 查看时保持 Full |
| PET5-08 | Issues 不无条件打断 | P1 | 部分失败只提示；全部失败/权限失败展开 |
| PET5-09 | 右键菜单提供 Show Panel / Open App / Hide | P1 | Mini 无按钮时仍有发现路径 |
| PET5-10 | Reduce Motion 覆盖双态动画 | P0 | 开启后无循环或缩放动画 |
| PET5-11 | VoiceOver 可识别 Mini 和 Full | P0 | Mini 状态、Full 按钮、进度均可读 |
| PET5-12 | 不改变核心压缩和安全路径 | P0 | `ImagePetCore` 无变更，覆盖确认和权限仍走现有路径 |

## 15. 自动化测试建议

新增或扩展 XCUITest：

1. `testDesktopPetStartsInMiniMode`
   - 打开 Pet。
   - 验证 Mini 只显示 Pet，不显示 Full 标题和按钮。

2. `testDesktopPetMiniExpandsToFull`
   - 点击 Mini。
   - 验证出现 `Ready`、`Add`、`Open App` 或对应 Full 控件。

3. `testDesktopPetFullCollapsesToMini`
   - 从 Full 点击 Collapse。
   - 验证回到 Mini，动作按钮消失。

4. `testDesktopPetMiniAcceptsImages`
   - 通过 Mini 发起添加或拖拽等价入口。
   - 验证任务进入队列并进入 `Eating`。

5. `testDesktopPetBlockingStatesForceFull`
   - 覆盖模式从 Mini 发起。
   - 验证 `Confirm` 自动展开并激活主窗口确认。

6. `testDesktopPetIssuesMiniBehavior`
   - 触发部分失败。
   - 验证不会错误进入 `Permission`，Full 中有 `Retry`。

7. `testDesktopPetReduceMotion`
   - 在可控环境下开启 Reduce Motion 或检查 no-animation fallback。
   - 验证关键状态仍可读。

保留现有验证集：

```bash
swift test
xcodebuild -project ImagePet.xcodeproj -scheme ImagePet -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' test
./script/build_and_run.sh --verify
git diff --check
```

## 16. 手工验收

必须手工确认：

- Pet 显示后默认是 Mini。
- Mini 长期停留在桌面上不显得像控制面板。
- Mini 可拖动，位置可恢复。
- Mini 跨 Space 行为与 v0.4 一致。
- 点击 Mini 可展开 Full。
- Full 可收回 Mini。
- 拖入 20 张图片到 Mini 后进入处理。
- 处理中点击 Mini 可查看进度。
- 完成后 Mini 不强制展开。
- Full 中完成后保留 `Reveal`。
- 混入坏图后 Mini 有异常提示，Full 有 Retry。
- 覆盖模式从 Mini 发起时必须进入确认流程。
- 输出目录失效或权限不足时必须展开解释。
- Reduce Motion 开启后动效降级。
- VoiceOver 能读出 Mini 状态和 Full 控件。

## 17. 风险与取舍

### 风险一：Mini 被加回面板信息

如果 Mini 加了角标、文字、按钮、进度环，会重新变成小面板。P0 必须严格保持“只有 Pet”。

### 风险二：Full 变成主窗口替代品

如果 Full 加入输出格式、质量、保存位置等配置，会破坏低打扰定位。复杂设置继续留在主窗口。

### 风险三：自动收回打断用户

完成后无条件收回会让用户错过 `Reveal`。需要区分用户当前是在 Mini 还是 Full。

### 风险四：Issues 自动展开过度打扰

部分失败不一定需要立刻打断。只有全部失败、权限、覆盖确认等阻塞状态应强制解释。

### 风险五：双态引入第二状态机

View Mode 只能是展示状态，业务状态仍由 `ImagePetStore` 派生。不能让 Mini / Full 各自维护业务逻辑。

## 18. 成功指标

定性指标：

- 用户愿意长期保留 Mini。
- 用户能从 Mini 完成拖拽压缩。
- 用户能理解何时需要展开 Full。
- 阻塞状态不会让用户猜。
- Full 仍然轻，不像主窗口缩小版。

定量指标：

- Mini 点击展开 Full 的感知延迟低于 150ms。
- 从 Mini drop 到 `Eating` 状态的感知延迟低于 300ms。
- 20 张图片处理期间 Mini / Full 动画不卡顿。
- Pet UI 自动化测试覆盖不少于 10 个核心场景。
- 不新增 `ImagePetCore` 对 SwiftUI/AppKit 的依赖。

## 19. 发布范围

### P0: v0.5 必须交付

- Mini / Full 双态。
- Mini 只显示 Pet。
- 点击 Mini 展开 Full。
- Full 可收回 Mini。
- Mini 支持拖拽图片。
- 阻塞状态自动展开 Full。
- Done / Issues 的不打断策略。
- Reduce Motion 降级。
- VoiceOver 基础可读。
- 自动化测试覆盖核心路径。

### P1: v0.5 可选交付

- Mini 右键菜单。
- Full 非阻塞状态 30 秒无交互自动收回。
- Issues 轻微摇头动效。
- Done 根据批次规模微调庆祝时长。
- 记住用户偏好 Mini 或 Full。

### P2: v0.5 之后评估

- 自定义 Pet 图形资产。
- 更完整的 Pet 动画资源。
- Mini 边缘吸附。
- 历史批次入口。
- 菜单栏模式。

## 20. 开放问题

1. Full 非阻塞状态自动收回的默认时间是否定为 30 秒？
2. `Issues` 在多少失败比例时自动展开？建议 P0 只对全部失败展开。
3. Mini 是否必须在 P0 提供右键菜单？建议 P1。
4. Done 动画是否按批次数量延长？建议 P1。
5. 是否允许用户偏好“始终 Full”？建议 P1 或 P2。

