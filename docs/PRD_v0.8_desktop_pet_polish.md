# ImagePet PRD v0.8: 主题切换过渡打磨、视觉修复与空状态改造

## 1. 版本定位

在 ImagePet v0.7 中，我们成功实现了**静默桌面 Pet 常驻**以及内置的多主题选择（`Cute Cat`、`Shiba Inu` 与 `Pixel Slime`）。

ImagePet v0.8 的核心目标是：
```text
拒绝“为了宠物而做宠物”的产品漂移，守住 ImagePet 作为本地图片压缩工具的价值定位。本版本不引入任何外部声音系统和复杂的电池能效监测，而是集中工作于打磨现有三个内置主题（Cute Cat, Shiba Inu, Pixel Slime）的视觉与动效表现，重点消除 Mini <-> Full 状态切换时的布局跳跃，修复卡片边框显示缺陷，重构主界面列表空状态，并在自动化 UI 测试中补齐窗口中心点锚定校验，全面提升核心体验品质。
```

v0.8 包含以下三大功能模块：
1. **P0：内置主题切换与过渡动画打磨**：消除桌面 Pet 在 Mini 与 Full 状态切换时的布局跳跃与字符截断；实现中心点锚定的 UI 自动化测试；自查 Shiba Inu 与 Pixel Slime 在 Mini 态头像框下的边缘完整性。
2. **P0：ThemeCard 边框显示缺陷修复**：在 SwiftUI 侧改用 `.strokeBorder` 替换 `.stroke` 解决边框被外层 frame 截断的问题；化简卡片微动效，去除 Y 轴位移与 Spring 缩放，仅保留 Hover 阴影与选中高亮；坚守 `Cute Cat` 作为默认宠物主题。
3. **P0：空任务状态展示重构**：重新设计主窗口 `EmptyJobListView` 的空任务状态，引入契合主题风格的爪印水印与行动引导文案，打磨首屏视觉。
4. **P1：无障碍辅助打磨**：为设置页面的每一个 `ThemeCard` 赋予清晰的 Accessibility Value，优化 VoiceOver 体验。

---

## 2. 设计简报

*   **产品对象**：ImagePet macOS 桌面 Pet 与主应用设置面板。
*   **设计对象**：状态切换过渡动画、Empty State 占位、ThemeCard 边框描边、VoiceOver labels。
*   **技术范围**：
    *   在 `Sources/ImagePet` 增加/修改：
        *   界面打磨：重构 Mini <-> Full 切换动画逻辑，实现控制项与文本的延迟淡入淡出（Opacity 动画）。
        *   布局调整：使用 `.strokeBorder` 修复 `ThemeCard` 边框裁剪；化简 `ThemeCard` 的交互动画，去除 `.scaleEffect` 与 Y 轴位移；保持 `Cute Cat` 为默认主题。
        *   空状态打磨：引入内置宠物爪印占位图与磨砂感引导文案。
    *   **不改变** `ImagePetCore` 的基础图像压缩核心及既有沙盒读写权限边界（Sandbox 依然保持启用）。

---

## 3. 优先级范围与技术规范

### 3.1 P0：内置主题切换与过渡动画打磨 (Theme Transitions & Centering)

目标：精细化打磨桌面 Pet 的动效表现，避免状态切换时出现突兀的闪烁、变形与截断。

#### 3.1.1 Mini <-> Full 切换过渡动画优化 (Timing Synchronizing)
*   **当前问题**：当桌面 Pet 在 Mini 态（80x80 无背景）与 Full 态（192x176 磨砂卡片）之间切换时，由于 AppKit 窗口大小的改变（带动画）与 SwiftUI 内部子视图重新排布（瞬间发生）存在时间差，会导致布局瞬间跳跃、文本被部分截断或出现瞬间的白边。
*   **优化方案**：
    *   **延迟大小设定与淡入淡出**：在进行 `.collapse`（折叠至 Mini）时，在 SwiftUI 侧优先对 Full 态的控制按钮、文本等进行淡出（Opacity 动画从 `1.0 -> 0.0`），随后触发 AppKit 窗口框架缩小。
    *   在进行 `.expand`（展开至 Full）时，先由 AppKit 窗口完成放大，随后 SwiftUI 内部的控制项、进度条等以淡入（Opacity 动画 `0.0 -> 1.0`）及微小上浮位移渲染，使整个变化过程具备流畅的呼吸感。
    *   **中心点锚定校验**：精确锁定窗口在缩放时的几何中心（MidX, MidY），折叠/展开前后窗口中心点坐标不允许发生任何跳跃性位移。

#### 3.1.2 资源素材全屏兼容性自查
*   自查现有 `Shiba Inu` 和 `Pixel Slime` 的 PNG 序列帧素材在 Mini 态（包裹在 72x60 的头像框内）下的显示。
*   检查所有动作状态（如 `eating`、`yawn` 等）帧图像的边缘留白，确保动画播放到极限帧（如伸懒腰 stretch 或打哈欠 yawn）时，角色的身体边缘不会被头像框容器的 `clipShape` 截断，也不会因为图片定位偏移导致角色在播放动画时产生不规则的画面剧烈抖动。

---

### 3.2 P0：ThemeCard 边框缺陷修复与 Cute Cat 默认主题 (ThemeCard Fix & Cute Cat Default)

目标：修复设置页主题选择卡片的绘制 Bug，精简交互动画降低系统负担，坚守 Cute Cat 的 Mascot 心智。

#### 3.2.1 ThemeCard 边框显示缺陷修复
*   **当前问题**：目前主题选择卡片 `ThemeCard` 存在边框显示不完整的问题（由于边框描边 `.stroke` 会沿路径中线向外扩张，导致卡片边缘部分超出 frame bounds 被容器截断）。
*   **修复方案**：在 SwiftUI 侧改用 `.strokeBorder` 替换 `.stroke`，使得描边完全收缩在卡片内部，或为卡片外层添加适当 padding 缓冲区，确保选中和悬浮时的加粗描边高亮能完整、无缺陷地呈现。

#### 3.2.2 交互微动效去重 (Tame Card Animations)
*   **过度设计剔除**：移除原计划中过度设计的 Y 轴位移悬浮（Y -4）、呼吸缩放（Scale 1.03）和 Spring 弹性动画，以防止在 SwiftUI 中引入额外渲染 Bug 并精简能耗。
*   **保留核心视觉反馈**：
    *   **Hover 反馈**：当鼠标指针悬停在卡片上时，卡片底部的投影（Shadow）半径适度增大，展现交互聚焦。
    *   **Selected 反馈**：卡片边框高亮主色描边加粗（2px），未选中卡片为浅灰色描边（1px）。

#### 3.2.3 坚守 Cute Cat 作为默认主题
*   拒绝无业务/数据支撑的默认主题变更为 Shiba Inu 的方案，继续维持 `Cute Cat` 为系统默认初始化宠物主题，尊重老用户心智。

---

### 3.3 P0：空任务状态展示重构 (Empty State Redesign)

目标：让队列的空状态具有设计质感，提高首屏压缩引导的友好度。

*   **当前问题**：目前主窗口在没有任务时仅在列表中部显示一行灰色小字 "No images yet"，显得有些简陋，没有体现“宠物”工具的调性。
*   **重构设计**：
    *   **占位背景**：引入一个带有透明度（opacity 0.4）的内置宠物爪印或简化头像图标。
    *   **引导文案**：设计多行带磨砂质感的引导文字（例如：“No images in queue” 为主要粗体，“Drag images here or click Add to begin” 为副文本），提示用户主要操作行为。

---

### 3.4 P1：无障碍辅助打磨 (Accessibility Labels)

*   为设置页面的每一个 `ThemeCard` 属性赋予清晰的 Accessibility Value（例如：“Theme: Cute Cat, Selected”或“Theme: Shiba Inu, Click to Select”）。
*   为音效音量 Slider（如在后续版本加入时）补充辅助说明文本，支持 VoiceOver 精确读出百分比值。

---

## 4. 设置界面要求 (Settings View Layout)

设置窗口的“桌面宠物”板块布局需进行如下拓展重组：

```text
+--------------------------------------------------------------+
| [ ] Show Desktop Pet                                         |
|                                                              |
| Theme Select                                                 |
| +-----------+ +-----------+ +-------------+                  |
| |  Cute Cat | | Shiba Inu | | Pixel Slime |                  |
| |  [Selected| |           | |             |                  |
| +-----------+ +-----------+ +-------------+                  |
|                                                              |
|--------------------------------------------------------------|
|                                                              |
| [ ] Energy Saving Mode                                       |
| [i] Halves the animation frame rate to minimize CPU usage.   |
+--------------------------------------------------------------+
```

---

## 5. 能耗与性能预算 (Performance Budget)

*   **CPU 运行时开耗**：
    *   在常规运行下，桌面 Pet 的整体 CPU 占用应控制在 `< 0.5%`（Idle 状态）。
    *   关闭或隐藏桌面 Pet 窗口后，没有任何 Timer 动画定时器在后台运行。

---

## 6. 测试与验证计划

### 6.1 自动化测试

1.  **UI 自动化测试 (XCUITest)**：
    *   `testMiniFullResizeCentering`：切换 Mini 与 Full，记录窗口的 `frame.midX` 和 `frame.midY`，断言切换前后的中心点坐标偏移量在 1 像素以内，确保无位移跳跃。
    *   `testLaunchAndInitialLayout`：测试应用首屏启动时，新的 Empty State 占位图标及引导文案能被正确读取与展示。
    *   `testPRDv07NewSettings`：验证设置页卡片主题切换功能，卡片选中状态的高亮边框与辅助文本变化符合 PRD。

### 6.2 手工验收列表

*   **视觉平滑度测试**：
    *   点击 Mini 展开为 Full，检查背景卡片是否先放大，随后内部控制文字与按钮顺滑淡入，整个过程无生硬跳变与闪烁。
    *   从 Full 折叠回 Mini，检查按钮是否先消失，随后窗口缩回 Mini Pet 尺寸。
*   **卡片绘制测试**：
    *   确认主题选择卡片的四条描边高亮在 Hover 和 Selected 状态下均完整且清晰呈现，无任何裁切与缺失。
*   **素材边缘测试**：
    *   在 Mini 态下检查 Shiba Inu 和 Pixel Slime 播放 yawn、stretch 等动作时，检查画面边缘是否有剪切，身体活动是否顺畅，有无抖动。

---

## 7. 后续版本规划

以下功能不包含在 v0.8 中：
*   **互动音效**：音频播放引擎及 Done 成功轻提示音（AirDrop 风格）延后至 v0.9，且在 v0.9 仅保留 Done 成功音效，不引入 Nom Nom、Hover 等高频噪声音效。
*   **智能电池节能**：自动感知外接电源与低电量降频机制延后至 v0.9 评估，v0.8 保持手动节能开关。
*   **自定义主题导入**：第三方 zip/文件夹的主题解析机制延后至 v1.0。
