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

v0.9 不赌系统 ImageIO 的 WebP 写入能力。WebP 路线改为 **Swift-WebP / libwebp 为主**，ImageIO 只保留为既有 JPEG/PNG/HEIC 管线、fixture 对照或明确标记的 fallback。Advanced JPEG、mozjpeg 和通用 codec 插件体系仍移出 v0.9 首发。

---

## 2. 最终范围

### P0

- WebP 静态输入/输出。
- Custom Quality。
- Swift-WebP based WebP engine。
- Swift-WebP / libwebp dependency governance。
- SPM build、App Sandbox、codesign、notarization smoke test。
- Third Party Notices。
- WebP alpha 保留。
- WebP bitstream inspection。
- animated / multi-frame WebP 拒绝。
- Overwrite 禁止格式转换。
- 输出变大 => skipped。
- UI capability gate。

### P1 / v0.9.x

- WebP lossless spike。
- benchmark fixtures。
- ImageIO WebP fallback 评估。
- Swift-WebP/libwebp 安全更新流程自动化。

### v1.0

- Advanced JPEG。
- mozjpeg。
- Advanced JPEG 相关 Third Party Notices 扩展。

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
- 把 ImageIO 作为 WebP 主编码器。

---

## 4. Phase 0 Dependency Spike 与决策门

v0.9 不应在实现阶段才发现 WebP 依赖无法稳定集成。必须先完成一个短 spike，并把结果写回 PRD 或进度文档。

### 4.1 Spike 范围

首选 WebP 路线：

```text
Swift-WebP -> libwebp-Xcode -> libwebp
```

ImageIO 只作为：

- 既有 JPEG / PNG / HEIC decode/encode 路径。
- WebP fixture 对照。
- 明确标记的 fallback 候选，不作为 v0.9 主 WebP encoder。

Swift-WebP dependency spike 必须验证：

- SPM 能在当前 Xcode / Swift toolchain 下 resolve、build、test。
- `Package.resolved` 锁定 Swift-WebP 与 transitive `libwebp-Xcode` 版本。
- App target 能通过 committed `ImagePet.xcodeproj` 引用该 SPM dependency。
- `swift test`、`xcodebuild ... test` 和 `./script/build_and_run.sh --verify` 不因 SPM dependency 失效。
- Sandboxed app 内可调用 Swift-WebP encode、decode、bitstream inspection。
- Debug app codesign 后可运行。
- Developer ID / Hardened Runtime / notarization smoke 不因 libwebp 依赖失败。
- `docs/THIRD_PARTY_NOTICES.md` 能覆盖 Swift-WebP MIT license、libwebp/libwebp-Xcode license、版本、源码 URL 和构建方式。

依赖快照（2026-06-15）：

- Swift-WebP 是 `libwebp` 的 Swift wrapper，README 明确覆盖 encode、decode 和 bitstream inspection。
- Swift Package product 名称为 `WebP`，依赖 `SDWebImage/libwebp-Xcode`。
- Swift Package Index 显示最新 release 为 `0.6.1`，MIT licensed，当前无 open issues / PR。
- 该快照只用于选择候选依赖；发布前仍必须以本仓库的 dependency spike 和 smoke test 为准。

目标系统 smoke 矩阵是：

- macOS 13。
- macOS 14。
- macOS 15。
- macOS 26，若本机或 CI 环境可用。

已知风险：

- macOS 13 的 ImageIO WebP write 能力可能不稳定或不可用，但 v0.9 不依赖 ImageIO WebP write。
- Swift-WebP 当前 README 标注的 Swift toolchain、Swift language mode、libwebp 和 deployment target 要求必须和 ImagePet 当前 toolchain 对齐；如果不对齐，v0.9 需要显式升级 toolchain 或重新评估依赖。
- 截至 2026-06-15，Swift-WebP `main` 的 `Package.swift` 使用 Swift tools 6.2，ImagePet 当前工程配置仍是 Swift 5.9；dependency spike 必须确认可用 tag 与本地 Xcode/CI toolchain 兼容，不能静默把 v0.9 变成 Xcode/Swift 升级项目。
- Swift-WebP 依赖 `libwebp-Xcode`，因此安全更新不只看 Swift wrapper，还要跟进 libwebp 版本。

现实约束：

- 独立开发者通常无法一次性覆盖全部系统版本。
- v0.9 的发布阻断项是“当前开发机 + 可获得 CI / 虚拟机 / 用户验证环境”的 Swift-WebP dependency smoke 结果。
- 无法获得的系统版本必须在 spike 记录中标注为 `not verified`，并作为后续兼容性验证缺口，而不是伪造通过。

实测项：

- Swift-WebP encode 是否可用。
- Swift-WebP decode 是否可用。
- Swift-WebP bitstream inspection 是否能读出 width、height、hasAlpha、hasAnimation。
- JPG/PNG/HEIC -> WebP 是否可写出。
- WebP -> Original 是否可写出。
- PNG alpha -> WebP 是否保留透明通道。
- 静态 WebP 是否能被 Preview、Safari、Chrome 打开。
- animated / multi-frame WebP 是否能通过 bitstream inspection 稳定检测并拒绝。
- ImageIO decode 对同一 fixture 的结果是否可作为对照。

Spike 记录模板至少包含：

```text
macOS version: 26.5.1 (25F80)
hardware / runner: local arm64 Mac
Swift / Xcode version: Swift 6.3.2 / Xcode 26.5 (17F42)
Swift-WebP version: 0.6.1
libwebp-Xcode version: 1.5.0
SPM resolve: pass
swift test: pass
xcodebuild test: pass
app sandbox smoke: pass, sandbox entitlement present in Debug build
codesign smoke: pass, adhoc Debug signature
notarization smoke: not verified
Swift-WebP encode: yes
Swift-WebP decode: yes
bitstream inspection: yes
alpha: pass, 100% transparent and 50% alpha fixtures covered
animated/multi-frame rejection: not verified with real animated fixture
Preview open: not verified
Safari open: not verified
Chrome open: not verified
ImageIO fixture comparison: not verified
notes: WebP write/read capability is injectable for tests; WebP write unavailable maps to a skipped result reason.
```

### 4.2 决策结果

Spike 后只能进入以下两种方案之一：

#### 方案 A: Swift-WebP 足够

v0.9 首发使用 Swift-WebP/libwebp：

- 实现 `SwiftWebPEncodingEngine` 和 WebP decode/inspection path。
- 锁定 Swift-WebP 和 `libwebp-Xcode` 版本。
- 新增 Third Party Notices。
- 保留 capability gate 和 smoke test。
- ImageIO 只作为 fixture 对照或 fallback 候选。

#### 方案 B: Swift-WebP 不足

v0.9 不发布 WebP：

- WebP 输出格式继续隐藏。
- `.webp` 输入继续按 unsupported 或 ImageIO decode-only 实验处理。
- 只发布 Custom Quality 或推迟 v0.9。

在没有完成方案 A 的依赖治理前，v0.9 不应把 WebP 标成可发布功能。

---

## 5. WebP 静态输入/输出

### 5.1 支持能力

- `SupportedImageFormat` 增加 `webp`，但由 Swift-WebP read capability 决定是否接受 `.webp` 输入。
- `OutputFormat` 增加 `webp`，但只在 Swift-WebP write capability 可用时显示。
- WebP read capability 和 write capability 仍是两个独立维度，不能因为使用 Swift-WebP 就合并成一个布尔值。
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
- ImageIO WebP encode 不作为 v0.9 主要实现；只能用于 fixture comparison 或受 capability gate 保护的 fallback 实验。

### 5.2 多帧 WebP 拒绝

v0.9 只支持静态 WebP。

Swift-WebP 路径的检测口径：

```swift
WebPImageInspector.inspect(data).hasAnimation == true
```

严格说，多帧不一定等于动画。v0.9 的产品口径是：所有 animated / multi-frame WebP 均视为 unsupported。

如果 bitstream inspection 发现 `hasAnimation == true` 或等价多帧信号，拒绝并显示：

```text
Unsupported image format
```

不要只依赖文件后缀，也不要只依赖 ImageIO 的 `CGImageSourceGetCount(source)`。

已知限制：

- v0.9 依赖 Swift-WebP/libwebp 暴露的 bitstream inspection 结果；如果损坏 WebP 容器无法被 inspection 正常解析，应失败为 `Failed to decode image` 或 `Unsupported image format`，不能退化为静默接受。
- v0.9 的测试必须覆盖正常 animated/multi-frame WebP 拒绝；损坏动画 WebP 作为 v0.9.x 安全强化项继续跟踪。

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
- PNG encoder 路径必须防御式忽略非 nil `lossyQuality`，不得因为 UI 或调用方错误传入 custom quality 而崩溃。

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

## 8. Swift-WebP Engine 与 Capabilities

### 8.1 为什么需要

WebP P0 需要稳定的 encode、decode、alpha 和 bitstream inspection。v0.9 首发使用 Swift-WebP/libwebp，而不是赌系统 ImageIO WebP write。

v0.9 只需要：

- `EncoderCapabilities`，表达 Swift-WebP engine 当前可读、可写和 alpha 能力。
- `SwiftWebPEncodingEngine`，封装 Swift-WebP 写出行为。
- `SwiftWebPDecodingEngine` 或等价 helper，封装 Swift-WebP decode / bitstream inspection。

v0.9 不需要完整的多 encoder protocol 或 composite engine。等 v0.9.x 真的需要 ImageIO fallback 或其他 encoder 时，再抽通用 `ImageEncodingEngine` protocol 和 composite routing。

### 8.2 建议接口

```swift
public struct EncoderCapabilities: Sendable, Equatable {
    public let readableFormats: Set<SupportedImageFormat>
    public let writableFormats: Set<OutputFormat>
    public let supportsCustomQuality: Bool
    public let alphaCapableFormats: Set<OutputFormat>
    public let supportsBitstreamInspection: Bool
}

public struct SwiftWebPEncodingEngine: Sendable {
    public let capabilities: EncoderCapabilities

    func encode(
        image: CGImage,
        source: ImageSourceMetadata,
        destinationTemporaryURL: URL,
        options: CompressionOptions
    ) throws
}
```

`alphaCapableFormats` 必须是 per-format 能力集合，而不是 engine 级布尔值。JPEG 永远不应出现在该集合中；PNG 通常应出现；WebP 只有在 Swift-WebP path 通过透明度 spike 后才出现。

`SwiftWebPEncodingEngine` 使用 `struct` 和不可变 `capabilities`。`encode()` 必须只使用局部 Swift-WebP/libwebp 对象，不保存跨 job 的可变状态，因此同一个值可以在 `maxConcurrentJobs = 2` 下并发调用。不要使用 `@unchecked Sendable`，除非后续实现引入内部缓存并补充锁保护说明。

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
- 对 WebP 输出调用 Swift-WebP/libwebp。

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

- 如果 Swift-WebP write smoke 不可用，`OutputFormat.webp` 不显示。
- 如果 Swift-WebP read smoke 不可用，`.webp` 文件拖入后显示 `Unsupported image format`。
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
- Swift-WebP 必须通过 SPM 版本锁定进入构建，不允许运行时动态发现或下载。
- `Package.resolved` 必须提交。
- `docs/THIRD_PARTY_NOTICES.md` 必须新增并覆盖 Swift-WebP、libwebp-Xcode 和 libwebp。
- 保留 `maxConcurrentJobs = 2`。
- Decode/encode 继续包裹 `autoreleasepool`。
- 输出仍遵守“成功才替换/成功才展示”的原则。
- 任何格式输出大于输入时默认 skipped。

Swift-WebP / libwebp 治理要求：

- 固定 Swift-WebP 版本。
- 固定 transitive `libwebp-Xcode` / libwebp 版本。
- 明确记录所选 Swift-WebP tag 的 Swift tools version；如果需要升级 ImagePet 的 Swift/Xcode toolchain，必须作为单独决策项进入 PR。
- 验证 Universal macOS binary。
- 验证 App Sandbox、codesign、Hardened Runtime 和 notarization smoke。
- 记录 license、source URL、version、build method。
- 跟踪 libwebp 安全更新；安全更新可以作为 patch release 优先级高于功能开发。

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
| Swift-WebP lossy Balanced | 与同一批 20 张 12MP HEIC/JPEG fixture 的 Native JPEG Balanced 批量 wall-clock 对比，不超过 2.5x；在 Apple Silicon 开发机上硬上限 60 秒 |
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
  - animated / multi-frame WebP 拒绝，Swift-WebP 路径用 bitstream inspection。
  - 损坏 WebP inspection 失败时映射为 `Failed to decode image` 或 `Unsupported image format`。
  - WebP 输出命名不覆盖已有文件。
  - Overwrite 模式不允许格式转换。
  - 任意格式输出大于输入时 skipped，并显示 `Skipped: output would be larger than source`。
  - encoder 抛错时清理 `destinationTemporaryURL`。
- Encoder capability tests
  - Swift-WebP read/write capability 分离。
  - `alphaCapableFormats` 按输出格式表达能力，JPEG 不得出现在集合中。
  - `supportsBitstreamInspection` 必须为 true，否则 WebP 功能不展示。
  - WebP write 不可用时 UI 不展示 WebP 输出格式。
  - WebP read 可用但 write 不可用时，WebP 输入仍可进入队列。
  - 已保存 WebP 输出偏好不可用时只做内存回退，不写回 `UserDefaults`。
- Dependency smoke tests
  - SPM resolve 成功。
  - `Package.resolved` 锁定 Swift-WebP 和 transitive libwebp dependency。
  - `docs/THIRD_PARTY_NOTICES.md` 包含 Swift-WebP、libwebp-Xcode、libwebp 的 license / version / source URL / build method。
  - Debug app codesign 后可调用 Swift-WebP encode/decode/inspection。
  - Developer ID / notarization smoke 不因 Swift-WebP/libwebp 失败。

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

- 先完成当前可获得环境的 Swift-WebP dependency spike，并记录未覆盖系统版本。
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

- Phase 0 Swift-WebP dependency spike 结果已记录，未覆盖系统版本已标注。
- WebP capability gate 可控。
- App Sandbox 验证通过。
- 没有新增网络权限。
- Swift-WebP / libwebp-Xcode / libwebp 版本已锁定。
- Third Party Notices 已归档。
- codesign、Hardened Runtime、notarization smoke 已通过或明确标注未验证。
- 保存的 WebP 偏好在不可用环境中可回退。

回滚策略：

- WebP 可通过 capability gate 下线。
- 已保存的用户偏好如果指向不可用格式，启动时只在内存 effective value 中回退到 `Original`，不写回覆盖用户偏好。
- 旧版本读取 v0.9 UserDefaults 时应忽略未知字段。

---

## 15. 后续版本

### v0.9.x

- WebP lossless spike。
- WebP / PNG / JPEG benchmark fixture 集。
- ImageIO WebP fallback 评估。
- Swift-WebP/libwebp 安全更新自动化。

### v1.0

- Advanced JPEG。
- mozjpeg。
- libjpeg-turbo 评估。
- Advanced JPEG 相关 Third Party Notices 扩展。
- 外部 codec 的 Universal binary、codesign、notarization 和安全更新流程。

---

## 16. 参考资料

本 PRD 中的外部 codec 判断基于 2026-06-15 查阅的官方资料：

- [libwebp README](https://github.com/webmproject/libwebp)
- [Swift-WebP README](https://github.com/ainame/Swift-WebP)
- [Swift-WebP Package.swift](https://github.com/ainame/Swift-WebP/blob/main/Package.swift)
- [Swift-WebP license](https://github.com/ainame/Swift-WebP/blob/main/LICENSE)
- [Swift Package Index: WebP](https://swiftpackageindex.com/ainame/Swift-WebP)
- [Google WebP overview](https://developers.google.com/speed/webp)
- [cwebp documentation](https://developers.google.com/speed/webp/docs/cwebp)
- [WebP tools documentation](https://chromium.googlesource.com/webm/libwebp/+/HEAD/doc/tools.md)
- [mozjpeg README](https://github.com/mozilla/mozjpeg)
- [libjpeg-turbo license](https://github.com/libjpeg-turbo/libjpeg-turbo/blob/main/LICENSE.md)
- [Apple UTType.webP documentation](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/webp)
