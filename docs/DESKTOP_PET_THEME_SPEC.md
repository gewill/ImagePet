# ImagePet 桌面宠物主题设计规范

> 本文档描述 ImagePet 桌面宠物的完整素材规范，可直接交给 AI 图像生成工具作为 prompt 参考。

---

## 1. 产品背景

ImagePet 是一个 macOS 图片压缩工具，桌面宠物是它的核心交互元素。宠物浮动在桌面上，通过不同的动画状态反映压缩进度（空闲 → 吃东西 → 完成 / 出错）。用户可以切换不同的宠物主题。

---

## 2. 现有主题参考

三套现有主题的 idle 静帧：

| ShibaInu | CuteCat | PixelSlime |
|:---:|:---:|:---:|
| ![ShibaInu](../Sources/ImagePet/Resources/ShibaInu/idle/frame_000.png) | ![CuteCat](../Sources/ImagePet/Resources/CuteCat/idle/frame_000.png) | ![PixelSlime](../Sources/ImagePet/Resources/PixelSlime/idle/frame_000.png) |
| 柴犬，圆润卡通风格，粗描边 | 可爱猫咪，与柴犬同风格体系 | 像素史莱姆，简约可爱 |

---

## 3. 技术规格

| 属性 | 要求 |
|---|---|
| **画布尺寸** | 256 × 256 px（正方形） |
| **格式** | PNG，带 Alpha 透明通道 |
| **背景** | 完全透明，角色浮在桌面上 |
| **色彩空间** | sRGB |
| **单帧文件大小** | 建议 < 30 KB，全主题 < 500 KB |
| **命名** | `frame_000.png`, `frame_001.png`, … 三位数零填充 |
| **渲染区域** | 角色居中，四周留 ~20 px 安全边距（给阴影/特效留空） |

> [!IMPORTANT]
> 所有帧**必须**保持角色在画布中的位置一致（锚点居中），否则动画会抖动。

---

## 4. 目录结构

每个主题是一个以主题名命名的文件夹，包含 **9 个动画子文件夹**：

```
ThemeName/
├── idle/          # 空闲呼吸  — 循环
├── eating/        # 正在压缩  — 循环
├── done/          # 压缩完成  — 播放一次
├── issues/        # 出错/警告 — 循环
├── dragHover/     # 拖拽悬停  — 循环
├── petting/       # 鼠标悬停  — 循环
├── stretch/       # 空闲变体  — 播放一次
├── yawn/          # 空闲变体  — 播放一次
└── sleep/         # 空闲变体  — 循环
```

文件夹名必须与 `PetAnimation` enum 的 `rawValue` 完全一致（区分大小写）。

---

## 5. 动画详细说明

### 5.1 帧数与播放方式

| 动画 | 帧数 | 播放 | 说明 |
|---|---|---|---|
| `idle` | 8 | 循环 | 默认状态，轻微呼吸/摇摆 |
| `eating` | 6 | 循环 | 张嘴咀嚼，表示正在压缩图片 |
| `done` | 12 | 一次 | 开心庆祝，停在最后一帧 |
| `issues` | 8 | 循环 | 困惑/难过，表示有文件失败 |
| `dragHover` | 4 | 循环 | 期待/张嘴等待，用户拖拽文件悬停时 |
| `petting` | 8 | 循环 | 开心摇尾巴/眯眼，鼠标悬停触摸 |
| `stretch` | 12 | 一次 | 伸懒腰，空闲一段时间后随机触发 |
| `yawn` | 10 | 一次 | 打哈欠，空闲一段时间后随机触发 |
| `sleep` | 8 | 循环 | 打瞌睡，空闲时备用 |

> [!TIP]
> 帧数不是硬性限制，但建议在上表范围内。帧数太少动画生硬，太多则文件体积过大。

### 5.2 播放速率

- 默认 **10 FPS**
- 节能模式下自动降至 **5 FPS**
- 设计动画时按 10 FPS 计算时长（如 8 帧 = 0.8 秒一个完整循环）

---

## 6. 各状态视觉情绪指南

### idle（空闲）
角色放松、自然站立或坐着，有轻微的呼吸/摇摆动作。这是用户看到最多的状态，必须看起来生动但不分散注意力。

![ShibaInu idle 参考](../Sources/ImagePet/Resources/ShibaInu/idle/frame_000.png)

### eating（正在压缩）
角色张嘴咀嚼或吞咽的动作，传达"正在吃掉/消化图片"的隐喻。可以加食物颗粒或吞咽特效。

![ShibaInu eating 参考](../Sources/ImagePet/Resources/ShibaInu/eating/frame_002.png)

### done（完成）
角色开心、满足的表情。可以有庆祝动作，如跳跃、撒花、闭眼微笑。最后一帧应定格在满足的表情上。

![ShibaInu done 参考](../Sources/ImagePet/Resources/ShibaInu/done/frame_005.png)

### issues（出错）
角色困惑、不安或难过。可以有问号、叉叉眼、汗滴等视觉元素。表达"有些事情出错了"但不要太可怕。

![ShibaInu issues 参考](../Sources/ImagePet/Resources/ShibaInu/issues/frame_003.png)

### dragHover（拖拽悬停）
角色兴奋等待，张嘴准备接住东西。传达"把文件放到我这里！"的期待感。

![ShibaInu dragHover 参考](../Sources/ImagePet/Resources/ShibaInu/dragHover/frame_001.png)

### petting（鼠标悬停抚摸）
角色享受被抚摸的样子。眯眼、微笑、摇尾巴等快乐反馈。

![ShibaInu petting 参考](../Sources/ImagePet/Resources/ShibaInu/petting/frame_003.png)

### sleep（打瞌睡）
角色闭眼打瞌睡，可以有 Z 字符飘出。轻微起伏的呼吸感。

![ShibaInu sleep 参考](../Sources/ImagePet/Resources/ShibaInu/sleep/frame_003.png)

### stretch（伸懒腰）
角色伸展身体的动作。从正常姿势 → 拉伸 → 回到正常姿势。一次性播放。

### yawn（打哈欠）
角色张大嘴打哈欠。从正常 → 张嘴 → 闭嘴。一次性播放。

---

## 7. 画面显示上下文

宠物在桌面上的实际显示区域：

| 模式 | 窗口尺寸 | 角色渲染区 | 说明 |
|---|---|---|---|
| Mini | 80 × 80 pt | 72 × 72 pt | 只显示角色，无 UI 控件 |
| Full | 192 × 176 pt | 72 × 60 pt | 角色 + 标题 + 按钮面板 |

- 256 px 的源图会被缩小到约 64 × 56 pt 渲染（Retina 下对应 128 × 112 px）
- 角色下方有圆角色块背景和阴影
- 窗口背景完全透明，角色直接浮在桌面上

> [!NOTE]
> 虽然角色在 Full 模式下只显示 60 pt 高，但 256 px 源图保证了 Retina 屏清晰度和未来扩展空间。

---

## 8. 美术风格指南

### 推荐风格
- **圆润卡通**：粗描边（2–3 px）、圆角造型、柔和阴影
- **像素风**：低分辨率放大、复古游戏感
- **扁平矢量**：简洁几何形、少量渐变
- **手绘涂鸦**：铅笔/水彩质感、手工感

### 设计要点

> [!IMPORTANT]
> 以下要点必须遵守：

1. **透明背景**：角色必须在透明画布上，不能有背景色块
2. **居中对齐**：所有帧的角色锚点保持一致，避免跳动
3. **辨识度**：在 60–80 pt 缩小后仍能识别表情和状态
4. **一致性**：同主题 9 个动画的风格、线条粗细、配色必须统一
5. **情绪清晰**：每个状态的情绪要一眼看出（开心/难过/困惑/放松）
6. **轻量化**：尽量减少颜色数和复杂渐变以控制 PNG 体积

### 配色建议
- 选取 1 个主色 + 1 个辅色 + 黑色描边
- 参考现有主题：柴犬用暖橙，史莱姆用天蓝
- 避免使用过于刺眼的纯色，用柔和的色调

---

## 9. 交付清单

为新主题生成一套完整素材，需要交付：

```
NewThemeName/
├── idle/           8 帧 (frame_000.png ~ frame_007.png)
├── eating/         6 帧 (frame_000.png ~ frame_005.png)
├── done/          12 帧 (frame_000.png ~ frame_011.png)
├── issues/         8 帧 (frame_000.png ~ frame_007.png)
├── dragHover/      4 帧 (frame_000.png ~ frame_003.png)
├── petting/        8 帧 (frame_000.png ~ frame_007.png)
├── stretch/       12 帧 (frame_000.png ~ frame_011.png)
├── yawn/          10 帧 (frame_000.png ~ frame_009.png)
└── sleep/          8 帧 (frame_000.png ~ frame_007.png)

共 76 帧 PNG 文件
```

### 集成步骤
1. 将主题文件夹放入 `Sources/ImagePet/Resources/`
2. 在 `AppSettingsView.swift` 的主题选择列表中添加一张卡片
3. 无需修改动画代码——`ThemeCache` 会自动按文件夹名加载

---

## 10. AI 生图 Prompt 模板

以下模板可直接用于 AI 图像生成工具：

### 通用角色描述
```
Design a cute [动物/角色名] character for a macOS desktop pet app.
The character should be centered on a 256×256 transparent PNG canvas
with ~20px safety margin. Style: [圆润卡通/像素风/扁平矢量].
Use thick outlines (2-3px), soft shadows, and a warm color palette.
The character must be recognizable when scaled down to 60px height.
```

### 各状态 Prompt

```
idle:     [角色] standing relaxed, subtle breathing animation, gentle sway, 8 frames
eating:   [角色] chewing with mouth open, happy expression, food particles, 6 frames
done:     [角色] celebrating happily, sparkles and confetti, satisfied smile, 12 frames
issues:   [角色] confused and worried, question mark, X-eyes or sweat drops, 8 frames
dragHover: [角色] excited and waiting, mouth wide open ready to catch, 4 frames
petting:  [角色] enjoying being petted, squinting eyes, wagging tail, 8 frames
stretch:  [角色] stretching body, from rest to full stretch to rest, 12 frames
yawn:     [角色] yawning, mouth opens wide then closes, sleepy, 10 frames
sleep:    [角色] dozing off, eyes closed, Z characters floating, gentle breathing, 8 frames
```

> [!TIP]
> 生成序列帧时，建议先生成 frame_000（关键帧），确认风格后再生成其余帧。每个动画的第一帧和最后一帧应该能自然衔接（循环动画）或干净收尾（一次性动画）。
