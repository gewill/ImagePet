# ImagePet PRD v0.11: App 完整性、帮助中心与可自定义快捷键

## 1. 版本定位

v0.9 和 v0.10 已经把 ImagePet 的核心压缩能力从基础 ImageIO workflow 推进到：

- WebP 输入/输出与自定义质量。
- Advanced JPEG / mozjpeg。
- 更完整的保存位置、覆盖保护、尺寸限制、元数据剥离和桌面 Pet 常驻体验。

v0.11 不继续扩大图片格式范围。它的目标是补齐一个可发布 macOS app 应有的完整性：

```text
用户第一次打开能知道怎么用，遇到权限/覆盖/格式疑问能离线自助，常驻桌面 Pet 用户能按自己的习惯唤起关键动作。
```

v0.11 的产品承诺是：

```text
ImagePet becomes easier to discover, control, and troubleshoot without expanding the compression surface.
```

## 2. 当前基线

截至 2026-06-15，仓库当前实现状态如下：

- `ImagePetApp.swift` 已有 SwiftUI `WindowGroup("ImagePet")`、`Window(id: "main")`、共享 `ImagePetStore`、AppDelegate reopen 处理和固定菜单命令。
- 当前固定快捷键包括：
  - `⌘1`: Show Main Window
  - `⌘O`: Add Images
  - `⇧⌘O`: Choose Output Folder
  - `⇧⌘P`: Show / Hide Desktop Pet
  - `⌘N`: Compress More
  - `⌘R`: Retry Failed，仅在失败状态按钮上出现
- 主窗口 `TabView` 目前只有 `Compress` 与 `Settings` 两页；`Settings` 实际是 `DesktopPetSettingsView`，偏桌面 Pet 配置。
- 目前没有独立 Help 页面、Help 菜单入口、帮助窗口、帮助文档资源或帮助验收清单。
- `Package.swift` / `project.yml` 已包含 `Swift-WebP` 与 `mozjpeg.swift`，但没有 `KeyboardShortcuts`。
- `Generated/Info.plist` 没有 Apple Help Book metadata，也没有 `NSServices`、Finder Extension 或 Shortcuts 入口。

因此 v0.11 必须先处理可发现性、帮助、自定义控制和菜单一致性，而不是继续新增压缩参数。

## 3. 最终范围

### P0

- 新增离线 Help Center。
- 新增 Help 菜单入口，并可从设置页进入。
- 新增可自定义全局快捷键设置，基于 `sindresorhus/KeyboardShortcuts` 先做 dependency spike。
- 保留现有 in-app 固定快捷键；全局快捷键默认不预设，由用户主动录制。
- 整理菜单命令分组和 disabled 规则。
- 拆分设置页结构，让 Desktop Pet、Keyboard Shortcuts、Help/About 信息有明确位置。
- 更新 Third Party Notices，覆盖 `KeyboardShortcuts` MIT license。
- 补充自动化测试和手工验收清单。

### P1 / v0.11.x

- Help Center 搜索。
- Help 内容多语言。
- Reset All Shortcuts。
- Copy Diagnostics / Support Summary。
- About 面板显示 dependency versions、bundle version、sandbox status、notarization hints。
- 全局 `Add Images` 快捷键，前提是交互不会在后台突然弹出文件选择器。

### v1.0+

- Apple Help Book 深度集成。
- Apple Shortcuts / Automator wrapper。
- Finder Extension。
- Raycast Extension。
- CLI target。
- 文件夹监听。
- 用户自定义工作流或批处理模板。

## 4. 非目标

v0.11 明确不做：

- 不新增 AVIF、JPEG XL、GIF、PDF、TIFF。
- 不新增任何压缩算法或高级 codec 参数。
- 不做 Apple Shortcuts app 动作。
- 不做 Finder Extension / Raycast Extension。
- 不做文件夹监听。
- 不做云帮助中心、远程文档、账号、反馈上传或遥测。
- 不做营销式 onboarding hero。
- 不允许全局快捷键直接执行破坏性动作，例如覆盖原图确认、删除队列、开始覆盖写入。
- 不允许全局快捷键绕过输出目录授权、security-scoped bookmark 或 overwrite confirmation。

## 5. KeyboardShortcuts 依赖评估

### 5.1 外部快照

截至 2026-06-15，`sindresorhus/KeyboardShortcuts` 的上游信息：

- Upstream: https://github.com/sindresorhus/KeyboardShortcuts
- GitHub README 定位为给 macOS app 添加用户可自定义 global keyboard shortcuts。
- README 声明 sandbox 与 Mac App Store compatible。
- Requirements 为 macOS 10.15+；ImagePet 最低 macOS 13，版本兼容。
- GitHub 页面显示当前 Version 为 `3.0.0`，latest release 为 `3.0.0`，发布时间为 2026-06-14。
- SwiftUI 使用方式是 `KeyboardShortcuts.Recorder(...)`。
- `Recorder` 会把 shortcut 存在 `UserDefaults`，并在用户选择系统或主菜单已占用快捷键时给出警告。
- README FAQ 声明不会触发额外 permission dialogs。
- License 为 MIT。

该快照只用于 v0.11 PRD 评估。实现前必须重新确认版本、release notes、license 和 SwiftPM 解析结果。

### 5.2 采用原则

ImagePet 可以采用 `KeyboardShortcuts`，但只放在 GUI target：

```text
ImagePet target -> KeyboardShortcuts
ImagePetCore   -> no dependency on KeyboardShortcuts
```

理由：

- `ImagePetCore` 只负责压缩行为，不应知道 AppKit/SwiftUI 全局快捷键。
- 全局快捷键是 app interaction，不是 compression core。
- 未来 CLI target 不应该被 GUI 快捷键依赖污染。

依赖接入应遵循本仓库现有策略：

- `Package.swift` 增加 exact version。
- `project.yml` 增加 SwiftPM package。
- 如使用 XcodeGen，运行 `xcodegen generate` 后审查并提交 `ImagePet.xcodeproj` diff。
- 更新 `Package.resolved` 和 `ImagePet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`。
- 更新 `docs/THIRD_PARTY_NOTICES.md`。

### 5.3 默认快捷键策略

P0 不设置任何 initial global shortcut。

原因：

- 全局快捷键会跨 app 生效，默认抢占用户系统快捷键风险高。
- 上游 README 也建议公开发布 app 避免设置 initial shortcut，更倾向在欢迎或设置界面让用户主动配置。
- ImagePet 已有 in-app fixed menu shortcuts，首次使用不依赖全局热键。

P0 只提供 Recorder：

```text
Global Shortcuts
- Show Main Window: unset by default
- Toggle Desktop Pet: unset by default
- Toggle Pet Mini / Full: unset by default
```

P1 再评估：

```text
- Add Images: unset by default
```

`Add Images` 作为全局快捷键需要谨慎，因为它可能在 app 后台时弹出 `NSOpenPanel`，这对用户有打扰。

### 5.4 技术形状

新增 GUI-only shortcut coordinator：

```text
Sources/ImagePet/Services/GlobalShortcutCoordinator.swift
```

职责：

- 定义 `KeyboardShortcuts.Name`。
- 注册 `onKeyUp` handler。
- 在 `@MainActor` 上调用 `ImagePetStore` 的现有入口。
- 不持有压缩核心。
- 不执行任何破坏性动作。

建议快捷键 names：

```swift
extension KeyboardShortcuts.Name {
    static let showMainWindow = Self("showMainWindow")
    static let toggleDesktopPet = Self("toggleDesktopPet")
    static let togglePetMode = Self("togglePetMode")
}
```

`togglePetMode` 只在桌面 Pet 可见时切换 Mini / Full；如果 Pet 不可见，则显示 Pet 并保持 Mini。

handler 规则：

- `showMainWindow`: 调用 `store.activateMainWindow()`。
- `toggleDesktopPet`: 调用 `store.toggleDesktopPet()`。
- `togglePetMode`: 调用安全的 `store` 方法，不直接操作 `DesktopPetWindowController`。
- 所有 handler 必须尊重 `isDesktopPetEnabled`、`isProcessing`、`showOverwriteConfirmation` 等现有状态。

## 6. Help Center 产品要求

### 6.1 内容结构

P0 Help Center 必须是离线、本地、无需网络的帮助页面。

首版内容：

1. Quick Start
   - Add Images / drag images。
   - Choose Output Folder。
   - Pick output format and quality。
   - Reveal in Finder。
2. Formats and Quality
   - 支持的输入格式。
   - 支持的输出格式。
   - Original / JPEG / PNG / HEIC / WebP 的差异。
   - Advanced JPEG 只影响 JPEG 输出。
3. Save Locations and Permissions
   - Designated Folder。
   - Original Folder。
   - Overwrite Original。
   - sandbox 授权、bookmark 失效后的恢复方式。
4. Overwrite Original Safety
   - 覆盖模式会二次确认。
   - 覆盖模式保持每个文件原始格式。
   - 取消后不会继续写入。
5. Desktop Pet
   - Show / Hide。
   - Mini / Full。
   - Launch at Login。
   - 能耗设置、主题设置、成功音效。
6. Keyboard Shortcuts
   - 固定 in-app shortcuts。
   - 用户配置的 global shortcuts。
   - 如何清除或改录。
7. Troubleshooting
   - Unsupported image format。
   - Permission denied。
   - Output folder unavailable。
   - Failed to decode image。
   - Failed to write output file。
   - Not enough disk space。
8. Privacy
   - 图片本地处理。
   - 不上传图片。
   - 不引入遥测。

### 6.2 实现形状

P0 首选：

```text
Window("ImagePet Help", id: "help") -> HelpView
```

`HelpView` 使用原生 SwiftUI：

- 左侧 topic list。
- 右侧 topic content。
- 支持 VoiceOver。
- 支持键盘导航。
- 不使用远程 WebView。
- 不依赖外部网站。

内容可用结构化 Swift 数据维护：

```text
HelpTopic(id, title, systemImage, bodyBlocks)
```

首版不引入 Markdown renderer，避免为帮助页再引入一条渲染依赖。后续如果内容明显变大，再评估本地 Markdown。

### 6.3 Help 入口

必须有这些入口：

- App Help 菜单：`ImagePet Help`。
- Settings 页面：`Open Help`。
- 权限或输出目录失败状态：可以提供 `Help` 按钮或 context help，但 P0 可先只保证 Help menu 可达。
- Desktop Pet Full 态不放完整帮助入口，避免小窗承担复杂说明；只保留返回主 app 的路径。

## 7. 菜单与设置整理

### 7.1 菜单结构

v0.11 应把现有命令整理成更像 macOS app 的结构：

```text
File
- Add Images...              ⌘O
- Choose Output Folder...    ⇧⌘O
- Compress More              ⌘N
- Retry Failed               ⌘R, only enabled when failed jobs exist

View
- Show Main Window           ⌘1
- Show Desktop Pet / Hide Desktop Pet
- Toggle Pet Mini / Full     no fixed shortcut unless implemented safely

Help
- ImagePet Help              standard Help shortcut if feasible
- Keyboard Shortcuts...
```

保留现有 `⌘O`、`⇧⌘O`、`⇧⌘P`、`⌘N` 和 `⌘R` 行为，除非发现与 macOS 菜单冲突或实现冲突。

### 7.2 设置页面结构

当前 `Settings` tab 只承载 Desktop Pet。v0.11 应重组为：

```text
Settings
- General
  - Output defaults summary
  - Reset warnings / restore prompts, if needed
- Desktop Pet
  - Enabled
  - Theme
  - Launch at Login
  - Idle variants / hover / success sound / energy saving
- Keyboard Shortcuts
  - Show Main Window Recorder
  - Toggle Desktop Pet Recorder
  - Toggle Pet Mini / Full Recorder
  - Clear / change guidance
- Help & About
  - Open Help
  - Version / build
  - Third-party notices link
```

如果实现成本较低，可以新增 SwiftUI `Settings` scene 作为 native settings window，并用 `⌘,` 打开。否则 P0 可以继续沿用主窗口 `Settings` tab，但必须确保 `⌘,` 或菜单命令能聚焦到该 tab。

## 8. 数据、隐私与安全

### 8.1 UserDefaults namespace

KeyboardShortcuts 自身会保存 shortcut。ImagePet 额外设置必须继续使用清晰 namespace：

```text
ImagePet.shortcuts.hasSeenIntro
ImagePet.shortcuts.lastOpenedSettingsSection
```

不要复用 compression 或 desktop-pet 的旧 key。

### 8.2 Sandbox

v0.11 不新增文件系统 entitlements。

必须保持：

```text
com.apple.security.app-sandbox = true
com.apple.security.files.user-selected.read-write = true
```

全局快捷键不得改变 sandbox 权限模型：

- 不绕过 `NSOpenPanel`。
- 不默认写入用户目录。
- 不自动授权 Original Folder。
- 不绕过 Overwrite confirmation。

### 8.3 Privacy

Help 和 Shortcuts 不引入网络访问。

不采集：

- 图片路径。
- 快捷键设置。
- 错误日志。
- 用户环境信息。

P1 如果做 Copy Diagnostics，也必须是用户主动点击、复制到剪贴板，不自动上传。

## 9. 可访问性与本地化

P0 要求：

- Help topic list 和正文可被 VoiceOver 顺序朗读。
- Recorder label 必须明确动作名称，例如 `Show Main Window`、`Toggle Desktop Pet`。
- Shortcuts 设置页要说明全局快捷键默认未设置。
- 文本在 `780x560` 最小窗口内不截断关键内容。
- Help window 支持滚动，不通过缩小字体解决拥挤。
- 所有新增按钮设置 `accessibilityIdentifier`，方便 XCUITest。

本地化策略：

- P0 保持当前 app 主要 UI 语言一致，先用英文界面文案。
- PRD 和内部文档继续中文。
- P1 再评估帮助内容多语言。

## 10. 测试与验收

### 10.1 自动化测试

Unit tests：

- `GlobalShortcutCoordinatorTests` 或等价测试覆盖 shortcut name 集合与 reset 行为。
- 确认默认 global shortcut 为空，避免公开发布时抢占用户快捷键。
- 确认 shortcut handlers 调用 store-level 方法，而不是直接操作窗口 controller。

UI tests：

- `testHelpMenuOpensHelpWindow`
- `testHelpWindowShowsCoreTopics`
- `testSettingsShowsKeyboardShortcutsSection`
- `testGlobalShortcutsAreUnsetByDefault`
- `testExistingMenuShortcutsStillWork`
- `testHelpAndSettingsTextDoesNotClipAtMinimumWindowSize`

Dependency / project tests：

- `swift package resolve`
- `swift test`
- `xcodebuild -project ImagePet.xcodeproj -scheme ImagePet -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' test`
- `./script/build_and_run.sh --verify`
- `git diff --check`

### 10.2 手工验收

KeyboardShortcuts：

- 打开 Settings -> Keyboard Shortcuts。
- 录制 Show Main Window 快捷键。
- app 在后台时触发快捷键，主窗口回到前台。
- 录制 Toggle Desktop Pet 快捷键。
- app 在后台时触发快捷键，Pet 显示/隐藏且不打断当前压缩。
- 尝试录制系统已占用或菜单已占用快捷键，确认有冲突提示。
- 重启 app 后快捷键仍然存在。
- 清除快捷键后不再触发。

Help：

- 从 Help 菜单打开 Help Center。
- 从 Settings 页打开 Help Center。
- 阅读 Save Locations and Permissions，确认与当前 sandbox 行为一致。
- 阅读 Overwrite Original Safety，确认没有承诺可撤销覆盖。
- 阅读 Formats and Quality，确认与当前 `OutputFormat` / `EncoderCapabilities` 一致。

Regression：

- `⌘O` 仍打开 Add Images。
- `⇧⌘O` 仍打开 Choose Output Folder。
- `⇧⌘P` 仍切换 Desktop Pet。
- `⌘N` 在非处理状态可 Compress More。
- `⌘R` 只在失败状态可 Retry Failed。
- 覆盖模式确认弹窗不受任何 global shortcut 绕过。

## 11. 验收标准

v0.11 可以标记为完成，当且仅当：

- Help Center 可从菜单和设置页打开。
- Help Center 内容覆盖 Quick Start、格式、保存位置、覆盖保护、Desktop Pet、快捷键、错误排查和隐私。
- Settings 有明确的 Keyboard Shortcuts 区域。
- `KeyboardShortcuts` dependency 只接入 GUI target。
- 所有 global shortcuts 默认 unset。
- 用户能配置并持久化至少 `Show Main Window` 与 `Toggle Desktop Pet`。
- 现有 fixed in-app shortcuts 继续工作。
- Third Party Notices 覆盖新增依赖。
- `swift test`、完整 `xcodebuild ... test`、`./script/build_and_run.sh --verify` 和 `git diff --check` 通过。
- App Sandbox entitlements 未扩大。

## 12. 分阶段计划

### Phase 0: Dependency Spike

- 引入 `KeyboardShortcuts` exact version。
- 验证 SwiftPM resolve、Xcode build、sandbox Debug run。
- 验证 no permission dialog。
- 验证 Recorder 在 Settings 中可显示。
- 更新 Third Party Notices。

决策结果：

```text
A. 依赖可发布：进入 Phase 1/2。
B. 依赖风险过高：保留 Help/Menu/Settings 整理，不发布 global customizable shortcuts。
```

### Phase 1: Help 与菜单

- 新增 Help window / HelpView。
- 新增 Help menu command。
- 新增 Settings -> Help & About。
- 整理 File / View / Help 命令分组。
- 补 UI tests。

### Phase 2: Global Shortcuts

- 新增 `GlobalShortcutCoordinator`。
- 新增 Settings -> Keyboard Shortcuts recorders。
- 接入 `Show Main Window`、`Toggle Desktop Pet`、`Toggle Pet Mini / Full`。
- 补默认 unset、持久化、触发和重启手工验收。

### Phase 3: Release Polish

- Help 文案与 README / MANUAL_ACCEPTANCE 对齐。
- Third Party Notices 检查。
- 最小窗口、VoiceOver、Light/Dark 手工检查。
- Developer ID signing / notarization smoke 如进入发布候选。

## 13. 风险与决策门

### 风险 1：全局快捷键抢占用户习惯

缓解：

- 默认不设置。
- 用户主动录制。
- 设置页解释全局快捷键会在 ImagePet 后台时生效。

### 风险 2：后台打开文件选择器打扰用户

缓解：

- P0 不提供 global Add Images。
- 只允许 Show Main Window、Toggle Desktop Pet、Toggle Pet Mode。

### 风险 3：设置页过度膨胀

缓解：

- 按 General / Desktop Pet / Keyboard Shortcuts / Help & About 分组。
- 不把 Help 正文塞进设置页，只提供入口。

### 风险 4：Help 内容与实现漂移

缓解：

- Help 内容验收必须对照 live code。
- 更新格式、保存位置或错误文案时，把 Help 当作用户可见文档同步更新。

### 风险 5：依赖引入影响发布

缓解：

- Phase 0 单独决策。
- 如果 `KeyboardShortcuts` 造成 Xcode project、sandbox、codesign 或 notarization 风险，v0.11 仍可发布 Help/Menu/Settings 整理，global shortcuts 延后。

## 14. 开放问题

1. v0.11 是否要同时引入 native SwiftUI `Settings` scene，还是继续使用主窗口 `Settings` tab？
2. `Toggle Pet Mini / Full` 是否应该是 P0，还是只做 `Show Main Window` 与 `Toggle Desktop Pet`？
3. Help P0 是否只做英文 UI，还是同步增加中文帮助内容？
4. 是否需要在首次启动后提示用户可以配置 global shortcuts？默认建议不弹窗，只在 Settings 和 Help 中说明。
5. `Keyboard Shortcuts...` 菜单项应打开 Settings 的 Shortcuts section，还是独立小窗口？
