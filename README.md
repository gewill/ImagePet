# ImagePet

ImagePet 是一个 macOS 本地图片压缩小工具。MVP 的核心 workflow 是：

1. Drop JPG, PNG, or HEIC images into the window.
2. Choose High, Balanced, or Small JPG quality.
3. Write smaller JPG files to a user-selected output folder.
4. Review per-file status and total saved space.

第一版只做一件事：批量把 `JPG / PNG / HEIC` 压成更小的 `JPG`，并显示每张图和总计节省了多少空间。App 全程本地处理，不上传图片。

## Project Shape

项目现在以提交到仓库的 Xcode project 为主入口：

- `ImagePet.xcodeproj`：日常开发、CI、构建和测试使用的主项目文件。
- `Generated/Info.plist`：`ImagePet.xcodeproj` 引用的 app Info.plist。
- `project.yml`：XcodeGen 配置，作为 AI/脚手架辅助工具保留；不是 CI 必需步骤。
- `Sources/ImagePetCore`：可复用压缩内核，不依赖 SwiftUI/AppKit UI。
- `Sources/ImagePet`：macOS SwiftUI GUI app。
- `Entitlements/ImagePet.entitlements`：App Sandbox 和用户选择文件读写权限。
- `Tests/ImagePetTests`：核心压缩、命名规则、Apple fixture 测试。

Bundle ID 前缀是 `org.gewill`：

- App: `org.gewill.ImagePet`
- Core framework: `org.gewill.ImagePetCore`
- Tests: `org.gewill.ImagePetTests`

`Package.swift` 仍保留，主要用于快速 `swift test` 和保持 Core 的 SwiftPM 可测试性；日常打开 Xcode 和构建 app 时，以提交的 `ImagePet.xcodeproj` 为准。

CI 应直接使用提交的 `ImagePet.xcodeproj`，不需要在每次构建前运行 XcodeGen。只有当需要大幅调整 target、scheme 或 build setting，并且希望借助 XcodeGen 重新生成项目时，才手动运行 `xcodegen generate`，生成后应检查并提交 `.xcodeproj` 的变化。

## Architecture

### ImagePetCore

`ImagePetCore` 是项目里最重要的边界。它负责“图片如何被压缩”，但不负责“用户如何选择文件、如何拖拽、UI 如何显示状态”。

核心类型：

- `CompressionPreset`：`high / balanced / small` 三档质量，对应 `0.9 / 0.8 / 0.65`。
- `ImageJob` 和 `JobStatus`：描述单张图片的输入、输出、大小、状态和错误。
- `CompressionResult`：单张图片压缩后的结果。
- `ImageCompressing`：压缩服务协议，便于 GUI、测试、未来 CLI 复用。
- `ImageCompressor`：当前 ImageIO 实现。
- `OutputNameAllocator`：生成不覆盖原文件的输出文件名。
- `CompressionError`：把常见失败映射成 UI/CLI 可读错误。

`ImageCompressor` 当前做了这些 MVP 决策：

- 支持输入扩展名：`jpg / jpeg / png / heic`。
- 统一输出：`jpg`。
- 输出统一转为标准 sRGB。
- 使用 `CGImageSourceCreateThumbnailAtIndex(... kCGImageSourceCreateThumbnailWithTransform: true ...)` 保留基础方向信息。
- 对解码、转换、编码包裹 `autoreleasepool`，减少批量处理时的临时对象驻留。
- 对 input URL 和 output directory 调用 security-scoped resource access，适配 sandbox GUI 场景。
- 永远不覆盖已有文件。

Core 不知道宠物状态、按钮、拖拽、Open Panel、Finder reveal。这些都属于 GUI 层。

### ImagePet GUI

`Sources/ImagePet` 是 macOS SwiftUI app：

- `ImagePetApp.swift`：app entry point，设置 regular activation policy。
- `ContentView.swift`：主界面，包括宠物状态、拖拽区、任务列表、统计和按钮。
- `ImagePetStore.swift`：GUI 状态和批处理队列。
- `OutputFolderPanel.swift`：用 `NSOpenPanel` 选择输出目录。
- `OutputDirectoryBookmarkStore.swift`：保存和恢复输出目录 security-scoped bookmark。
- `FileSizeFormatting.swift`：UI 展示用的文件大小格式化。

GUI 层负责：

- 拖拽图片进入窗口。
- 首次选择输出目录。
- 保存输出目录 bookmark。
- 最多 2 个任务并发处理。
- 每张图完成后即时更新 UI。
- 管理宠物状态机：`idle / eating / happy / error`。
- 处理 `Reveal in Finder`、`Retry Failed`、`Compress More`。

## Sandbox

App 必须启用 sandbox。当前 entitlements：

```text
com.apple.security.app-sandbox = true
com.apple.security.files.user-selected.read-write = true
```

输入文件来自用户拖拽，输出目录来自用户通过 `NSOpenPanel` 授权选择。GUI 启动后会尝试恢复输出目录 bookmark；如果 bookmark 失效，需要用户重新选择。

## CLI Feasibility

后期可以基于 `ImagePetCore` 做 Command Line 版本，而且这是现在把 Core 和 GUI 分开的主要收益之一。

推荐形态：

```bash
imagepet compress \
  --preset balanced \
  --output /path/to/output \
  /path/to/a.heic /path/to/b.png /path/to/c.jpg
```

CLI 版本可以直接复用：

- `CompressionPreset`
- `ImageCompressor`
- `OutputNameAllocator`
- `CompressionError`
- `CompressionResult`

CLI 不应该复用：

- `ImagePetStore`
- `ContentView`
- `OutputFolderPanel`
- `OutputDirectoryBookmarkStore`

原因是 CLI 不需要 SwiftUI、`NSOpenPanel`、security-scoped bookmark 或宠物状态机。它应该只接收普通文件路径和输出目录路径，然后调用 `ImagePetCore`。

建议未来新增一个 target：

- XcodeGen target: `ImagePetCLI`
- SwiftPM executable product: `imagepet`
- Dependency: `ImagePetCore`
- Argument parsing: 可以用 Swift Argument Parser

CLI 行为建议：

- `--preset high|balanced|small`，默认 `balanced`。
- `--output <directory>` 必填。
- 支持多个输入文件。
- 并发仍限制为 `2`，和 GUI MVP 保持一致。
- 每个文件失败不影响整个批次。
- 输出 per-file 结果和最终总计。
- exit code:
  - `0`：全部成功。
  - `1`：部分或全部文件失败。
  - `2`：参数错误或输出目录不可用。

如果 CLI 是 Developer ID 分发的独立工具，通常不需要 App Sandbox。若未来要走 Mac App Store，则更适合把 CLI 当作 app bundle 内的 helper/tool 另行设计，不建议直接把当前 GUI 的 bookmark 流程硬搬到 CLI。

## Run

```bash
./script/build_and_run.sh
```

The script builds the committed `ImagePet.xcodeproj` with `xcodebuild`, signs
the app with the sandbox entitlements in `Entitlements/ImagePet.entitlements`,
and launches it from project-local `DerivedData`.

## XcodeGen

```bash
xcodegen generate
open ImagePet.xcodeproj
```

XcodeGen is optional. It is useful for bootstrapping or AI-assisted project
rewrites, but the generated `ImagePet.xcodeproj` is committed and should be the
source used by CI.

## Tests

```bash
swift test
xcodebuild -project ImagePet.xcodeproj -scheme ImagePet -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' test
```

如果本地存在 `TestImages/Apple`，`AppleFixtureCompressionTests` 会使用 Apple Newsroom 测试素材跑一遍真实压缩；如果素材不存在，该测试会自动 skip。
