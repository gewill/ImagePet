# ImagePet PRD v0.16: 桌面 Pet 主题生产与验证管线

## 1. 版本定位

v0.16 规划一个受 Codex `hatch-pet` 工作流启发的桌面 Pet 主题生产与验证管线。本版本不把图像生成能力加入 ImagePet app。ImagePet 仍然是本地图片压缩工具；主题创建、修复、QA 和打包都在离线流程完成，app 只消费已经验证过的主题资产。

本版本的产品承诺是：

```text
ImagePet 主题是可复用、可验证的资产包：设计师或生成工具可以离线创建主题，ImagePet 可以稳定加载主题，损坏的 Pet 资产会在进入运行时前失败。
```

## 2. 背景

ImagePet 当前已经有资源驱动的桌面 Pet 实现：

- 运行时动画由 `BuiltInPetTheme`、`ThemeCache`、`FrameAnimator`、`DesktopPetView` 和 `AppSettingsView` 驱动。
- 当前内置主题使用 9 个动画文件夹下的 256 x 256 透明 PNG 帧。
- `docs/DESKTOP_PET_THEME_SPEC.md` 定义了当前视觉与文件夹级资产要求。
- 现有资产测试已经检查帧尺寸、帧数量和单主题体积预算。

Codex `hatch-pet` skill 提供了更完整的资产生产模型：

- 把 Pet 当成带 manifest 元数据和 sprite 资产的包。
- 把视觉生成与确定性的几何处理、验证、contact sheet、preview、打包和清理分离。
- 先用 canonical base image 锁定角色身份，再制作各状态动画。
- 机器验证是必要条件，但最终视觉 QA 仍然检查身份漂移、动作语义、透明度和状态可读性。
- 修复以最小失败状态为单位，不因为一行坏帧就重做整套主题。

v0.16 只吸收这些生产管线思想，并适配 ImagePet 当前运行时；不直接复制 Codex 的 atlas 合约。

## 3. P0 范围

### 3.1 主题包契约

定义一个 ImagePet 主题包格式，可同时描述内置主题和未来可能导入的自定义主题。

P0 包结构：

```text
ThemeName/
├── theme.json
├── idle/frame_000.png
├── eating/frame_000.png
├── done/frame_000.png
├── issues/frame_000.png
├── dragHover/frame_000.png
├── petting/frame_000.png
├── stretch/frame_000.png
├── yawn/frame_000.png
└── sleep/frame_000.png
```

P0 `theme.json` 字段：

```json
{
  "schemaVersion": 1,
  "themeId": "Dog",
  "displayName": "Dog",
  "description": "A friendly all-round puppy with balanced motion.",
  "defaultFPS": 10,
  "cellSize": { "width": 256, "height": 256 },
  "assetFormat": "png-sequence",
  "states": {
    "idle": { "mode": "loop", "recommendedFrames": 8 },
    "eating": { "mode": "loop", "recommendedFrames": 6 },
    "done": { "mode": "once", "recommendedFrames": 12 },
    "issues": { "mode": "loop", "recommendedFrames": 8 },
    "dragHover": { "mode": "loop", "recommendedFrames": 4 },
    "petting": { "mode": "loop", "recommendedFrames": 8 },
    "stretch": { "mode": "once", "recommendedFrames": 12 },
    "yawn": { "mode": "once", "recommendedFrames": 10 },
    "sleep": { "mode": "loop", "recommendedFrames": 8 }
  }
}
```

验收：

- `theme.json` 写入 `docs/DESKTOP_PET_THEME_SPEC.md`。
- 内置主题可以用该包契约描述，且不改变现有视觉行为。
- 合约保留 ImagePet 当前状态名，不采用 Codex `idle/running/review` 状态名。

### 3.2 离线生产 run 目录

为生成工具或设计师交付资产定义一个离线生产目录结构。

打包前的预期输出：

```text
run/
├── theme_request.json
├── source/
├── decoded/
├── final/ThemeName/
├── qa/contact-sheet.png
├── qa/previews/*.gif
├── qa/review.json
└── qa/run-summary.json
```

规则：

- 生成工具可以产出粗糙 row strip、单帧或完整文件夹，但标准化与验证由确定性脚本负责。
- ImagePet 不应只因为文件树存在就接受生成资产。
- 生产管线需要写出简洁的 `run-summary.json`，包含验证状态、来源说明、输出路径和已知 warning。

验收：

- PRD 明确区分 app 消费的 `ThemeName/` 与 authoring workflow 使用的 `run/`。
- 中间文件默认不提交，除非明确需要用于设计 review。
- 最终主题资产和 QA 产物路径稳定可预测。

### 3.3 验证与 QA 脚本

新增或扩展仓库内脚本，让主题验证可以脱离 Xcode 运行。

P0 验证项：

- 9 个 ImagePet 动画状态文件夹全部存在。
- 帧文件使用 `frame_000.png` 命名，并且编号连续。
- 每帧都是 256 x 256 px、带 alpha 的 PNG。
- 在可检测范围内，透明像素不保留不安全的隐藏颜色残留。
- 不存在空帧。
- 每个状态的帧数在允许范围内。
- 单主题总大小保持在 3 MB 以下，除非后续 PRD 明确修改预算。
- `defaultFPS` 位于支持的 8-12 FPS 范围内。
- `theme.json` 的 ID 和文件夹名合法且稳定。

P0 QA 输出：

- `qa/contact-sheet.png`：展示所有状态和代表帧。
- `qa/previews/*.gif`：每个状态一份 motion preview。
- `qa/review.json`：机器可读的 error / warning。

验收：

- 当前可选内置主题通过 validator，或有明确记录的失败原因。
- `swift test` 仍覆盖 bundled asset contract。
- 文档和脚本变更后 `git diff --check` 通过。

### 3.4 视觉 QA 规则

为主题验收记录人工或模型视觉 QA checklist。

视觉 QA 必须拒绝：

- 不同状态之间物种、脸、配色、材质或剪影漂移。
- 身体被裁切，或动作超过可见安全区域。
- 白底、黑底、棋盘格底或非透明背景。
- 分离特效造成看起来像多个独立 sprite。
- 状态语义与 ImagePet 行为不匹配。
- idle loop 虽然技术上有差异，但视觉上几乎静止。
- motion preview 出现非预期尺寸跳动、基线跳动或时间顺序反转。

状态语义：

- `idle`：安静呼吸、眨眼、轻微摆动。
- `dragHover`：期待用户放下图片的姿态。
- `eating`：明显表达正在处理或压缩图片。
- `done`：完成后的满足感或一次性庆祝动作。
- `issues`：清楚但不吓人的失败或警告状态。
- `petting`：hover 时的友好回应或被抚摸反馈。
- `stretch`：一次性 idle 变体，剪影变化需要可读。
- `yawn`：一次性困倦 idle 变体。
- `sleep`：低能量循环。

验收：

- `docs/DESKTOP_PET_THEME_SPEC.md` 区分机器验证与视觉验收。
- 没有 contact sheet 和 preview review 时，主题不能标记为验收完成。

### 3.5 运行时加载方向

引入 manifest-backed theme registry，同时保持当前运行时行为稳定。

实现方向：

- `ImagePetCore` 继续不包含 Pet 和主题逻辑。
- `ThemeCache` 与 `FrameAnimator` 继续作为运行时动画锚点。
- 主题元数据从 Swift 硬编码逐步迁移到 `theme.json`。
- P0 仍只加载 app resources 内的内置主题。
- 自定义 `.zip` 主题导入延后到 validator 和 manifest-backed bundled themes 稳定之后。

验收：

- 现有设置页可以基于 manifest-backed metadata 列出内置主题。
- 已保存的 selected theme 在主题缺失或重命名时仍能安全 fallback。
- 无效主题 metadata 不应导致运行时崩溃，应回退到默认主题。

## 4. P1 范围

- 如果 runtime profiling 显示文件数量造成加载成本，再把 PNG sequence 主题转换为单 atlas 或 WebP spritesheet。
- 增加主题包 preview 工具，可以从 Finder 打开 contact sheet 和 previews。
- 为 `theme.json` 增加可选 `author`、`license`、`source`、`createdAt` 字段。
- 增加迁移 helper，为历史主题或未来新增主题写出 `theme.json`。
- 如果外部工具生成 row strip 而不是文件夹，增加确定性 row-strip extraction 模式。
- 为外部生成主题增加 repair notes 和最小范围重生成 prompt。

## 5. 非目标

v0.16 明确不做：

- 不在 ImagePet 内部加入 AI 图像生成。
- 不做云端生成、登录、同步或在线主题市场。
- 在验证、fallback 和安全行为实现前，不提供用户可见的自定义主题导入。
- 主题包中不允许任意 JavaScript、可执行脚本、symlink、alias 或外部 URL。
- 不改变 ImagePet 压缩格式或 `ImagePetCore`。
- 不采用 Codex `1536x1872` atlas 合约，除非后续 PRD 明确选择 atlas runtime loading。
- 不做音效包导入或自定义音频。

## 6. 安全与沙盒边界

未来加入导入能力时，主题包必须被视为不可信文件：

- 拒绝 symlink、alias、路径穿越、隐藏可执行文件和嵌套压缩包。
- 在复制到 app 管理目录前，先强制检查文件数量、总大小、图片尺寸和图片格式 allowlist。
- 只有验证成功后，才能导入到 app-owned container path。
- 导入失败必须回滚部分导入。
- 主题资产永远不能获得用户选择的图片输入/输出文件夹权限。

v0.16 P0 只把这些规则写入设计并用于 shaping validator；运行时来源仍只限 bundled themes。

## 7. 文档变更

P0 文档更新：

- `docs/DESKTOP_PET_THEME_SPEC.md`：补充 `theme.json`、authoring pipeline、validation、contact sheet、preview 和 visual QA。
- `docs/PROGRESS.md`：标记 v0.16 规划与实现进展。
- `README.md`：在 Product Docs 中加入 v0.16 PRD。

可选文档：

- 如果生产流程细节让现有规格文档过长，新增 `docs/THEME_AUTHORING.md`。

## 8. 验证命令

规划文档阶段：

```bash
git diff --check
```

P0 进入实现后：

```bash
swift test
xcodebuild -project ImagePet.xcodeproj -scheme ImagePet -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' test
./script/build_and_run.sh --verify
git diff --check
```

主题生产验证需要增加脚本级命令，例如：

```bash
python3 script/validate_pet_theme.py Sources/ImagePet/Resources/Dog --json-out /tmp/dog-theme-review.json
```

具体脚本路径和参数属于实现细节，但该命令必须能在不启动 app 的情况下运行。

## 9. 完成标准

v0.16 可以标记为完成，当且仅当：

- 主题包契约已写入文档，并对当前可选 bundled themes 实现。
- 所有当前可选内置主题都包含或能解析到有效 `theme.json` metadata。
- validator 能捕捉缺失文件夹、错误命名、错误尺寸、空帧、超预算主题和无效 metadata。
- contact sheet 与 preview generation 可用于主题 QA。
- `BuiltInPetThemeAssetTests` 或替代测试覆盖 manifest-backed contract。
- 运行时 fallback 行为覆盖缺失或无效主题 metadata。
- `ImagePetCore` 继续不依赖 UI、Pet、主题或资产生产逻辑。

## 10. 后续问题

- ImagePet 是否在 v0.16 继续保持 PNG sequence runtime format，还是先 spike atlas loading 再确定 manifest schema？
- `docs/DESKTOP_PET_THEME_SPEC.md` 是否继续作为唯一 authoring guide，还是把较长的管线细节拆到 `docs/THEME_AUTHORING.md`？
- 如果未来开放用户导入，是否需要主题包签名、版本迁移和导入 UI 的独立 PRD？
