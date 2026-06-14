# ImagePet PRD v0.9: WebP 与自定义压缩质量

## 1. 版本定位

ImagePet 当前已经从早期 MVP 的“统一输出 JPG”扩展为本地图片压缩工具：

- 输入：`JPG / JPEG / PNG / HEIC`
- 输出：`Original / JPEG / PNG / HEIC`
- 已支持质量预设、最大边长限制、元数据剥离、原目录保存、指定目录保存和覆盖原图保护
- `ImagePetCore` 负责压缩行为，GUI 负责拖拽、授权、队列、宠物状态和窗口交互

v0.9 的核心价值收窄为：

```text
ImagePet 正式支持 Web 发布格式 WebP，并给用户可控的质量滑杆。
```

v0.9 不做一次 codec 基础设施大迁移。Advanced JPEG、mozjpeg、完整第三方 notices 体系和复杂外部 codec 分发都移出 v0.9 首发。

---

## 2. 最终范围

### P0

- WebP 静态输入/输出。
- Custom Quality。
- Native ImageIO capability probe。
- Native ImageIO engine + EncoderCapabilities。
- WebP alpha 保留。
- 多帧 WebP 拒绝。
- Overwrite 禁止格式转换。
- 输出变大 => skipped。
- UI capability gate。

### P1 / v0.9.x

- libwebp fallback。
- WebP lossless spike。
- benchmark fixtures。

### v1.0

- Advanced JPEG。
- mozjpeg。
- Third Party Notices 完整体系。

---

## 3. 非目标

v0.9 明确不做：

- AVIF、JPEG XL、GIF 输出或 PDF 压缩。
- 动画 WebP、动画 GIF 转 WebP 或多帧图片编辑。
- WebP Lossless toggle。
- Advanced JPEG、mozjpeg、libjpeg-turbo 或 JPEG 无损二次优化。
- SVG、TIFF 输入/输出。
- 精确目标文件大小，例如“压到 500 KB 以下”。
- 用户自定义外部可执行文件路径，例如 Homebrew 的 `cwebp`、`dwebp`、`jpegtran`。
- 运行时下载 codec、插件或动态库。
- 在 Overwrite Original 模式下把源文件转换为另一种格式。
- 允许用户输出比输入更大的文件。

---

## 4. Phase 0 Spike 与决策门

v0.9 不应在实现阶段才决定 native WebP 是否足够。必须先完成一个短 spike，并把结果写回 PRD 或进度文档。

### 4.1 Spike 范围

优先在当前支持范围内可获得的系统环境上实测 ImageIO WebP 能力。目标矩阵是：

- macOS 13。
- macOS 14。
- macOS 15。
- macOS 26，若本机或 CI 环境可用。

已知风险：

- macOS 13 的 ImageIO WebP write 能力可能不稳定或不可用，spike 结果必须单独标注 `read` / `write` / `alpha` / `preview-open`，不能把 macOS 14+ 的结果外推到 macOS 13。
- 如果最低支持系统仍包含 macOS 13，但 macOS 13 无法验证或 WebP write 不达标，v0.9 仍可通过 capability gate 隐藏 WebP 输出；发布说明必须把该系统版本标为 `not verified` 或 `write unavailable`。

现实约束：

- 独立开发者通常无法一次性覆盖全部系统版本。
- v0.9 的发布阻断项是“当前开发机 + 可获得 CI / 虚拟机 / 用户验证环境”的实测结果。
- 无法获得的系统版本必须在 spike 记录中标注为 `not verified`，并作为后续兼容性验证缺口，而不是伪造通过。

实测项：

- `CGImageSourceCopyTypeIdentifiers()` 是否包含 WebP 读能力。
- `CGImageDestinationCopyTypeIdentifiers()` 是否包含 WebP 写能力。
- 读能力和写能力必须分别记录，不能合并为一个 WebP available 布尔值。
- JPG/PNG/HEIC -> WebP 是否可写出。
- WebP -> Original 是否可写出。
- PNG alpha -> WebP 是否保留透明通道。
- 静态 WebP 是否能被 Preview、Safari、Chrome 打开。
- 多帧 WebP 是否能被稳定检测并拒绝。

Spike 记录模板至少包含：

```text
macOS version:
hardware / runner:
ImageIO WebP read: yes/no/not verified
ImageIO WebP write: yes/no/not verified
alpha: pass/fail/not verified
multi-frame rejection: pass/fail/not verified
Preview open: pass/fail/not verified
Safari open: pass/fail/not verified
Chrome open: pass/fail/not verified
notes:
```

### 4.2 决策结果

Spike 后只能进入以下两种方案之一：

#### 方案 A: Native WebP 足够

v0.9 首发只使用 ImageIO：

- 实现 `NativeImageIOEncodingEngine`。
- 不引入 libwebp。
- 不新增第三方二进制、license notices 或 codesign 复杂度。

#### 方案 B: Native WebP 不足

v0.9 首发不直接承诺 libwebp。可选路径：

- 将 libwebp fallback 移入 v0.9.x。
- 或明确扩展 v0.9 范围，并重新评审签名、notarization、license、Universal binary 和安全更新策略。

在没有完成方案 B 的重新评审前，v0.9 不应同时承诺 native 和 libwebp。

---

## 5. WebP 静态输入/输出

### 5.1 支持能力

- `SupportedImageFormat` 增加 `webp`，但由 WebP read capability 决定是否接受 `.webp` 输入。
- `OutputFormat` 增加 `webp`，但只在 WebP write capability 可用时显示。
- WebP read capability 和 write capability 是两个独立维度。
- 如果 WebP 可读但不可写：
  - `.webp` 可以导入。
  - `Output Format` 不显示 WebP。
  - 用户仍可把 WebP 转为 JPEG / PNG / HEIC。
  - WebP 输入在 `Original` 输出模式下无法完成原格式写出，应显示明确结果原因：`Skipped: WebP output is unavailable on this Mac`。
- 如果 WebP 可写但不可读：
  - `Output Format` 可以显示 WebP。
  - `.webp` 输入仍应被拒绝为 unsupported。
- 非覆盖模式下，用户可以选择输出为 `.webp`。
- `Original` 输出模式下：
  - 静态 WebP 输入只有在 WebP write capability 可用时才输出 WebP。
  - JPG/PNG/HEIC 输入仍按各自原格式输出。
- WebP 输出为 lossy WebP with alpha support。
- PNG/WebP 输入包含 alpha 时，WebP 输出必须保留 alpha。
- JPEG 输出继续按现有规则扁平化为标准 sRGB。

### 5.2 多帧 WebP 拒绝

v0.9 只支持静态 WebP。

Native ImageIO 路径的检测口径：

```swift
CGImageSourceGetCount(source) > 1
```

严格说，多帧不一定等于动画。v0.9 的产品口径是：所有多帧图片均视为 unsupported。

如果 `CGImageSourceGetCount(source) > 1`，按多帧 WebP 处理，拒绝并显示：

```text
Unsupported image format
```

如果未来 v0.9.x 引入 libwebp，必须提供等价的多帧 WebP 检测，不能只依赖文件后缀。

已知限制：

- `CGImageSourceGetCount(source) > 1` 是 v0.9 的最小检测标准，不保证覆盖所有损坏或异常编码的动画 WebP。
- 如果损坏动画 WebP 被 ImageIO 只解出第一帧并返回 count = 1，v0.9 可能把它当作静态图处理；这种 case 需要在 v0.9.x 用 WebP 容器级检测补齐，例如检查 VP8X/ANIM 标志或 ImageIO 暴露的 WebP 动画属性。
- v0.9 的测试必须覆盖正常多帧 WebP 拒绝；损坏动画 WebP 作为 v0.9.x 安全强化项跟踪。

### 5.3 WebP -> Original 的 skipped 策略

WebP 输入选择 `Original` 时仍会重新编码为 WebP。

如果输出文件大于输入文件：

```text
Skipped: output would be larger than source
```

该策略适用于所有格式，不只适用于 WebP。v0.9 不提供“允许输出更大文件”的开关。

实现上可以继续使用 `JobStatus.skipped`，但 UI 必须展示专门的 result reason，不能只显示泛化的 skipped，否则用户会误以为程序没有执行。

---

## 6. Custom Quality

当前三档预设继续保留：

| Preset | Quality |
| --- | ---: |
| High | 0.90 |
| Balanced | 0.80 |
| Small | 0.65 |

v0.9 新增 `Custom` 模式：

- UI 形态：Preset segmented control 增加 `Custom`，下方出现 Quality slider。
- Slider 范围：`30...95`。
- 默认值：`80`，等价于 Balanced。
- 步进：`1`。
- 显示：`Quality 80`。
- 处理中禁用修改，与现有格式、路径、尺寸选项保持一致。
- 持久化到 `UserDefaults`。

适用范围：

- JPEG：映射到 JPEG encoder quality。
- HEIC：映射到 HEIC encoder quality。
- WebP：映射到 WebP lossy quality。
- PNG：不适用。

Core 传参规则：

- `CompressionOptions.lossyQuality` 是可选值。
- JPEG / HEIC / WebP 输出必须传入 `.preset(...)` 或 `.custom(...)`。
- PNG 输出必须传入 `nil`，由 `ImagePetStore` 或 `ImageCompressor` 构建 options 时清洗。
- `NativeImageIOEncodingEngine` 对 PNG 路径必须防御式忽略非 nil `lossyQuality`，不得因为 UI 或调用方错误传入 custom quality 而崩溃。

PNG 模式下不要只把控件置灰，必须显示解释文案：

```text
PNG uses lossless compression. Quality does not apply.
```

WebP Lossless 不进入 v0.9。透明 PNG 输出 WebP 时，v0.9 只支持 lossy WebP with alpha support。

---

## 7. 保存策略与安全边界

### 7.1 SaveOptions 与 CompressionOptions 拆分

v0.9 需要避免把 UI 状态全部塞进 encoder options。

建议拆分：

```swift
public struct CompressionOptions: Sendable, Equatable, Codable {
    public let lossyQuality: CompressionQuality?
    public let format: OutputFormat
    public let maxDimension: MaxDimensionLimit
    public let stripMetadata: Bool
}

public struct SaveOptions: Sendable, Equatable, Codable {
    public let locationMode: SaveLocationMode
    public let suffix: String
    public let overwritePolicy: OverwritePolicy
}
```

`locationMode`、`suffix` 和覆盖策略属于保存行为，不属于 encoder 行为。

持久化边界：

- v0.9 的压缩设置 key 继续使用 `ImagePet.outputFormat`、`ImagePet.preset` 等 compression namespace。
- 不与桌面 Pet / theme 的配置 key 混用。
- 如果未来引入统一 app settings 文件，压缩设置、保存策略和 Pet/theme 设置必须分 namespace，避免与早期 Pet 动画配置发生 key 冲突。

迁移策略：

- 这是一次 `ImagePetCore` API 重构，必须在同一个 PR 中同步更新所有调用方、测试和 Xcode project 引用。
- 不保留旧的合并 options 兼容层，避免 GUI 保存状态继续污染 encoding options。
- Commit message 使用 Conventional Commits 的破坏性标记，例如 `refactor(core)!: split compression and save options`。

### 7.2 Overwrite Original

Overwrite Original 是破坏性操作，v0.9 继续保持安全底线：

- Overwrite 模式强制 `OutputFormat.original`。
- 不允许 JPG/PNG/HEIC 覆盖成 WebP。
- 不允许 WebP 覆盖成 JPEG/PNG/HEIC。
- 覆盖前仍必须二次确认。
- 仍必须写入临时文件，成功后再替换原文件。

Overwrite Original = 只允许原格式重写。

---

## 8. Native ImageIO Engine 与 Capabilities

### 8.1 为什么需要

WebP P0 需要 capability gate 和 Native ImageIO probe。v0.9 首发不引入 libwebp，因此不需要完整的多 encoder protocol 或 composite engine。

v0.9 只需要：

- `EncoderCapabilities`，表达 ImageIO 当前可读、可写和 alpha 能力。
- `NativeImageIOEncodingEngine`，封装 ImageIO 写出行为。

等 v0.9.x 真的引入 libwebp 时，再抽通用 `ImageEncodingEngine` protocol 和 composite routing。

### 8.2 建议接口

```swift
public struct EncoderCapabilities: Sendable, Equatable {
    public let readableFormats: Set<SupportedImageFormat>
    public let writableFormats: Set<OutputFormat>
    public let supportsCustomQuality: Bool
    public let alphaCapableFormats: Set<OutputFormat>
}

public struct NativeImageIOEncodingEngine: Sendable {
    public let capabilities: EncoderCapabilities

    func encode(
        image: CGImage,
        source: ImageSourceMetadata,
        destinationTemporaryURL: URL,
        options: CompressionOptions
    ) throws
}
```

`alphaCapableFormats` 必须是 per-format 能力集合，而不是 engine 级布尔值。JPEG 永远不应出现在该集合中；PNG 通常应出现；WebP 只有在 native path 通过透明度 spike 后才出现。

`NativeImageIOEncodingEngine` 使用 `struct` 和不可变 `capabilities`。`encode()` 必须只使用局部 ImageIO/CG 对象，不保存跨 job 的可变状态，因此同一个值可以在 `maxConcurrentJobs = 2` 下并发调用。不要使用 `@unchecked Sendable`，除非后续实现引入内部缓存并补充锁保护说明。

命名必须使用 `destinationTemporaryURL`，明确 encoder 只能写 compressor 提供的临时目标。

### 8.3 边界

`ImageCompressor` 继续负责：

- security-scoped resource access。
- 输出目录解析。
- output filename allocation。
- overwrite confirmation 之后的事务性替换。
- decode、orientation、resize、sRGB flatten。
- 输出变大时删除临时文件并返回 skipped。
- `encode()` 抛错时清理 `destinationTemporaryURL`，不允许在输出目录或临时目录残留部分写入文件。
- per-file error mapping。

Encoder 只负责：

- 把标准化后的 `CGImage` 写入 `destinationTemporaryURL`。
- 使用 `CompressionOptions` 中的格式、质量和 metadata 策略。

Encoder 不能：

- 自行决定最终文件名。
- 自行决定保存目录。
- 自行覆盖原文件。
- 自行绕过 skipped 策略。
- 自行请求 sandbox 权限。

临时文件生命周期：

- `ImageCompressor` 创建并拥有 `destinationTemporaryURL`。
- Encoder 可以直接写入该 URL，但不能 rename、move 或 replace 最终文件。
- 无论 encoder 成功、抛错、输出变大 skipped，`ImageCompressor` 都负责清理临时文件。

---

## 9. Capability Gate

UI 不应展示运行时不可用的格式或选项。

规则：

- 如果 WebP write 不可用，`OutputFormat.webp` 不显示。
- 如果 WebP read 不可用，`.webp` 文件拖入后显示 `Unsupported image format`。
- 如果 WebP read 可用但 write 不可用，`.webp` 仍可导入并转换为其他可写格式。
- 如果已保存的输出偏好指向不可写的 WebP，启动时在内存中回退到 `Original` 或当前第一个可写格式，不能崩溃。
- 如果 `Original` 模式遇到“源格式可读但不可写”的 WebP 输入，该 job 显示：`Skipped: WebP output is unavailable on this Mac`。
- 单元测试必须能注入 mock capabilities，避免 UI 测试依赖本机 codec 状态。

UserDefaults 语义：

- Capability 回退只影响本次运行的 effective output format。
- 不要因为 capability 不可用就把用户保存的 `webp` 偏好写回为 `original`。
- 只有用户在 UI 中主动选择了新的输出格式，才更新 `UserDefaults`。
- 这样用户升级 macOS 或换到支持 WebP write 的机器后，原本保存的 WebP 偏好可以自动恢复生效。

---

## 10. UI 要求

### 10.1 Compress 页面控制区

```text
Quality
[ High | Balanced | Small | Custom ]

Custom Quality: 80
[--------------------o---------]

Output Format
[ Original | JPEG | PNG | HEIC | WebP ]
```

显示规则：

- `Custom Quality` 只在选择 Custom 时出现。
- `PNG` 模式显示：`PNG uses lossless compression. Quality does not apply.`
- `WebP` 模式显示：`Best for web sharing. Static images only.`
- `Overwrite Original` 下格式选择器继续禁用，并显示原有红色警告。
- 不显示 Advanced JPEG、Further Compress JPEG、WebP Lossless 等 v0.9 非目标控件。

Slider 持久化：

- 拖动时可以实时更新屏幕上的 `Custom Quality: NN` 和内存状态。
- `UserDefaults` 写入应在拖动结束时提交，或使用短 debounce，避免每个 slider tick 都触发持久化写入。

### 10.2 文件列表与结果

- 输出路径仍为主要证据。
- WebP job 可在辅助文本或 tooltip 显示 `WebP`。
- 不在主列表里展示复杂 encoder 名称，v0.9 不把压缩工具变成 codec 调参面板。

---

## 11. 沙盒、安全与分发

v0.9 不改变现有 entitlements：

```text
com.apple.security.app-sandbox = true
com.apple.security.files.user-selected.read-write = true
```

安全要求：

- 不新增网络权限。
- 不调用用户系统 PATH 上的外部命令。
- 不运行时下载 codec。
- 保留 `maxConcurrentJobs = 2`。
- Decode/encode 继续包裹 `autoreleasepool`。
- 输出仍遵守“成功才替换/成功才展示”的原则。
- 任何格式输出大于输入时默认 skipped。

如果 v0.9.x 引入 libwebp，必须重新补齐：

- 固定版本。
- Universal macOS binary。
- codesign、Hardened Runtime、notarization。
- license notices。
- 安全更新策略。

---

## 12. 性能预算

基准素材：

- 20 张 12MP iPhone HEIC/JPEG 混合照片。
- 透明 PNG/WebP fixture 至少包含：
  - 100% 透明区域。
  - 50% 半透明区域。
- 5 张已经高度压缩的小 JPEG。
- 2 张损坏图片。
- 2 张不支持或多帧 WebP。

通过标准：

| 路径 | 预算 |
| --- | --- |
| Native JPEG Balanced | 不回退现有性能目标 |
| WebP lossy Balanced | 与同一批 20 张 12MP HEIC/JPEG fixture 的 Native JPEG Balanced 批量 wall-clock 对比，不超过 2.5x；在 Apple Silicon 开发机上硬上限 60 秒 |
| 批量内存峰值 | 低于 1.5 GB，目标低于 512 MB |
| 单文件失败 | 不中断批次 |

---

## 13. 测试与验收

### 13.1 单元测试

必须新增或更新：

- `SupportedImageFormatTests`
  - WebP read capability 可用时接受 `.webp`。
  - WebP read capability 不可用时拒绝 `.webp`。
  - WebP write capability 不影响 `.webp` 输入接受结果。
  - GIF/PDF/SVG/TIFF 继续拒绝。
- `CompressionPresetTests`
  - 保持三档 preset 数值不漂移。
  - 覆盖 `CompressionQuality.custom(80)` 到 `0.8` 的映射。
- `CompressionOptionsTests`
  - JPEG / HEIC / WebP 输出带 `lossyQuality`。
  - PNG 输出将 `lossyQuality` 清洗为 `nil`。
  - PNG 路径收到非 nil `lossyQuality` 时 encoder 防御式忽略。
- `ImageCompressorTests`
  - JPG/PNG/HEIC -> WebP。
  - WebP -> Original。
  - WebP alpha 保留。
  - 透明 PNG -> WebP，覆盖 100% 透明和 50% 半透明。
  - 多帧 WebP 拒绝，Native 路径用 `CGImageSourceGetCount(source) > 1`。
  - 损坏动画 WebP 漏报作为 v0.9.x 已知风险，不作为 v0.9 阻断。
  - WebP 输出命名不覆盖已有文件。
  - Overwrite 模式不允许格式转换。
  - 任意格式输出大于输入时 skipped，并显示 `Skipped: output would be larger than source`。
  - encoder 抛错时清理 `destinationTemporaryURL`。
- Encoder capability tests
  - native ImageIO read/write capability 分离。
  - `alphaCapableFormats` 按输出格式表达能力，JPEG 不得出现在集合中。
  - WebP write 不可用时 UI 不展示 WebP 输出格式。
  - WebP read 可用但 write 不可用时，WebP 输入仍可进入队列。
  - 已保存 WebP 输出偏好不可用时只做内存回退，不写回 `UserDefaults`。

### 13.2 UI 测试

必须覆盖：

- 选择 WebP 输出格式。
- 选择 Custom quality 并持久化。
- PNG 模式显示 lossless 解释文案。
- Custom Quality slider 拖动时实时更新 UI，结束拖动或 debounce 后才持久化。
- Overwrite 模式禁用格式转换。
- WebP write 不可用时，格式选择器不出现 WebP。
- WebP read 可用但 write 不可用时，WebP 输入可导入并转为其他格式。

### 13.3 手工验收

- 先完成当前可获得环境的 ImageIO WebP spike，并记录未覆盖系统版本。
- 拖入 JPG/PNG/HEIC/WebP 混合批次，输出 WebP。
- 用 Preview、Safari、Chrome 打开输出 WebP。
- 透明 PNG 输出 WebP 后检查 100% 透明和 50% 半透明区域。
- 已压缩小 JPEG 或 WebP 再压，确认不会输出更大文件。
- 覆盖模式下确认格式被锁定为 Original。
- 删除或移动输出目录，确认 bookmark 恢复逻辑不回退。
- 无网络环境下完整压缩，确认不依赖在线资源。

### 13.4 标准验证命令

```bash
swift test
xcodebuild -project ImagePet.xcodeproj -scheme ImagePet -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' test
./script/build_and_run.sh --verify
git diff --check
```

`./script/build_and_run.sh --verify` 是当前仓库已有验证脚本，不是 v0.9 新增脚本；如果后续删除或重命名该脚本，必须同步更新本节。

如果新增 Swift source files 并通过 XcodeGen 管理 project，应运行：

```bash
xcodegen generate
```

并检查、提交 `project.yml` 和 `ImagePet.xcodeproj` 的配套 diff。

---

## 14. 发布与回滚

发布前必须满足：

- Phase 0 Spike 结果已记录，未覆盖系统版本已标注。
- WebP capability gate 可控。
- App Sandbox 验证通过。
- 没有新增网络权限。
- 没有新增外部二进制分发风险。
- 保存的 WebP 偏好在不可用环境中可回退。

回滚策略：

- WebP 可通过 capability gate 下线。
- 已保存的用户偏好如果指向不可用格式，启动时只在内存 effective value 中回退到 `Original`，不写回覆盖用户偏好。
- 旧版本读取 v0.9 UserDefaults 时应忽略未知字段。

---

## 15. 后续版本

### v0.9.x

- libwebp fallback。
- WebP lossless spike。
- WebP / PNG / JPEG benchmark fixture 集。

### v1.0

- Advanced JPEG。
- mozjpeg。
- libjpeg-turbo 评估。
- Third Party Notices 完整体系。
- 外部 codec 的 Universal binary、codesign、notarization 和安全更新流程。

---

## 16. 参考资料

本 PRD 中的外部 codec 判断基于 2026-06-15 查阅的官方资料：

- [libwebp README](https://github.com/webmproject/libwebp)
- [Google WebP overview](https://developers.google.com/speed/webp)
- [cwebp documentation](https://developers.google.com/speed/webp/docs/cwebp)
- [WebP tools documentation](https://chromium.googlesource.com/webm/libwebp/+/HEAD/doc/tools.md)
- [mozjpeg README](https://github.com/mozilla/mozjpeg)
- [libjpeg-turbo license](https://github.com/libjpeg-turbo/libjpeg-turbo/blob/main/LICENSE.md)
- [Apple UTType.webP documentation](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/webp)
