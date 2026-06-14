# ImagePet PRD v0.7: 静默桌面 Pet 常驻与内置主题扩展

## 1. 版本定位

在 ImagePet v0.6 中，桌面 Pet 已经具备 `Cute Cat` 帧动画引擎，以及 Mini / Full 双态交互模型。

ImagePet v0.7 的核心目标收窄为：

```text
让 ImagePet 可以不打开主窗口，只靠桌面 Pet 常驻完成高频压缩；主题扩展作为体验加分项，而不是本版的主叙事。
```

v0.7 只包含以下 P0 / P1：

1. **P0：Launch at Login + Silent Pet Startup**
   - 支持沙盒兼容的 Launch at Login。
   - 当应用以登录项方式启动时，不主动弹出主窗口。
   - 按用户偏好恢复桌面 Pet，并提供可靠入口重新打开主应用。
   - 既有 Direct Drop 静默路径只作为该启动模式下的回归验收，不作为新增入口重做。

2. **P1：至少 1 套高质量内置宠物主题**
   - 新增至少 1 套只读内置主题，候选为 `Shiba Inu` 或 `Pixel Slime`。
   - 第二套主题不强制进入 v0.7，视素材质量与 QA 成本决定是否顺带交付。
   - 继续沿用 `Cute Cat` 的帧动画模型、资源预算和安全边界。
   - v0.7 不做用户自定义主题导入。

v0.7 明确不做：

- `.zip`、文件夹或 `theme.json` 自定义主题导入。
- 主题市场、在线下载、主题分享或用户生成主题管理。
- 基于系统电量状态的自动节能模式。
- 互动音效。
- 任何 `ImagePetCore` 压缩算法、输入格式、输出格式规则或 `maxConcurrentJobs = 2` 的改动。
- 第二套主题的强制交付，以及更细节的主题切换动效。

---

## 2. 设计简报

- **产品对象**：ImagePet macOS 桌面 Pet，作为登录后可常驻的低打扰图片压缩入口。
- **设计对象**：开机启动流程、启动来源识别、静默启动状态、Pet 可见性偏好恢复、既有 Pet 浮窗拖拽路径验收、内置主题选择、主题资源验收。
- **技术范围**：
  - 在 `Sources/ImagePet` 增加 Launch at Login 设置与启动状态处理。
  - Pet 直接拖拽继续作为既有基线路由到 `ImagePetStore.addDroppedURLs(_:)`。
  - 新增至少 1 套内置主题资源与主题选择 UI，主题候选为 `Shiba Inu` / `Pixel Slime`。
  - GUI-only 职责继续留在 `Sources/ImagePet`；v0.7 不新增独立后台压缩 Core 或 CLI 路径。

---

## 3. 优先级范围

### 3.1 P0：Launch at Login + Silent Pet Startup

目标：用户登录后，ImagePet 可以通过桌面 Pet 保持可用，而不是每次都弹出主窗口。

- **API 选型**：优先使用 macOS 13+ `SMAppService.mainApp`。
  - 当前最低系统版本为 macOS 13+，因此不需要为 macOS 12 或更低版本提供登录项降级实现。
  - 如果未来降低最低系统版本，设置页必须隐藏该开关或显示“不支持当前系统版本”。
- **用户控制**：
  - 在设置中提供 Launch at Login 开关。
  - 注册失败时只在设置页显示 inline warning 或 toast，不进入 Desktop Pet Display State。
  - 用户仍可在 macOS 系统设置中统一管理登录项。
- **启动来源模型**：
  - 必须通过可测试的 `LaunchMode` 注入或推断机制区分启动来源。
  - 至少定义以下模式：
    - `normal`：用户普通打开 app。
    - `loginItem`：系统登录项拉起。
    - `fileOpen`：Finder 或系统通过文件打开 app。
    - `reopen`：Dock 图标、菜单或系统 reopen 事件重新激活 app。
  - 静默启动规则只应用于 `loginItem`，不得误伤普通启动、文件打开或 Dock 重新激活。
- **静默启动策略**：
  - 普通启动维持当前行为：打开主窗口。
  - 登录项启动不应创建或前置主窗口。
  - 登录项启动时按以下优先级恢复：
    - `desktopPetEnabled == false`：不显示 Pet，不显示主窗口，app 保持后台可被 Dock / menu 打开。
    - `desktopPetEnabled == true && petVisible == true`：显示 Mini；若当前存在阻塞状态，则允许自动展开 Full。
    - `desktopPetEnabled == true && petVisible == false`：不显示 Pet，不显示主窗口，app 保持后台可被 Dock / menu 打开。
  - Pet 或状态入口必须提供明确的“打开主应用”路径。
- **生命周期约定**：
  - 关闭主窗口不等于关闭 Launch at Login。
  - 隐藏桌面 Pet 应持久化用户的 Pet 可见性偏好。
  - 退出应用应停止当前 UI 活动，并保留下次启动所需的偏好状态。
  - Dock 点击、菜单打开或 reopen 事件必须能可靠调出主窗口，即使 app 是登录项静默启动的。
  - Finder 文件打开不走静默路径；如果未来支持文件打开，应打开主窗口或进入明确的导入确认流程。

### 3.2 P0：既有悬浮窗拖拽压缩的验收与硬化 (Direct Drop to Pet)

目标：该能力已存在，v0.7 不把它当作新增入口重做；本版本只补齐它在静默启动场景下的产品合同、验收标准和安全例外。

- **拖拽响应**：
  - 保持 Mini 与 Full 桌面 Pet 浮窗接收文件 URL。
  - 拖拽 hover 时进入 `InteractionState.dragHover`，播放现有投喂/等待动画。
  - 不支持的文件作为单个失败 job 展示，继续使用现有短错误文案。
- **队列规则**：
  - 拖入文件进入与主窗口拖拽、`Add Images` 相同的 `ImagePetStore` 队列。
  - 保持 `maxConcurrentJobs = 2`。
  - 单个文件失败不得中断整个批次。
- **输出规则**：
  - Designated Folder 模式使用上一次授权的输出目录。
  - Original Folder 模式在原图所在文件夹生成非覆盖副本，并按需请求文件夹写入授权。
  - Overwrite Original 模式必须保留现有破坏性覆盖确认，不允许静默替换原文件。
- **静默处理边界**：
  - 只要流程可以安全继续，主窗口保持隐藏。
  - 遇到以下情况时，应用可以打开主窗口或系统授权面板：
    - 未设置输出目录
    - bookmark 失效或被拒绝
    - 原文件夹写入授权不足
    - 覆盖原图确认
  - Pet Full 视图必须解释阻塞状态，不能把需要授权的流程伪装成仍在静默处理。
- **反馈退出**：
  - Eating 状态显示紧凑进度，例如 `3 / 10`。
  - 全部成功后播放 Done，并沿用现有超时回到 Idle。
  - 混合失败或全部失败后显示 Issues，并保留 retry / reveal / open-app 路径。
- **用户信任边界**：
  - Mini 不显示保存路径。
  - 首次通过 Pet 静默压缩成功后，Full / Done 状态必须能解释保存位置，或提供清晰的 Reveal 入口。
  - 用户点击 Mini 展开 Full 后，应能知道文件保存到了 Designated Folder、Original Folder 还是 Overwrite Original 路径。

### 3.3 P1：至少一套高质量内置宠物主题

目标：增加桌面 Pet 的选择，但不牺牲素材质量、测试稳定性或打包体积。

v0.7 P1 的交付标准是至少新增 1 套高质量内置主题。第二套主题是 P2 候选，不作为 v0.7 发布阻断项。

#### Shiba Inu

- **Idle**：放松呼吸，尾巴小幅摆动。
- **DragHover**：站起来并快速摇尾巴。
- **Eating**：在小碗或骨头旁咀嚼。
- **Done**：短暂开心转圈或跳跃。
- **Issues**：耳朵垂下，呈现委屈状态。

#### Pixel Slime

- **Idle**：小幅规律弹动。
- **DragHover**：向上拉伸并张开嘴等待投喂。
- **Eating**：通过 squash-and-stretch 形变吞入图片。
- **Done**：短暂庆祝弹跳，允许有限高光效果。
- **Issues**：摊成小水滴或出现警示气泡。

主题要求：

- 使用透明 PNG 序列帧。
- 动作状态命名沿用 `PetAnimation`。
- 帧率为 `8-12 fps`。
- 单个动作不超过 `24` 帧。
- 单个内置主题资源体积不超过 `3 MB`。
- 资源必须随 app 打包，保持只读，并且不依赖网络。
- 切换主题不得影响压缩设置、当前队列、sandbox 授权或 Pet 可见性。
- 主题必须覆盖必需动作；缺少必需动作的主题不得进入选择器。
- 主题加载或切换失败时保持当前主题，不影响队列和压缩任务。
- 处理中切换主题时，新主题应从当前 `DisplayState` 对应动画开始播放。
- 每套主题必须提供 Reduce Motion 可用的静态帧，并在 Light / Dark 下保持可读。

---

## 4. 设置界面要求

v0.7 更新“桌面宠物”设置页：

1. **开机自动启动** Toggle。
   - 注册失败时在设置页显示 inline warning 或 toast。
   - 注册失败不改变 Pet Display State。
2. **主题选择器**，至少包含：
   - `Cute Cat`
   - 1 套新增内置主题：`Shiba Inu` 或 `Pixel Slime`
   - 第二套主题如果素材质量达标，可以作为非阻断项一并展示。
3. v0.6 已有行为/性能控制可以保留，但 v0.7 不新增基于系统电量状态的自动节能检测。

v0.7 不加入自定义导入、音效控制或主题包管理入口。

---

## 5. 动画与性能预算

- 单个内置主题资源：`<= 3 MB`。
- 单个动作序列帧：`<= 24` 帧。
- 帧率：`8-12 fps`。
- 在 Apple Silicon 上，Desktop Pet Idle 动画应保持低 CPU 占用和低感知打扰。
- Eating 动画预算不计入压缩 Core 的 CPU 工作负载。
- 主题切换不得出现明显白屏、空帧或磁盘读取卡顿。

---

## 6. 测试与验证计划

### 6.1 自动化测试

1. **Launch at Login 状态处理**
   - 通过可注入 launch mode 或等价测试 seam 覆盖启动路径。
   - 验证登录项启动不前置主窗口。
   - 验证 `normal`、`loginItem`、`fileOpen`、`reopen` 模式不会互相污染。
   - 验证 `desktopPetEnabled` 与 `petVisible` 的优先级恢复规则。
   - 验证注册失败只影响设置页错误展示，不进入 Desktop Pet Display State。

2. **Pet 直接拖拽回归与验收**
   - 通过模拟或单元测试覆盖 Pet 浮窗 URL ingestion 到 `ImagePetStore.addDroppedURLs(_:)`。
   - 验证安全的 Designated Folder drop 不打开主窗口。
   - 验证 Overwrite Original 模式仍进入现有确认流程。
   - 验证缺少输出目录或权限失败时强制进入 Full / 解释状态。
   - 验证首次静默成功后 Full / Done 状态可解释保存位置或提供 Reveal。

3. **内置主题资源**
   - 验证 `Cute Cat` 与至少 1 套新增内置主题存在。
   - 验证必需 animation 文件夹和连续帧命名。
   - 验证帧数、图片可读性、透明 PNG、Reduce Motion 静态帧和体积预算。
   - 验证缺少必需动作的主题不会进入选择器。
   - 验证主题切换失败时保持当前主题且不影响队列。

4. **回归覆盖**
   - 现有压缩、覆盖确认、失败重试、Reveal、Mini / Full、Reduce Motion 测试必须保持通过。

### 6.2 手工验收

- 打开 Launch at Login，退出后模拟登录项启动，确认只出现预期的静默表面。
- 验证 `desktopPetEnabled` / `petVisible` 组合下的登录项恢复行为。
- 验证 Dock 点击或 Open App 入口能从静默状态可靠调出主窗口。
- 分别把支持格式图片拖到 Mini 和 Full Pet。
- 确认安全路径下压缩不会打开主窗口。
- 确认 overwrite 与权限路径会打开必要的确认/授权 UI。
- 首次通过 Pet 静默压缩成功后，展开 Full 并确认用户能理解保存位置或直接 Reveal。
- 在 idle、eating 和完成态下切换 `Cute Cat` 与新增主题。
- 验证每套已交付主题在 Light / Dark 和 Reduce Motion 下都可读、不卡顿。

---

## 7. 后续版本规划

以下功能明确延后到 v0.7 之后。

### P2 / v0.7.x 候选：第二套内置主题与切换动效

- 如果 v0.7 只交付 `Shiba Inu` 或 `Pixel Slime` 其中一套，另一套进入 P2。
- 主题切换时可以加入更细节的过渡动效，但不得影响压缩队列和 Pet 状态真实性。
- 可评估 Eating 状态下主题切换的短过渡动画，但不能出现空帧、错态或任务进度重置。
- 第二套主题必须达到与 P1 主题相同的资源完整性、Reduce Motion、Light / Dark 和 QA 标准。

### v0.8 候选：自定义主题导入

- 支持 `.zip` 或文件夹导入。
- 定义带版本号的 `theme.json` schema。
- 合法主题复制到 App sandbox 的 Application Support 目录。
- 必须加入 Zip Slip 防护、symlink 拒绝、文件数量上限、帧尺寸上限、图片格式 allowlist、导入失败回滚、主题删除/更新，以及重复 `themeId` 处理。

未来 `theme.json` 示例：

```json
{
  "schemaVersion": 1,
  "themeId": "custom_slime_red",
  "themeName": "Red Slime",
  "author": "PixelStudio",
  "version": "1.0.0",
  "fps": 10,
  "animations": {
    "idle": ["idle_0.png", "idle_1.png", "idle_2.png"],
    "dragHover": ["hover_0.png", "hover_1.png"],
    "eating": ["chew_0.png", "chew_1.png", "chew_2.png"],
    "done": ["done_0.png", "done_1.png"],
    "issues": ["error_0.png", "error_1.png"]
  }
}
```

### v0.8+ 候选：智能电池节能模式

- 通过独立服务检测供电来源与低电量状态。
- 提供可注入测试状态，避免 UI 测试依赖真实硬件电量。
- 仅在用户选择自动模式时降低 idle 变体和动画帧率。

### v0.8+ 候选：互动音效

- 增加内置短音效。
- 提供静音与音量控制。
- 尊重系统音频预期并持久化用户偏好。
- 音效必须可关闭，并且不得成为任何关键压缩流程的必要条件。
